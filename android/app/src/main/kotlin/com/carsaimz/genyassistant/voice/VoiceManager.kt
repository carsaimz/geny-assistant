package com.carsaimz.genyassistant.voice

import android.content.Context
import com.getcapacitor.JSObject

/**
 * Orquestrador de voz (docs §7, Fase 2).
 *
 * **PT** Máquina de estados única atrás da ponte: ocioso → capturando
 * (sistema ou whisper) → transcrevendo → ocioso. Emite um único canal de
 * eventos `genyVoice` com `{ type, ... }` para a UI:
 *
 * - `level`    — nível do microfone 0..1 (barra da UI)
 * - `speech`   — início/fim de fala pelo VAD
 * - `partial`  — transcrição parcial (provider sistema)
 * - `transcribing` — áudio capturado, whisper processando
 * - `result`   — transcrição final (`final: true`, `source`)
 * - `error`    — código + mensagem amigável para i18n
 * - `modelProgress` / `modelReady` / `modelError` — downloads sob demanda
 *
 * **EN** Single state machine behind the bridge: idle → capturing (system
 * or whisper) → transcribing → idle. Emits one event channel `genyVoice`
 * with `{ type, ... }` payloads for the UI (see PT list above).
 */
class VoiceManager(
    private val context: Context,
    private val emit: (JSObject) -> Unit,
) {

    private val vadConfig = VadConfig()
    private val whisper = WhisperSttEngine(context)
    private var system: SystemSpeechController? = null
    private var capture: AudioCaptureController? = null
    private var vad: VadEngine? = null
    private var assembler: PcmAssembler? = null
    private var vadAutoStop = false

    enum class Engine { SYSTEM, WHISPER }

    var isCapturing = false
        private set

    var activeEngine: Engine? = null
        private set

    // ---------------------------------------------------------- capabilities --

    fun capabilities(): JSObject {
        val sileroFile = SileroVadEngine.modelFile(context)
        val caps = JSObject()
            .put("mic", true)
            .put("systemStt", (system ?: newSystem()).isAvailable)
            .put("whisperNative", WhisperJni.available)
            .put("vadSilero", sileroFile != null)
            .put("vadEngine", if (sileroFile != null) "silero" else "energy")
            .put("tts", true)
        val models = com.getcapacitor.JSArray()
        for (m in VoiceCatalog.STT_MODELS) {
            models.put(
                JSObject()
                    .put("id", m.id)
                    .put("file", m.fileName)
                    .put("bytes", m.bytes)
                    .put("downloaded", whisper.modelFile(m.fileName) != null),
            )
        }
        caps.put("whisperModels", models)
        return caps
    }

    // ------------------------------------------------------------- capture --

    fun startCapture(engine: Engine, language: String, vadAutoStop: Boolean, modelId: String): Boolean {
        stopAll()
        this.vadAutoStop = vadAutoStop
        isCapturing = true
        activeEngine = engine
        return try {
            when (engine) {
                Engine.SYSTEM -> startSystem(language)
                Engine.WHISPER -> startWhisperCapture(language, modelId)
            }
        } catch (e: Exception) {
            // Qualquer exceção aqui seria fatal na ponte — vira evento de erro.
            isCapturing = false
            activeEngine = null
            emitEvent(
                "error",
                JSObject().put("code", "unavailable").put("message", e.message ?: "erro"),
            )
            false
        }
    }

    private fun newSystem(): SystemSpeechController =
        SystemSpeechController(context, systemCallback).also { system = it }

    private fun startSystem(language: String): Boolean {
        val controller = newSystem()
        if (!controller.isAvailable) {
            isCapturing = false
            activeEngine = null
            emitEvent("error", JSObject().put("code", "unavailable"))
            return false
        }
        controller.start(language)
        return true
    }

    private fun startWhisperCapture(language: String, modelId: String): Boolean {
        val vadEngine: VadEngine = createVad()
        val controller = AudioCaptureController(
            config = vadConfig,
            onFrame = { frame -> onAudioFrame(frame) },
            onMaxDuration = { autoStop("maxDuration") },
            onError = { message ->
                emitEvent("error", JSObject().put("code", "capture").put("message", message))
                stopAll()
            },
        )
        vad = vadEngine
        capture = controller
        assembler = PcmAssembler(vadConfig)
        startedAtMs = System.currentTimeMillis()
        currentModelFile = modelFileName(modelId)
        currentLanguage = language
        if (!controller.start()) {
            stopAll()
            return false
        }
        return true
    }

    private var startedAtMs = 0L
    private var currentModelFile: String? = null
    private var currentLanguage: String = "auto"

    private fun modelFileName(modelId: String): String =
        VoiceCatalog.sttById(modelId)?.fileName ?: VoiceCatalog.STT_WHISPER_TINY.fileName

    /** Motor VAD: Silero quando o modelo existe; energia como fallback. */
    private fun createVad(): VadEngine {
        val model = SileroVadEngine.modelFile(context)
        if (model != null) {
            try {
                return SileroVadEngine(model.absolutePath, vadConfig)
            } catch (_: Exception) {
                // modelo corrompido/incompatível: cai para energia
            }
        }
        return EnergyVadEngine(vadConfig)
    }

    private fun onAudioFrame(frame: ShortArray) {
        val engine = vad ?: return
        val decision = engine.process(frame)
        maybeEmitLevel(decision.level)
        if (decision.started) {
            emitEvent("speech", JSObject().put("active", true))
        }
        assembler?.push(frame, decision.speech)
        if (vadAutoStop && decision.ended) {
            autoStop("vad")
        }
    }

    // Eventos `level` chegam a cada frame de 30 ms (~33/s): afoga a ponte
    // em aparelhos lentos. Limita a ~10/s — imperceptível para a UI.
    private var lastLevelEmitMs = 0L

    private fun maybeEmitLevel(level: Float) {
        val now = System.currentTimeMillis()
        if (now - lastLevelEmitMs >= 90) {
            lastLevelEmitMs = now
            emitEvent("level", JSObject().put("level", level.toDouble()))
        }
    }

    /** Para e transcreve. `reason`: user | vad | maxDuration. */
    fun stopCapture(reason: String = "user") {
        if (activeEngine == Engine.SYSTEM) {
            system?.stopListeningSafe()
            return
        }
        val pcm = capture?.let { audio ->
            audio.stop()
            assembler?.finish()
        }
        releaseCapture()
        if (pcm == null || pcm.isEmpty()) {
            isCapturing = false
            activeEngine = null
            emitEvent("error", JSObject().put("code", "no_speech"))
            return
        }
        transcribe(pcm, reason)
    }

    private fun autoStop(reason: String) {
        if (!isCapturing) return
        emitEvent("stopped", JSObject().put("reason", reason))
        stopCapture(reason)
    }

    fun cancelCapture() {
        stopAll()
        emitEvent("stopped", JSObject().put("reason", "cancelled"))
    }

    private fun transcribe(pcm: ShortArray, reason: String) {
        isCapturing = false
        emitEvent("transcribing", JSObject())
        val started = System.currentTimeMillis()
        whisper.transcribeAsync(
            pcm,
            currentModelFile ?: VoiceCatalog.STT_WHISPER_TINY.fileName,
            whisperLanguage(currentLanguage),
        ) { result ->
            val ms = System.currentTimeMillis() - started
            result.fold(
                onSuccess = { text ->
                    emitEvent(
                        "result",
                        JSObject()
                            .put("final", true)
                            .put("source", "whisper")
                            .put("text", text)
                            .put("sttMs", ms)
                            .put("samples", pcm.size)
                            .put("reason", reason),
                    )
                },
                onFailure = { e ->
                    emitEvent(
                        "error",
                        JSObject().put("code", "transcribe").put("message", e.message ?: "erro"),
                    )
                },
            )
        }
    }

    private fun releaseCapture() {
        capture?.stop()
        capture = null
        vad?.close()
        vad = null
        assembler = null
    }

    private fun stopAll() {
        system?.stop()
        system = null
        releaseCapture()
        isCapturing = false
        activeEngine = null
    }

    fun release() {
        stopAll()
        whisper.release()
    }

    // ------------------------------------------------------------- events --

    private val systemCallback = object : SystemSpeechController.Callback {
        override fun onPartial(text: String) {
            emitEvent("partial", JSObject().put("text", text))
        }

        override fun onFinal(text: String) {
            isCapturing = false
            activeEngine = null
            emitEvent(
                "result",
                JSObject()
                    .put("final", true)
                    .put("source", "system")
                    .put("text", text),
            )
        }

        override fun onError(code: String) {
            isCapturing = false
            activeEngine = null
            emitEvent("error", JSObject().put("code", code))
        }

        override fun onLevel(level: Float) {
            maybeEmitLevel(level)
        }
    }

    private fun SystemSpeechController.stopListeningSafe() {
        try {
            stop()
        } catch (_: Exception) {
        }
        // O resultado final chega pelo RecognitionListener.onResults.
    }

    private fun emitEvent(type: String, payload: JSObject) {
        emit(payload.put("type", type))
    }

    /** Modelo de download/progresso por evento (UI mostra barra). */
    fun downloadModel(kind: String, id: String) {
        val model = when (kind) {
            "stt" -> VoiceCatalog.sttById(id)
            "vad" -> if (id == VoiceCatalog.VAD_SILERO.id) VoiceCatalog.VAD_SILERO else null
            else -> null
        }
        if (model == null) {
            emitEvent("modelError", JSObject().put("kind", kind).put("id", id).put("message", "modelo desconhecido"))
            return
        }
        val manager = com.carsaimz.genyassistant.ai.ModelManager(context)
        manager.download(
            url = model.url,
            name = model.fileName,
            kind = model.kind,
            expectedSha256 = model.sha256,
            onProgress = { bytes, total ->
                val totalSafe = if (total > 0) total else model.bytes
                emitEvent(
                    "modelProgress",
                    JSObject()
                        .put("kind", kind)
                        .put("id", id)
                        .put("bytes", bytes)
                        .put("total", totalSafe),
                )
            },
            onDone = { result ->
                result.fold(
                    onSuccess = {
                        emitEvent("modelReady", JSObject().put("kind", kind).put("id", id))
                    },
                    onFailure = { e ->
                        emitEvent(
                            "modelError",
                            JSObject().put("kind", kind).put("id", id).put("message", e.message ?: "erro"),
                        )
                    },
                )
            },
        )
    }

    fun deleteModel(fileName: String): Boolean {
        return com.carsaimz.genyassistant.ai.ModelManager(context).delete(fileName)
    }

    companion object {
        /** BCP47 → ISO-639-1 para o whisper ("pt-BR" → "pt"). */
        fun whisperLanguage(tag: String): String {
            val base = tag.substringBefore('-').lowercase()
            return if (base.length == 2 && base.all { it in 'a'..'z' }) base else "auto"
        }
    }
}
