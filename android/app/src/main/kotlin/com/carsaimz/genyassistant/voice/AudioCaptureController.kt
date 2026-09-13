package com.carsaimz.genyassistant.voice

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder

/**
 * Captura de áudio em contexto (docs §7.1, TODO android-01): AudioRecord
 * 16 kHz mono PCM 16-bit, frames de 480 amostras (30 ms) — o mesmo
 * enquadramento esperado pelo Silero e pelo whisper.cpp. A permissão
 * RECORD_AUDIO é verificada ANTES de `start` e solicitada só no momento de
 * uso (nunca no arranque do app).
 */
class AudioCaptureController(
    private val config: VadConfig = VadConfig(),
    private val onFrame: (ShortArray) -> Unit,
    private val onMaxDuration: () -> Unit,
    private val onError: (String) -> Unit,
) {

    @Volatile
    var isRunning: Boolean = false
        private set

    private var record: AudioRecord? = null
    private var thread: Thread? = null

    /** Timestamp (ms) em que a captura começou; usado para limitar duração. */
    @Volatile
    private var startedAt = 0L

    val elapsedMs: Long
        get() = if (isRunning) System.currentTimeMillis() - startedAt else 0L

    @SuppressLint("MissingPermission") // verificada pelo chamador (VoiceManager)
    fun start(maxDurationMs: Long = DEFAULT_MAX_DURATION_MS): Boolean {
        if (isRunning) return true
        val minBuf = AudioRecord.getMinBufferSize(
            config.sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        if (minBuf <= 0) {
            onError("buffer de audio invalido: $minBuf")
            return false
        }
        val bufferSize = maxOf(minBuf, config.frameSamples * 8)
        val audio = try {
            AudioRecord(
                MediaRecorder.AudioSource.MIC,
                config.sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufferSize,
            )
        } catch (e: Exception) {
            onError("falha ao abrir microfone: ${e.message}")
            return false
        }
        if (audio.state != AudioRecord.STATE_INITIALIZED) {
            audio.release()
            onError("microfone indisponível (state=${audio.state})")
            return false
        }
        record = audio
        startedAt = System.currentTimeMillis()
        isRunning = true
        audio.startRecording()

        thread = Thread({
            try {
                Thread.currentThread().priority = Thread.MAX_PRIORITY
            } catch (_: Exception) {
            }
            val frame = ShortArray(config.frameSamples)
            var maxDurationNotified = false
            try {
                while (isRunning) {
                    var offset = 0
                    // Lê um frame completo (480 amostras) mesmo com leituras parciais.
                    while (offset < frame.size && isRunning) {
                        val read = audio.read(frame, offset, frame.size - offset)
                        if (read < 0) throw IllegalStateException("leitura de audio falhou: $read")
                        if (read == 0) continue
                        offset += read
                    }
                    if (!isRunning) break
                    onFrame(frame.copyOf())
                    if (!maxDurationNotified && elapsedMs >= maxDurationMs) {
                        maxDurationNotified = true
                        onMaxDuration()
                    }
                }
            } catch (e: Exception) {
                if (isRunning) onError(e.message ?: "erro de captura")
            }
        }, "geny-voice-capture").also { it.start() }
        return true
    }

    /** Para a captura e libera o microfone; seguro chamar várias vezes. */
    fun stop() {
        isRunning = false
        try {
            thread?.join(1_000)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        }
        thread = null
        record?.run {
            try {
                stop()
            } catch (_: Exception) {
            }
            release()
        }
        record = null
    }

    companion object {
        const val DEFAULT_MAX_DURATION_MS: Long = 60_000L
    }
}
