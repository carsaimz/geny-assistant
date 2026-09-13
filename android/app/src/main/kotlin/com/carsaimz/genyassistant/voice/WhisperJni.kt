package com.carsaimz.genyassistant.voice

/**
 * JNI bindings do whisper.cpp (docs §7.2, TODO core-02).
 *
 * **PT** A biblioteca nativa `libgeny_whisper_jni.so` é construída pelo
 * CMake (android/app/src/main/cpp) a partir do submodule pinado
 * `native/whisper.cpp`. Se o .so não estiver no APK (build sem NDK), o load
 * falha silenciosamente e o provider reporta indisponível — o app nunca
 * quebra por causa do whisper.
 * **EN** The `libgeny_whisper_jni.so` native library is built by CMake
 * (android/app/src/main/cpp) from the pinned `native/whisper.cpp` submodule.
 * If the .so is not in the APK (build without NDK), loading fails silently
 * and the provider reports unavailable — the app never breaks because of
 * whisper.
 */
object WhisperJni {

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
                            System.loadLibrary("geny_whisper_jni")
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

    // Assinaturas JNI — implementadas em android/app/src/main/cpp/geny_whisper_jni.cpp

    /** Carrega o modelo GGML do disco; devolve ponteiro do contexto (0 = falha). */
    external fun nativeInit(modelPath: String, threads: Int): Long

    /** Libera o contexto do whisper. */
    external fun nativeFree(ptr: Long)

    /**
     * Transcreve PCM float mono 16 kHz (faixa -1..1). `language` no formato
     * ISO-639-1 ("pt", "en"…) ou "auto" para detecção automática.
     */
    external fun nativeTranscribe(ptr: Long, samples: FloatArray, language: String, threads: Int): String
}
