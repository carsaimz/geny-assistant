package com.carsaimz.genyassistant.voice

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.util.Log
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicReference
import java.util.zip.ZipInputStream

/**
 * Gerenciador do TTS neural Piper (TODO core-03 — docs §7.4).
 *
 * **PT** Cola entre a ponte (TtsService) e o motor: extrai o espeak-ng-data
 * do ZIP baixado, resolve a voz pelo idioma, mantém um cache de 1 engine
 * (sessão ORT do modelo de ~63 MB) e toca o áudio sintetizado por AudioTrack
 * em um executor dedicado. Falhas viram `error` no canal `genyTts` — o
 * fallback para o TTS do sistema fica no TtsService.
 * **EN** Glue between the bridge (TtsService) and the engine: extracts the
 * downloaded espeak-ng-data ZIP, resolves the voice for the language, keeps
 * a 1-entry engine cache (~63 MB model ORT session) and plays synthesized
 * audio via AudioTrack on a dedicated executor. Failures become `error` on
 * the `genyTts` channel — system TTS fallback stays in TtsService.
 */
object PiperTts {

    private const val TAG = "geny-piper"
    private const val DATA_DIR = "espeak-ng-data"
    private const val MARKER = ".ok"

    private val executor: ExecutorService =
        Executors.newSingleThreadExecutor { r ->
            Thread(r, "geny-piper").apply { priority = Thread.NORM_PRIORITY - 1 }
        }

    private val currentTrack = AtomicReference<AudioTrack?>(null)
    private var cachedEngine: PiperTtsEngine? = null
    private var cachedModelPath: String? = null

    // ------------------------------------------------------------ arquivos --

    fun espeakDataDir(context: Context): File = File(context.filesDir, DATA_DIR)

    /** true quando o espeak-ng-data extraído está marcado como completo. */
    fun isEspeakDataReady(context: Context): Boolean =
        File(espeakDataDir(context), MARKER).exists()

    /** Arquivo .onnx da voz baixado no diretório de modelos (ou null). */
    fun downloadedVoiceFile(context: Context, voice: PiperVoiceInfo): File? {
        val f = File(File(context.filesDir, "models"), voice.fileName)
        return if (f.exists() && f.length() > 1_000_000L) f else null
    }

    fun voiceForLanguage(context: Context, language: String): PiperVoiceInfo? =
        PiperVoiceCatalog.voiceForLanguage(language)?.let { v ->
            if (downloadedVoiceFile(context, v) != null) v else null
        }

    /** Piper utilizável para o idioma: JNI + dados espeak + voz baixada. */
    fun isReadyFor(context: Context, language: String): Boolean {
        if (!EspeakPhonemizer.available || !isEspeakDataReady(context)) return false
        return voiceForLanguage(context, language) != null
    }

