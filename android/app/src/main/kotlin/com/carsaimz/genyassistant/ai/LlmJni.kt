package com.carsaimz.genyassistant.ai

/**
 * JNI bindings do llama.cpp (docs §6, TODO core-05).
 *
 * **PT** A biblioteca nativa `libgeny_llama_jni.so` é construída pelo CMake
 * (android/app/src/main/cpp) a partir do submodule pinado `native/llama.cpp`
 * (v0.4.0). Se o .so não estiver no APK (build sem o submodule), o load
 * falha silenciosamente e `available` reporta falso — o app nunca quebra
 * por causa do LLM local.
 * **EN** The `libgeny_llama_jni.so` native library is built by CMake
 * (android/app/src/main/cpp) from the pinned `native/llama.cpp` submodule
 * (v0.4.0). If the .so is not in the APK (build without the submodule),
 * loading fails silently and `available` reports false — the app never
 * breaks because of the local LLM.
 */
object LlmJni {

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
                            System.loadLibrary("geny_llama_jni")
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

    // Assinaturas JNI — implementadas em android/app/src/main/cpp/geny_llama_jni.cpp

    /**
     * Carrega o modelo GGUF do disco; devolve o handle do contexto
     * (0 = falha). `contextTokens` limita a janela (default 2048);
     * `threads` é o número de threads de inferência.
     */
    external fun nativeInit(modelPath: String, contextTokens: Int, threads: Int): Long

    /** Libera o modelo e o contexto. */
    external fun nativeFree(ptr: Long)

    /**
     * Gera uma resposta para o histórico de mensagens (roles/contents
     * paralelos; system é a primeira). `temperature <= 0` usa greedy.
     * Devolve JSON `{"text":…,"tokens":…,"ms":…}` ou `{"error":…}`.
     */
    external fun nativeGenerate(
        ptr: Long,
        system: String,
        roles: Array<String>,
        contents: Array<String>,
        maxTokens: Int,
        temperature: Float,
        topP: Float,
        seed: Int,
    ): String

    /**
     * Igual a [nativeGenerate], mas invoca `callback.onToken(piece)` a cada
     * peça gerada (TODO core-05b). O callback roda na mesma thread da
     * geração — o consumidor (LocalLlmManager) só emite eventos. O JSON
     * final inclui `"stopped":true` quando [nativeCancel] interrompeu.
     */
    external fun nativeGenerateStream(
        ptr: Long,
        system: String,
        roles: Array<String>,
        contents: Array<String>,
        maxTokens: Int,
        temperature: Float,
        topP: Float,
        seed: Int,
        callback: TokenCallback,
    ): String

    /** Pede a parada da geração em andamento (flag atômica no handle). */
    external fun nativeCancel(ptr: Long)
}

/** Callback por token do streaming (TODO core-05b). */
fun interface TokenCallback {
    fun onToken(token: String)
}
