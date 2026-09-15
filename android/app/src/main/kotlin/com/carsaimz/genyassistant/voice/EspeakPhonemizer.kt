package com.carsaimz.genyassistant.voice

import java.io.File

/**
 * Wrapper JNI do espeak-ng (TODO core-03 — docs §7.4).
 *
 * **PT** A lib nativa `libgeny_espeak_jni.so` é construída pelo CMake do app
 * a partir do submodule pinado `native/espeak-ng` (mesmo pin do sherpa-onnx).
 * Se o .so não estiver no APK, o load falha silenciosamente e `available`
 * reporta falso — o TTS do sistema continua sendo o fallback. O espeak roda
 * com AUDIO_OUTPUT_SYNCHRONOUS: só produzimos fonemas IPA; o áudio vem do
 * modelo VITS via ONNX Runtime (PiperTtsEngine). Estado global: init uma vez
 * por processo; trocas de voz são chamadas subsequentes (serializadas pelo
 * executor do TtsService).
 * **EN** The `libgeny_espeak_jni.so` native lib is built by the app's CMake
 * from the pinned `native/espeak-ng` submodule (same pin as sherpa-onnx). If
 * the .so is not in the APK, loading fails silently and `available` reports
 * false — system TTS remains the fallback. espeak runs with
 * AUDIO_OUTPUT_SYNCHRONOUS: we only produce IPA phonemes; audio comes from
 * the VITS model via ONNX Runtime (PiperTtsEngine). Global state: init once
 * per process; voice switches are subsequent calls (serialized by the
 * TtsService executor).
 */
object EspeakPhonemizer {

    @Volatile
    private var loadAttempted = false

    @Volatile
    private var loadOk = false

    /** true quando a lib nativa carregou nesta instalação. */
    val available: Boolean
        get() {
            if (!loadAttempted) {
                synchronized(this) {
                    if (!loadAttempted) {
                        loadAttempted = true
                        loadOk = try {
                            System.loadLibrary("geny_espeak_jni")
                            true
                        } catch (_: UnsatisfiedLinkError) {
                            false
                        } catch (_: SecurityException) {
                            false
                        }
                    }
                }
            }
            return loadOk
        }

    @Volatile
    private var initialized = false

    /**
     * Inicializa o espeak com o diretório espeak-ng-data (extraído do ZIP).
     * Idempotente; devolve false se a lib ou os dados não estiverem ok.
     */
    fun initIfNeeded(dataDir: File): Boolean {
        if (!available) return false
        if (initialized) return true
        synchronized(this) {
            if (initialized) return true
            initialized = try {
                nativeInit(dataDir.absolutePath)
            } catch (_: Exception) {
                false
            }
            return initialized
        }
    }

    /** Seleciona a voz espeak (ex.: "pt-br"); false se falhar. */
    fun setVoice(voice: String): Boolean = try {
        nativeSetVoice(voice)
    } catch (_: Exception) {
        false
    }

    /** Texto → fonemas IPA com pontuação (algoritmo do piper-phonemize). */
    fun phonemize(text: String): String = try {
        nativePhonemize(text) ?: ""
    } catch (_: Exception) {
        ""
    }

    private external fun nativeInit(dataPath: String): Boolean
    private external fun nativeSetVoice(voice: String): Boolean
    private external fun nativePhonemize(text: String): String
    private external fun nativeTerminate()
}
