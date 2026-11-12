package com.privateagent.private_agent

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.mediapipe.tasks.genai.llminference.LlmInference
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * On-device LLM inference for Geny's offline mode.
 *
 * Uses MediaPipe GenAI (LiteRT) to run downloadable models (e.g. Gemma 3
 * int4 .task files) entirely on the phone — no server, no internet needed
 * once the model file is downloaded inside the app.
 *
 * Channel: `com.privateagent/local_llm`
 *   loadModel(path, maxTokens, temperature) -> {ok, error?}
 *   isLoaded -> bool
 *   unload -> bool
 *   generate(prompt) -> {ok, text|error}
 *   generateStream(prompt) -> stream of partial chunks (string events),
 *                             final event is a JSON {"done": true}
 */
object GenyLocalLlm {
    private const val CHANNEL = "com.privateagent/local_llm"
    private const val TAG = "GENY_LLM"

    private var llm: LlmInference? = null
    private var loadedPath: String? = null
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    fun register(flutterEngine: FlutterEngine) {
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "loadModel" -> {
                    val path = call.argument<String>("path")
                    val maxTokens = (call.argument<Number>("maxTokens") ?: 1024).toInt()
                    val temperature = (call.argument<Number>("temperature") ?: 0.7).toDouble()
                    if (path.isNullOrBlank() || !File(path).exists()) {
                        result.success(mapOf("ok" to false, "error" to "Model file not found: $path"))
                    } else {
                        executor.execute {
                            try {
                                unloadInternal()
                                val options = LlmInference.LlmInferenceOptions.builder()
                                    .setModelPath(path)
                                    .setMaxTokens(maxTokens)
                                    .setTemperature(temperature.toFloat())
                                    .build()
                                val instance = LlmInference.createFromOptions(
                                    applicationContext(), options
                                )
                                llm = instance
                                loadedPath = path
                                Log.i(TAG, "Model loaded: $path")
                                mainHandler.post {
                                    result.success(mapOf("ok" to true))
                                }
                            } catch (e: Exception) {
                                Log.e(TAG, "loadModel failed: ${e.message}")
                                mainHandler.post {
                                    result.success(mapOf("ok" to false, "error" to (e.message ?: "load failed")))
                                }
                            }
                        }
                    }
                }

                "isLoaded" -> result.success(llm != null)

                "loadedPath" -> result.success(loadedPath)

                "unload" -> {
                    executor.execute { unloadInternal() }
                    result.success(true)
                }

                "generate" -> {
                    val prompt = call.argument<String>("prompt") ?: ""
                    val instance = llm
                    if (instance == null) {
                        result.success(mapOf("ok" to false, "error" to "No model loaded"))
                    } else {
                        executor.execute {
                            try {
                                val text = instance.generateResponse(prompt)
                                mainHandler.post {
                                    result.success(mapOf("ok" to true, "text" to text))
                                }
                            } catch (e: Exception) {
                                Log.e(TAG, "generate failed: ${e.message}")
                                mainHandler.post {
                                    result.success(mapOf("ok" to false, "error" to (e.message ?: "generation failed")))
                                }
                            }
                        }
                    }
                }

                "generateStream" -> {
                    val prompt = call.argument<String>("prompt") ?: ""
                    val instance = llm
                    if (instance == null) {
                        result.error("NOT_LOADED", "No model loaded", null)
                    } else {
                        executor.execute {
                            try {
                                instance.generateResponseAsync(prompt) { partial, done ->
                                    mainHandler.post {
                                        channel.invokeMethod(
                                            "onStream",
                                            mapOf("partial" to partial, "done" to done)
                                        )
                                    }
                                }
                            } catch (e: Exception) {
                                Log.e(TAG, "generateStream failed: ${e.message}")
                                mainHandler.post {
                                    channel.invokeMethod(
                                        "onStreamError",
                                        mapOf("error" to (e.message ?: "stream failed"))
                                    )
                                }
                            }
                        }
                        result.success(true)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun unloadInternal() {
        try {
            llm?.close()
        } catch (e: Exception) {
            Log.w(TAG, "unload warning: ${e.message}")
        }
        llm = null
        loadedPath = null
    }

    private fun applicationContext(): android.content.Context {
        return AppContextHolder.context
    }
}

/** Static application context holder (registered from MainActivity). */
object AppContextHolder {
    @Volatile
    var context: android.content.Context? = null
}
