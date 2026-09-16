package com.carsaimz.genyassistant.ai

import android.content.Context
import com.carsaimz.genyassistant.data.GenyDb
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

/**
 * Gerenciador de modelos locais (docs §7.5): download sob demanda com
 * verificação de integridade por SHA-256, em diretório dedicado do app.
 * Nenhum modelo é embutido no APK nem versionado no repositório.
 */
class ModelManager(private val context: Context) {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val db = GenyDb(context)
    private val modelsDir: File by lazy {
        File(context.filesDir, "models").apply { mkdirs() }
    }

    /** Baixa um modelo (ex.: GGUF para llama.cpp) e verifica o hash. */
    fun download(
        url: String,
        name: String,
        kind: String,
        expectedSha256: String?,
        onProgress: (bytes: Long, total: Long) -> Unit = { _, _ -> },
        onDone: (Result<File>) -> Unit = {},
    ) {
        scope.launch {
            onDone(
                try {
                    val file = downloadSync(url, name, kind, expectedSha256, onProgress)
                    Result.success(file)
                } catch (e: Exception) {
                    Result.failure(e)
                },
            )
        }
    }

    @Throws(Exception::class)
    private fun downloadSync(
        url: String,
        name: String,
        kind: String,
        expectedSha256: String?,
        onProgress: (Long, Long) -> Unit,
    ): File {
        require(name.matches(Regex("[A-Za-z0-9._-]+"))) { "nome de modelo invalido" }
        // Guarda anti-colisão (TODO android-03): a tela nativa e a UI web podem
        // pedir o MESMO arquivo — quem chegar segundo recebe erro em vez de
        // corromper o .part compartilhado.
        check(tryAcquireDownload(name)) { "download ja em andamento: $name" }
        try {
            return downloadLocked(url, name, kind, expectedSha256, onProgress)
        } finally {
            releaseDownload(name)
        }
    }

    /** Corpo do download; só roda com a guarda do arquivo adquirida. */
    @Throws(Exception::class)
    private fun downloadLocked(
        url: String,
        name: String,
        kind: String,
        expectedSha256: String?,
        onProgress: (Long, Long) -> Unit,
    ): File {
        val tmp = File(modelsDir, "$name.part")
        val digest = MessageDigest.getInstance("SHA-256")
        var total = -1L
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = 15_000
        connection.readTimeout = 60_000
        try {
            total = connection.contentLengthLong
            connection.inputStream.use { input ->
                tmp.outputStream().use { output ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE * 8)
                    var read: Int
                    var done = 0L
                    while (input.read(buffer).also { read = it } != -1) {
                        output.write(buffer, 0, read)
                        digest.update(buffer, 0, read)
                        done += read
                        onProgress(done, total)
                    }
                }
            }
        } finally {
            connection.disconnect()
        }
        val sha = digest.digest().joinToString("") { "%02x".format(it) }
        if (!expectedSha256.isNullOrEmpty() && !sha.equals(expectedSha256, ignoreCase = true)) {
            tmp.delete()
            throw SecurityException("hash do modelo nao confere: esperado $expectedSha256, obtido $sha")
        }
        val final = File(modelsDir, name)
        if (!tmp.renameTo(final)) {
            throw IllegalStateException("falha ao finalizar download de $name")
        }
        db.upsertModel(kind, name, final.absolutePath, sha, final.length(), System.currentTimeMillis())
        return final
    }

    /** Lista modelos baixados por categoria (llm, stt, tts, embedding, wakeword). */
    fun listModels(kind: String? = null): List<com.carsaimz.genyassistant.data.ModelRecord> {
        return db.listModels(kind)
    }

    /** Remove um modelo baixado (arquivo + registro no Room). */
    fun delete(name: String): Boolean {
        val file = File(modelsDir, name)
        val deleted = file.exists() && file.delete()
        if (deleted) {
            db.deleteModelByPath(file.absolutePath)
        }
        return deleted
    }

    /** Uso de disco pelos modelos, em bytes. */
    fun diskUsageBytes(): Long {
        return modelsDir.walkTopDown().filter { it.isFile }.sumOf { it.length() }
    }

    companion object {

        // Instâncias de ModelManager são criadas ad hoc (web e tela nativa);
        // a guarda de download tem de ser estática para valer entre elas.
        private val inFlight = java.util.concurrent.ConcurrentHashMap<String, Boolean>()

        /**
         * Reserva o arquivo para download. `false` quando já há um download
         * em andamento para o mesmo nome (comparação sem maiúsculas).
         * Puro o bastante para teste JVM (não toca em Context/rede).
         */
        @JvmStatic
        fun tryAcquireDownload(name: String): Boolean =
            inFlight.putIfAbsent(name.lowercase(), true) == null

        /** Libera a reserva de download (idempotente). */
        @JvmStatic
        fun releaseDownload(name: String) {
            inFlight.remove(name.lowercase())
        }

        /** true quando existe download em andamento para o nome. */
        @JvmStatic
        fun isDownloading(name: String): Boolean = inFlight.containsKey(name.lowercase())

        /** Metadados mínimos de um modelo para o gerenciador. */
        fun meta(kind: String, name: String, url: String, sha256: String?): JSONObject {
            return JSONObject()
                .put("kind", kind)
                .put("name", name)
                .put("url", url)
                .put("sha256", sha256 ?: JSONObject.NULL)
        }
    }
}