    /**
     * Extrai o ZIP do espeak-ng-data (download do ModelManager) para
     * filesDir/espeak-ng-data. Defesa contra path traversal: caminhos fora
     * do diretório de destino são ignorados. Marca .ok ao concluir.
     */
    fun extractEspeakData(context: Context, zipFile: File): Boolean {
        val dest = espeakDataDir(context)
        try {
            dest.deleteRecursively()
            dest.mkdirs()
            ZipInputStream(zipFile.inputStream().buffered()).use { zip ->
                var entry = zip.nextEntry
                var count = 0
                while (entry != null) {
                    if (entry.isDirectory) {
                        entry = zip.nextEntry
                        continue
                    }
                    val out = File(dest, entry.name)
                    if (!out.canonicalPath.startsWith(dest.canonicalPath)) {
                        Log.w(TAG, "entrada suspeita no zip: ${entry.name}")
                        entry = zip.nextEntry
                        continue
                    }
                    out.parentFile?.mkdirs()
                    out.outputStream().use { zip.copyTo(it) }
                    count++
                    entry = zip.nextEntry
                }
                Log.i(TAG, "espeak-ng-data extraído: $count arquivos")
            }
            File(dest, MARKER).writeText("ok")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "falha ao extrair espeak-ng-data", e)
            dest.deleteRecursively()
            return false
        }
    }

    /** Remove os dados extraídos (chamado ao apagar o ZIP). */
    fun deleteEspeakData(context: Context) {
        espeakDataDir(context).deleteRecursively()
        closeEngine()
    }

    // ------------------------------------------------------------- engine --

    private fun obtainEngine(context: Context, voice: PiperVoiceInfo, model: File): PiperTtsEngine? {
        cachedEngine?.let { cached ->
            if (cachedModelPath == model.absolutePath) return cached
            closeEngine()
        }
        return try {
            val engine = PiperTtsEngine(model, voice.jsonAsset, context.assets)
            cachedEngine = engine
            cachedModelPath = model.absolutePath
            engine
        } catch (e: Exception) {
            Log.e(TAG, "falha ao carregar engine piper (${voice.id})", e)
            null
        }
    }

    private fun closeEngine() {
        try {
            cachedEngine?.close()
        } catch (_: Exception) {
        }
        cachedEngine = null
        cachedModelPath = null
    }

    /**
     * Sintetiza e toca `text` no executor dedicado. `onEvent` emite
     * "start" | "done" | "error" (mesmo contrato do TTS do sistema).
     * Devolve false imediatamente quando o piper não está pronto.
     */
    fun speak(context: Context, text: String, language: String, onEvent: (String) -> Unit): Boolean {
        val voice = voiceForLanguage(context, language)
        if (voice == null || !isEspeakDataReady(context) || !EspeakPhonemizer.available) {
            return false
        }
        val model = downloadedVoiceFile(context, voice) ?: return false
        executor.execute {
            try {
                if (!EspeakPhonemizer.initIfNeeded(espeakDataDir(context))) {
                    onEvent("error")
                    return@execute
                }
                if (!EspeakPhonemizer.setVoice(voice.espeakVoice)) {
                    onEvent("error")
                    return@execute
                }
                val engine = obtainEngine(context, voice, model)
                if (engine == null) {
                    onEvent("error")
                    return@execute
                }
                val audio = engine.synthesize(text)
                if (audio.isEmpty()) {
                    onEvent("error")
                    return@execute
                }
                playBlocking(engine.sampleRate, audio)
                onEvent("done")
            } catch (e: Exception) {
                Log.e(TAG, "fala piper falhou", e)
                onEvent("error")
            }
        }
        return true
    }

    /** Parada imediata do áudio em andamento. */
    fun stop() {
        currentTrack.getAndSet(null)?.let { track ->
            try {
                track.pause()
                track.flush()
                track.stop()
                track.release()
            } catch (_: Exception) {
            }
        }
    }

    /** Áudio float [-1,1] → PCM 16-bit mono no AudioTrack (bloqueante). */
    private fun playBlocking(sampleRate: Int, audio: FloatArray) {
        val minBuf = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        ).coerceAtLeast(8_192)
        val track = AudioTrack(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build(),
            AudioFormat.Builder()
                .setSampleRate(sampleRate)
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                .build(),
            minBuf,
            AudioTrack.MODE_STREAM,
            AudioManager.AUDIO_SESSION_ID_GENERATE,
        )
        if (!currentTrack.compareAndSet(null, track)) {
            // stop() chegou antes: não toca.
            try {
                track.release()
            } catch (_: Exception) {
            }
            return
        }
        try {
            track.play()
            val pcm = ShortArray(2_048)
            var i = 0
            while (i < audio.size) {
                if (currentTrack.get() !== track) return // cancelado
                val n = minOf(pcm.size, audio.size - i)
                for (j in 0 until n) {
                    val v = audio[i + j].coerceIn(-1f, 1f)
                    pcm[j] = (v * 32_767f).toInt().toShort()
                }
                track.write(pcm, 0, n)
                i += n
            }
            // Drena o buffer interno: espera o head position alcançar o fim.
            while (currentTrack.get() === track &&
                track.playState == AudioTrack.PLAYSTATE_PLAYING &&
                track.playbackHeadPosition < audio.size
            ) {
                Thread.sleep(50)
            }
            track.stop()
        } finally {
            try {
                track.release()
            } catch (_: Exception) {
            }
            currentTrack.compareAndSet(track, null)
        }
    }
}
