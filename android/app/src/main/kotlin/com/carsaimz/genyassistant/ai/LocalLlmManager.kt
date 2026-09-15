package com.carsaimz.genyassistant.ai

import android.app.ActivityManager
import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Gerenciador do LLM local (docs §6, TODO core-05/app-02).
 *
 * **PT** Ciclo de vida do modelo GGUF atrás da ponte: download (ModelManager
 * com SHA-256 pinado), carga com guarda de RAM, geração e descarga. Um único
 * executor dedicado serializa operações pesadas. Eventos no canal `genyLlm`:
 *
 * - `llmProgress` — download em andamento (`bytes`, `total`, `id`)
 * - `llmReady`    — download concluído (`id`)
 * - `llmError`    — falha com código (`id`, `code`)
 * - `llmStatus`   — mudança de estado do motor (`state`: loading/ready/idle)
 * - `llmToken`    — peça gerada no streaming (`text`) — TODO core-05b
 *
 * **EN** GGUF model lifecycle behind the bridge: download (ModelManager with
 * pinned SHA-256), load with a RAM guard, generate and unload. A single
 * dedicated executor serializes heavy work. Events on the `genyLlm` channel:
 * `llmProgress`, `llmReady`, `llmError`, `llmStatus` and `llmToken` (see PT
 * list).
 */
