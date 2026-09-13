package com.carsaimz.genyassistant.voice

import android.content.Context
import java.io.File
import java.util.concurrent.Executors

/**
 * STT local — transcrição com whisper.cpp (docs §7.2, TODO core-02).
 *
 * **PT** Um processo por vez (executor single-thread): carrega o modelo do
 * disco, transcreve o PCM capturado e devolve o texto. Modelos são os GGML
 * do catálogo (`VoiceCatalog.STT_*`), baixados sob demanda com SHA-256.
 * A biblioteca nativa pode não existir em builds sem NDK — `isAvailable`
 * cobre isso e a UI orienta o usuário.
 * **EN** One job at a time (single-thread executor): loads the model from
 * disk, transcribes the captured PCM and returns the text. Models are the
 * GGML files from `VoiceCatalog.STT_*`, downloaded on demand with SHA-256.
 * The native library may be absent in non-NDK builds — `isAvailable` covers
 * that and the UI guides the user.
 */
class WhisperSttEngine(private val context: Context) {

    private val executor = Executors.newSingleThreadExecutor()
    private var ptr: Long = 0L
    private var loadedModel: String? = null
    private val threads: Int = (Runtime.getRuntime().availableProcessors() / 2).coerceIn(2, 4)

    val isAvailable: Boolean
        get() = WhisperJni.available

    /** Caminho do modelo GGML baixado, ou null se não existe. */
    fun modelFile(fileName: String): File? {
        val f = File(File(context.filesDir, "models"), fileName)
        return if (f.exists() && f.length() > 0) f else null
    }

    /**
     * Transcreve PCM i16 mono 16 kHz com o modelo indicado. Em caso de falha
     * devolve Result.failure com a mensagem para a UI.
     */
    fun transcribeAsync(
        pcm: ShortArray,
        modelFileName: String,
        language: String,
        onDone: (Result<String>) -> Unit,
    ) {
        executor.execute {
            onDone(
                try {
                    Result.success(transcribeBlocking(pcm, modelFileName, language))
                } catch (e: Exception) {
                    Result.failure(e)
                },
            )
        }
    }

    @Synchronized
    private fun transcribeBlocking(pcm: ShortArray, modelFileName: String, language: String): String {
        require(WhisperJni.available) { "whisper nativo indisponível nesta build" }
        if (pcm.isEmpty()) return ""
        val model = modelFile(modelFileName)
            ?: IllegalStateException("modelo não baixado: $modelFileName")
            .let { throw it }

        // Reativa o modelo só quando troca (carregar GGML custa segundos).
        if (ptr == 0L || loadedModel != model.absolutePath) {
            freeLocked()
            ptr = WhisperJni.nativeInit(model.absolutePath, threads)
            if (ptr == 0L) throw IllegalStateException("falha ao carregar modelo: $modelFileName")
            loadedModel = model.absolutePath
        }

        val floats = FloatArray(pcm.size) { pcm[it] / 32768f }
        val text = WhisperJni.nativeTranscribe(ptr, floats, language.ifBlank { "auto" }, threads)
        return text.trim()
    }

    private fun freeLocked() {
        if (ptr != 0L) {
            WhisperJni.nativeFree(ptr)
            ptr = 0L
            loadedModel = null
        }
    }

    @Synchronized
    fun release() {
        freeLocked()
    }
}
