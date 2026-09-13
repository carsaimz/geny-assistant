package com.carsaimz.genyassistant.voice

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer

/**
 * STT pelo reconhecedor do sistema, on-device (docs §7.2, TODO core-02).
 *
 * **PT** Provider "sistema": funciona de fábrica em aparelhos com pacote de
 * reconhecimento offline (a maioria dos Androids modernos baixa os idiomas
 * junto com o teclado). No Android 12+ usa
 * `createOnDeviceSpeechRecognizer` — garantia de que o áudio NÃO sai do
 * aparelho (local-first); antes disso usa o SpeechRecognizer normal com
 * `EXTRA_PREFER_OFFLINE = true`. Este provider gerencia o próprio microfone
 * (streaming), por isso coexiste com o pipeline whisper/ÁudioRecord apenas
 * em modos diferentes.
 * **EN** System-recognizer provider: works out of the box on devices with
 * the offline recognition package (most modern Androids ship it with the
 * keyboard). On Android 12+ it uses `createOnDeviceSpeechRecognizer` — a
 * guarantee that audio NEVER leaves the device (local-first); below that it
 * uses the regular SpeechRecognizer with `EXTRA_PREFER_OFFLINE = true`.
 * This provider owns the microphone (streaming), so it coexists with the
 * whisper/AudioRecord pipeline only in different modes.
 */
class SystemSpeechController(
    private val context: Context,
    private val callback: Callback,
) : RecognitionListener {

    interface Callback {
        fun onPartial(text: String)
        fun onFinal(text: String)
        fun onError(code: String)
        fun onLevel(level: Float)
    }

    private var recognizer: SpeechRecognizer? = null

    val isAvailable: Boolean
        get() = SpeechRecognizer.isRecognitionAvailable(context)

    fun start(languageTag: String) {
        stop()
        // createOnDeviceSpeechRecognizer lança em aparelhos sem o pacote
        // offline mesmo com isRecognitionAvailable == true — protege o toque.
        val rec = try {
            createRecognizer()
        } catch (e: Exception) {
            recognizer = null
            callback.onError("unavailable")
            return
        }
        recognizer = rec
        rec.setRecognitionListener(this)

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, languageTag)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            // Local-first: prefere o pacote offline sempre que existir.
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
        }
        // SpeechRecognizer.startListening lança RejectedExecutionException
        // quando o serviço de reconhecimento está ocupado (crash clássico
        // "app parou" ao tocar no microfone) e SecurityException sem permissão.
        try {
            rec.startListening(intent)
        } catch (e: Exception) {
            recognizer = null
            try {
                rec.destroy()
            } catch (_: Exception) {
            }
            callback.onError("busy")
        }
    }

    private fun createRecognizer(): SpeechRecognizer =
        if (android.os.Build.VERSION.SDK_INT >= 31) {
            SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
        } else {
            SpeechRecognizer.createSpeechRecognizer(context)
        }

    fun stop() {
        recognizer?.run {
            try {
                stopListening()
                destroy()
            } catch (_: Exception) {
            }
        }
        recognizer = null
    }

    // ------------------------------------------------- RecognitionListener --

    override fun onReadyForSpeech(params: Bundle?) = Unit

    override fun onBeginningOfSpeech() = Unit

    override fun onRmsChanged(rmsdB: Float) {
        // rmsdB em dB (-2..12 aprox.) → nível linear 0..1 para a UI.
        val normalized = ((rmsdB + 2f) / 14f).coerceIn(0f, 1f)
        callback.onLevel(normalized)
    }

    override fun onBufferReceived(buffer: ByteArray?) = Unit

    override fun onEndOfSpeech() = Unit

    override fun onError(error: Int) {
        val code = when (error) {
            SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "no_speech"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "denied"
            else -> "speech_error_$error"
        }
        callback.onError(code)
    }

    override fun onResults(results: Bundle?) {
        val text = results
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.firstOrNull()
            .orEmpty()
        if (text.isBlank()) {
            callback.onError("no_speech")
        } else {
            callback.onFinal(text)
        }
    }

    override fun onPartialResults(partialResults: Bundle?) {
        partialResults
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.firstOrNull()
            ?.takeIf { it.isNotBlank() }
            ?.let { callback.onPartial(it) }
    }

    override fun onEvent(eventType: Int, params: Bundle?) = Unit
}
