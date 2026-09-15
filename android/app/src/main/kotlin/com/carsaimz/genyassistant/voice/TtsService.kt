package com.carsaimz.genyassistant.voice

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import com.carsaimz.genyassistant.MainActivity
import com.carsaimz.genyassistant.R
import java.util.Locale

/**
 * TTS local em segundo plano (docs §7.3, TODO core-03/android-02).
 *
 * **PT** Serviço em primeiro plano (tipo mediaPlayback) com dois motores: o
 * TextToSpeech do sistema (vozes instaladas no Android) e, desde a Fase 3,
 * o Piper neural (TODO core-03) — vozes VITS baixadas sob demanda tocadas
 * por AudioTrack. A escolha vem da UI no request (`engine`: system|piper);
 * se o piper não está pronto, cai para o sistema sem falhar. Enquanto fala,
 * mostra notificação com ação de parar — a fala sobrevive à troca de app.
 * **EN** Foreground service (mediaPlayback type) with two engines: the
 * system TextToSpeech (voices installed with Android) and, since Phase 3,
 * the Piper neural TTS (TODO core-03) — VITS voices downloaded on demand,
 * played through AudioTrack. The choice comes from the UI in the request
 * (`engine`: system|piper); if piper is not ready it falls back to system
 * without failing. While speaking it shows a notification with a stop
 * action — speech survives app switches and is cancellable.
 */
class TtsService : Service() {

    private var tts: TextToSpeech? = null
    private var ready = false
    private var pending: MutableList<SpeakReq> = mutableListOf()

    data class SpeakReq(val text: String, val language: String, val engine: String = "system")

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        tts = TextToSpeech(this) { status ->
            ready = status == TextToSpeech.SUCCESS
            if (ready) {
                tts?.setOnUtteranceProgressListener(progressListener)
                drainPending()
            } else {
                eventSink?.invoke("error")
                stopSelf()
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSpeaking()
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_SPEAK -> {
                val text = intent.getStringExtra(EXTRA_TEXT).orEmpty()
                val language = intent.getStringExtra(EXTRA_LANGUAGE).orEmpty()
                val engine = intent.getStringExtra(EXTRA_ENGINE) ?: "system"
                startForeground(NOTIF_ID, buildNotification())
                if (text.isNotBlank()) speak(SpeakReq(text, language, engine))
            }
        }
        return START_NOT_STICKY
    }

    private fun speak(req: SpeakReq) {
        // Piper neural (TODO core-03): quando o motor foi pedido e está
        // pronto; qualquer falha vira evento de erro — sem crash.
        if (req.engine == "piper") {
            val ok = PiperTts.speak(this, req.text, req.language) { event ->
                when (event) {
                    "start" -> {
                        speakingNow = true
                        eventSink?.invoke("start")
                    }
                    "done" -> {
                        speakingNow = false
                        eventSink?.invoke("done")
                        stopSelf()
                    }
                    else -> {
                        speakingNow = false
                        eventSink?.invoke("error")
                        stopSelf()
                    }
                }
            }
            if (ok) return
            // não pronto (dados/voz ausentes): cai para o sistema abaixo
        }
        val engine = tts ?: return
        if (!ready) {
            pending.add(req)
            return
        }
        val resolved = resolveLocale(req.language)
        val result = engine.setLanguage(resolved)
        val usable = result != TextToSpeech.LANG_MISSING_DATA &&
            result != TextToSpeech.LANG_NOT_SUPPORTED
        val finalLocale = if (usable) resolved else Locale.US

        engine.speak(
            req.text,
            TextToSpeech.QUEUE_FLUSH, // nova fala substitui a anterior
            Bundle.EMPTY,
            "geny-${System.currentTimeMillis()}",
        )
        currentLocale = finalLocale
    }

    private fun drainPending() {
        val reqs = pending.toList()
        pending.clear()
        reqs.forEach { speak(it) }
    }

    private var currentLocale: Locale? = null

    private fun resolveLocale(tag: String): Locale {
        if (tag.isNotBlank()) {
            val byTag = Locale.forLanguageTag(tag)
            // pt-BR/pt-PT precisam de país para vozes distintas; demais não.
            if (byTag.country.isNotBlank() && isLocaleSupported(byTag)) return byTag
            val langOnly = Locale(byTag.language)
            if (isLocaleSupported(langOnly)) return langOnly
        }
        return Locale.getDefault()
    }

    private fun isLocaleSupported(locale: Locale): Boolean {
        val available = tts?.availableLanguages ?: return false
        return available.any { it.language == locale.language }
    }

    private val progressListener = object : UtteranceProgressListener() {
        override fun onStart(utteranceId: String?) {
            speakingNow = true
            eventSink?.invoke("start")
        }

        override fun onDone(utteranceId: String?) {
            speakingNow = false
            eventSink?.invoke("done")
            // Fila vazia: encerra o serviço (remove a notificação).
            if (tts?.isSpeaking != true) stopSelf()
        }

        @Deprecated("Deprecated in Java")
        override fun onError(utteranceId: String?) {
            speakingNow = false
            eventSink?.invoke("error")
            stopSelf()
        }
    }

    @Volatile
    private var speakingNow = false

    private fun stopSpeaking() {
        tts?.stop()
        PiperTts.stop()
        speakingNow = false
    }

    override fun onDestroy() {
        stopSpeaking()
        tts?.shutdown()
        tts = null
        super.onDestroy()
    }

    // ------------------------------------------------------- notification --

    private fun createChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.notif_channel_tts),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = getString(R.string.notif_channel_tts_desc)
            setShowBadge(false)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val openApp = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val stop = PendingIntent.getService(
            this,
            1,
            Intent(this, TtsService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            android.app.Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            android.app.Notification.Builder(this)
        }
        return builder
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle(getString(R.string.notif_tts_title))
            .setContentText(getString(R.string.notif_tts_body))
            .setContentIntent(openApp)
            .setOngoing(true)
            .addAction(
                android.R.drawable.ic_media_pause,
                getString(R.string.action_stop),
                stop,
            )
            .build()
    }

    companion object {
        const val CHANNEL_ID = "geny_voice"
        const val NOTIF_ID = 42
        const val ACTION_SPEAK = "com.carsaimz.genyassistant.voice.SPEAK"
        const val ACTION_STOP = "com.carsaimz.genyassistant.voice.STOP"
        const val EXTRA_TEXT = "text"
        const val EXTRA_LANGUAGE = "language"
        const val EXTRA_ENGINE = "engine"

        /** Fala um texto; chamada pela ponte (sempre com app visível). */
        fun speak(context: Context, text: String, language: String, engine: String = "system") {
            val intent = Intent(context, TtsService::class.java)
                .setAction(ACTION_SPEAK)
                .putExtra(EXTRA_TEXT, text)
                .putExtra(EXTRA_LANGUAGE, language)
                .putExtra(EXTRA_ENGINE, engine)
            // Se a resposta chegar com o app em segundo plano, o Android 12+
            // proíbe iniciar FGS — falha calada em vez de derrubar o app.
            try {
                context.startForegroundService(intent)
            } catch (_: Exception) {
            }
        }

        /** Para a fala em andamento. */
        fun stop(context: Context) {
            try {
                context.startService(Intent(context, TtsService::class.java).setAction(ACTION_STOP))
            } catch (_: Exception) {
            }
        }

        /**
         * Coletor de progresso da fala ("start" | "done" | "error") — a
         * ponte (GenyPlugin) registra o repassador do canal `genyTts`.
         */
        @Volatile
        var eventSink: ((String) -> Unit)? = null
    }
}