class LocalLlmManager(
    private val context: Context,
    private val emit: (JSONObject) -> Unit,
) {

    /** Estado do motor exposto à UI. */
    var state: String = "idle" // idle | loading | ready
        private set

    var loadedFileName: String? = null
        private set

    private val executor: ExecutorService = Executors.newSingleThreadExecutor { r ->
        Thread(r, "geny-llm").apply { priority = Thread.NORM_PRIORITY - 1 }
    }
    private val modelsDir: File by lazy {
        File(context.filesDir, "models").apply { mkdirs() }
    }
    @Volatile
    private var handle: Long = 0

    // ---------------------------------------------------------- capabilities --

    fun capabilities(): JSONObject {
        val downloaded = downloadedFileNames()
        val models = JSONArray()
        for (m in LlmCatalog.MODELS) {
            models.put(
                JSONObject()
                    .put("id", m.id)
                    .put("fileName", m.fileName)
                    .put("label", m.label)
                    .put("bytes", m.bytes)
                    .put("downloaded", downloaded.any { it.equals(m.fileName, ignoreCase = true) }),
            )
        }
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
        val memInfo = ActivityManager.MemoryInfo()
        am?.getMemoryInfo(memInfo)
        return JSONObject()
            .put("jniAvailable", LlmJni.available)
            .put("state", state)
            .put("loadedFile", loadedFileName ?: JSONObject.NULL)
            .put("diskUsageBytes", diskUsageBytes())
            .put("totalRamBytes", memInfo.totalMem)
            .put("models", models)
    }

    private fun downloadedFileNames(): List<String> =
        modelsDir.listFiles()?.filter { it.isFile && it.name.endsWith(".gguf") }
            ?.map { it.name } ?: emptyList()

    private fun diskUsageBytes(): Long =
        modelsDir.walkTopDown().filter { it.isFile }.sumOf { it.length() }

    // ------------------------------------------------------------- download --

    fun downloadModel(id: String) {
        val model = LlmCatalog.byId(id)
        if (model == null) {
            emitEvent("llmError", JSONObject().put("id", id).put("code", "unknown_model"))
            return
        }
        val manager = ModelManager(context)
        manager.download(
            url = model.url,
            name = model.fileName,
            kind = "llm",
            expectedSha256 = model.sha256,
            onProgress = { bytes, total ->
                emitEvent(
                    "llmProgress",
                    JSONObject()
                        .put("id", id)
                        .put("bytes", bytes)
                        .put("total", if (total > 0) total else model.bytes),
                )
            },
            onDone = { result ->
                result.fold(
                    onSuccess = {
                        emitEvent("llmReady", JSONObject().put("id", id))
                    },
                    onFailure = { e ->
                        emitEvent(
                            "llmError",
                            JSONObject().put("id", id).put("code", "download_failed")
                                .put("message", e.message ?: "download falhou"),
                        )
                    },
                )
            },
        )
    }

    fun deleteModel(fileName: String): Boolean {
        val safe = File(fileName).name // sem traversy de caminho
        if (safe.equals(loadedFileName, ignoreCase = true)) unload()
        val file = File(modelsDir, safe)
        return file.exists() && file.delete()
    }

    // ------------------------------------------------------- load / unload --

    fun load(fileName: String) {
        executor.execute {
            val safe = File(fileName).name
            val model = LlmCatalog.byFileName(safe)
            if (model == null) {
                emitEvent("llmError", JSONObject().put("id", safe).put("code", "unknown_model"))
                return@execute
            }
            if (!LlmJni.available) {
                emitEvent("llmError", JSONObject().put("id", model.id).put("code", "jni_unavailable"))
                return@execute
            }
            val file = File(modelsDir, safe)
            if (!file.exists()) {
                emitEvent("llmError", JSONObject().put("id", model.id).put("code", "not_downloaded"))
                return@execute
            }
            val required = requiredRamBytes(file.length())
            val am = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            val memInfo = ActivityManager.MemoryInfo()
            am?.getMemoryInfo(memInfo)
            if (memInfo.availMem < required) {
                emitEvent(
                    "llmError",
                    JSONObject()
                        .put("id", model.id)
                        .put("code", "low_memory")
                        .put("requiredBytes", required)
                        .put("availBytes", memInfo.availMem),
                )
                return@execute
            }
            setState("loading")
            val ptr = LlmJni.nativeInit(file.absolutePath, model.contextTokens, estimateThreads())
            if (ptr == 0L) {
                setState("idle")
                loadedFileName = null
                emitEvent("llmError", JSONObject().put("id", model.id).put("code", "load_failed"))
                return@execute
            }
            handle = ptr
            loadedFileName = safe
            setState("ready")
        }
    }

    fun unload() {
        executor.execute {
            if (handle != 0L) {
                LlmJni.nativeFree(handle)
                handle = 0
            }
            loadedFileName = null
            setState("idle")
        }
    }

    private fun setState(next: String) {
        state = next
        emitEvent("llmStatus", JSONObject().put("state", next).put("file", loadedFileName ?: ""))
    }

    // ------------------------------------------------------------ generate --

    /**
     * Gera uma resposta de forma assíncrona no executor dedicado — load,
     * generate e unload compartilham o MESMO executor single-thread, o que
     * elimina use-after-free (unload só roda depois da geração atual).
     */
    fun generateAsync(
        messagesJson: String,
        maxTokens: Int,
        temperature: Float,
        topP: Float,
        seed: Int,
        onDone: (JSONObject) -> Unit,
    ) {
        executor.execute {
            onDone(generate(messagesJson, maxTokens, temperature, topP, seed))
        }
    }

    /**
     * Igual a [generateAsync], mas com streaming (TODO core-05b): cada peça
     * gerada chega à UI pelo evento `llmToken` do canal `genyLlm` e ao
     * callback [onToken] (mesma thread do executor — emita, não bloqueie).
     * O JSON final traz `stopped=true` quando [stopGeneration] foi chamado.
     */
    fun generateStreamAsync(
        messagesJson: String,
        maxTokens: Int,
        temperature: Float,
        topP: Float,
        seed: Int,
        onToken: (String) -> Unit,
        onDone: (JSONObject) -> Unit,
    ) {
        executor.execute {
            onDone(generateStream(messagesJson, maxTokens, temperature, topP, seed, onToken))
        }
    }

    /**
     * Pede a parada da geração em andamento. Não entra na fila do executor
     * (que está ocupado gerando): marca a flag atômica no handle nativo
     * direto da thread chamadora — o loop entre tokens observa e encerra,
     * devolvendo o texto parcial com `stopped=true`.
     */
    fun stopGeneration() {
        val ptr = handle
        if (ptr != 0L && LlmJni.available) {
            runCatching { LlmJni.nativeCancel(ptr) }
        }
    }

    /**
     * Gera uma resposta. Bloqueia a thread chamante — usar apenas dentro do
     * executor dedicado. `messagesJson`: `[{role, content}, ...]`.
     */
    fun generate(messagesJson: String, maxTokens: Int, temperature: Float, topP: Float, seed: Int): JSONObject {
        if (handle == 0L || state != "ready") {
            return JSONObject().put("error", "modelo_nao_carregado")
        }
        val pairs = extractPairs(messagesJson)
        if (pairs.first.isEmpty()) {
            return JSONObject().put("error", "sem_mensagens")
        }
        val roles = pairs.first.toTypedArray()
        val contents = pairs.second.toTypedArray()
        val raw = LlmJni.nativeGenerate(
            handle, systemPrompt(), roles, contents,
            maxTokens.coerceIn(1, 1024), temperature, topP, seed,
        )
        return parseResult(raw)
    }

    /**
     * Igual a [generate] com streaming (TODO core-05b): invoca [onToken] por
     * peça e emite o evento `llmToken`. Bloqueia a thread chamante — usar
     * apenas dentro do executor dedicado.
     */
    fun generateStream(
        messagesJson: String,
        maxTokens: Int,
        temperature: Float,
        topP: Float,
        seed: Int,
        onToken: (String) -> Unit,
    ): JSONObject {
        if (handle == 0L || state != "ready") {
            return JSONObject().put("error", "modelo_nao_carregado")
        }
        val pairs = extractPairs(messagesJson)
        if (pairs.first.isEmpty()) {
            return JSONObject().put("error", "sem_mensagens")
        }
        val roles = pairs.first.toTypedArray()
        val contents = pairs.second.toTypedArray()
        val raw = LlmJni.nativeGenerateStream(
            handle, systemPrompt(), roles, contents,
            maxTokens.coerceIn(1, 1024), temperature, topP, seed,
        ) { piece ->
            try {
                emitEvent("llmToken", JSONObject().put("text", piece))
            } catch (_: Exception) {
                // evento nunca derruba a geração
            }
            onToken(piece)
        }
        return parseResult(raw)
    }

    private fun parseResult(raw: String): JSONObject {
        return try {
            JSONObject(raw)
        } catch (e: Exception) {
            JSONObject().put("error", "resposta_invalida").put("message", e.message ?: "")
        }
    }

    fun release() {
        executor.execute {
            if (handle != 0L) {
                LlmJni.nativeFree(handle)
                handle = 0
            }
            loadedFileName = null
            state = "idle"
        }
        executor.shutdown()
    }

    // -------------------------------------------------------------- helpers --

    private fun emitEvent(type: String, payload: JSONObject) {
        payload.put("type", type)
        emit(payload)
    }

    private fun systemPrompt(): String {
        val lang = java.util.Locale.getDefault().toLanguageTag()
        return "Voce e o Geny Assistant, uma assistente local-first. " +
            "Responda no idioma do usuario ($lang) de forma curta e util."
    }

    companion object {
        /** RAM estimada para o modelo + runtime (pesos × 1,35 + 128 MB). */
        fun requiredRamBytes(modelBytes: Long): Long = (modelBytes * 1.35).toLong() + 128L * 1024 * 1024

        /** Threads de inferência: metade dos núcleos, mínimo 1, teto de 6 (térmico). */
        fun estimateThreads(cores: Int = Runtime.getRuntime().availableProcessors()): Int =
            (cores / 2).coerceIn(1, 6)

        /**
         * Extrai roles/contents de `[{role, content}]` — pure, testável.
         * Mensagens vazias e roles inválidos são descartados.
         */
        fun extractPairs(messagesJson: String): Pair<List<String>, List<String>> {
            if (messagesJson.isBlank()) return Pair(emptyList(), emptyList())
            return try {
                val arr = JSONArray(messagesJson)
                val roles = mutableListOf<String>()
                val contents = mutableListOf<String>()
                for (i in 0 until arr.length()) {
                    val obj = arr.optJSONObject(i) ?: continue
                    val role = obj.optString("role").trim()
                    val content = obj.optString("content").trim()
                    if (role.isEmpty() || content.isEmpty()) continue
                    if (role !in setOf("user", "assistant")) continue
                    roles.add(role)
                    contents.add(content)
                }
                Pair(roles, contents)
            } catch (_: Exception) {
                Pair(emptyList(), emptyList())
            }
        }
    }
}
