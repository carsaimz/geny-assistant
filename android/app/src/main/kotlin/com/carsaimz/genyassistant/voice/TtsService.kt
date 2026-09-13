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
 * **PT** Serviço em primeiro plano (tipo mediaPlayback) com o motor
 * TextToSpeech do sistema — vozes on-device, instaladas junto com o
 * Android. Primeiro idioma da Fase 2: pt-BR, pt-PT e en; demais idiomas
 * usam a voz disponível mais próxima. Enquanto fala, mostra notificação
 * com ação de parar — a fala sobrevive à troca de app e é cancelável.
 * Piper (neural) entra na Fase 3 como segundo provider atrás da mesma
 * interface.
 * **EN** Foreground service (mediaPlayback type) running the system
 * TextToSpeech engine — on-device voices shipped with Android. Phase-2
 * languages first: pt-BR, pt-PT and en; other languages fall back to the
 * closest available voice. While speaking it shows a notification with a
 * stop action — speech survives app switches and is cancellable. Piper
 * (neural) lands in Phase 3 as a second provider behind this same
 * interface.
 */
class TtsService : Service() {

    private var tts: TextToSpeech? = null
    private var ready = false
    private var pending: MutableList<SpeakReq> = mutableListOf()

    data class SpeakReq(val text: String, val language: String)

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
                startForeground(NOTIF_ID, buildNotification())
                if (text.isNotBlank()) speak(SpeakReq(text, language))
            }
        }
        return START_NOT_STICKY
    }

    private fun speak(req: SpeakReq) {
        if (!ready) {
            pending.add(req)
            return
        }
        val engine = tts ?: return
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
        }

        override fun onDone(utteranceId: String?) {
            speakingNow = false
            // Fila vazia: encerra o serviço (remove a notificação).
            if (!tts!!.isSpeaking) stopSelf()
        }

        @Deprecated("Deprecated in Java")
        override fun onError(utteranceId: String?) {
            speakingNow = false
            stopSelf()
        }
    }

    @Volatile
    private var speakingNow = false

    private fun stopSpeaking() {
        tts?.stop()
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

        /** Fala um texto; chamada pela ponte (sempre com app visível). */
        fun speak(context: Context, text: String, language: String) {
            val intent = Intent(context, TtsService::class.java)
                .setAction(ACTION_SPEAK)
                .putExtra(EXTRA_TEXT, text)
                .putExtra(EXTRA_LANGUAGE, language)
            context.startForegroundService(intent)
        }

        /** Para a fala em andamento. */
        fun stop(context: Context) {
            context.startService(Intent(context, TtsService::class.java).setAction(ACTION_STOP))
        }
    }
}
