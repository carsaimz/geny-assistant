package com.carsaimz.genyassistant.voice

import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.carsaimz.genyassistant.GenyApplication
import com.carsaimz.genyassistant.MainActivity
import com.carsaimz.genyassistant.R
import java.io.File

/**
 * Wake word em segundo plano (Fase 3, TODO android-03b) — serviço em
 * primeiro plano com microfone, DESLIGADO POR PADRÃO: só roda quando a
 * pessoa ativa explicitamente nas configurações.
 *
 * **PT** Captura 30 ms de áudio com o mesmo [AudioCaptureController] da
 * conversa por voz e alimenta o [OpenWakeWordEngine]. Ao disparar: emite
 * `{type: "triggered", score}` no canal `genyWake` (a UI web abre a tela de
 * voz) e publica notificação de tap para abrir o app quando ele está
 * fechado. Nada de áudio sai do dispositivo.
 * **EN** Captures 30 ms audio with the same [AudioCaptureController] used by
 * voice chat and feeds [OpenWakeWordEngine]. On trigger: emits
 * `{type: "triggered", score}` on the `genyWake` channel (web UI opens the
 * voice screen) and posts a tap notification to open the app when closed.
 * No audio ever leaves the device.
 */
class WakeWordService : Service() {

    private var capture: AudioCaptureController? = null
    private var engine: OpenWakeWordEngine? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopListening()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                val modelFile = intent?.getStringExtra(EXTRA_MODEL)
                    ?: WakeWordCatalog.WAKE_WORDS.first().fileName
                startListening(modelFile)
            }
        }
        return START_STICKY
    }

    private fun startListening(modelFileName: String) {
        if (engine != null) return // já em execução
        if (checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            emit("error", JSObjectLike().put("code", "permission"))
            stopSelf()
            return
        }
        val modelsDir = File(filesDir, "models")
        if (!OpenWakeWordEngine.featuresReady(modelsDir) || !File(modelsDir, modelFileName).exists()) {
            emit("error", JSObjectLike().put("code", "model_missing"))
            stopSelf()
            return
        }
        startForeground(NOTIF_ID, buildNotification())
        try {
            val wakeEngine = OpenWakeWordEngine(modelsDir, modelFileName)
            engine = wakeEngine
            val controller = AudioCaptureController(
                config = VadConfig(),
                onFrame = { frame ->
                    val result = try {
                        wakeEngine.process(frame)
                    } catch (_: Exception) {
                        null
                    }
                    if (result != null && result.triggered) {
                        emit(
                            "triggered",
                            JSObjectLike().put("score", result.score.toDouble()).put("model", modelFileName),
                        )
                        notifyTapToOpen(result.score)
                    }
                },
                onMaxDuration = { /* wake word roda contínuo: sem limite */ },
                onError = {
                    emit("error", JSObjectLike().put("code", "capture"))
                    stopListening()
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelf()
                },
            )
            capture = controller
            if (!controller.start(maxDurationMs = Long.MAX_VALUE)) {
                stopListening()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            emit("listening", JSObjectLike().put("model", modelFileName))
        } catch (e: Exception) {
            stopListening()
            emit("error", JSObjectLike().put("code", "engine").put("message", e.message ?: "erro"))
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    private fun stopListening() {
        capture?.stop()
        capture = null
        engine?.close()
        engine = null
    }

    override fun onDestroy() {
        stopListening()
        super.onDestroy()
    }

    // ------------------------------------------------------------- notificação --

    /** Notificação de "toque para responder" — abrir activity em segundo plano exige interação. */
    private fun notifyTapToOpen(score: Float) {
        val manager = getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
        val open = PendingIntent.getActivity(
            this,
            1,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(this, GenyApplication.CHANNEL_ASSISTANT)
            .setSmallIcon(R.drawable.ic_launcher)
            .setContentTitle(getString(R.string.wake_word_detected))
            .setContentText(getString(R.string.wake_word_tap_to_open))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_SYSTEM)
            .setAutoCancel(true)
            .setContentIntent(open)
            .build()
        try {
            manager.notify(NOTIF_ID + 1, notification)
        } catch (_: Exception) {
        }
    }

    private fun buildNotification(): Notification =
        NotificationCompat.Builder(this, GenyApplication.CHANNEL_ASSISTANT)
            .setSmallIcon(R.drawable.ic_launcher)
            .setContentTitle(getString(R.string.wake_word_listening_title))
            .setContentText(getString(R.string.wake_word_listening_text))
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()

    // ------------------------------------------------------------------ eventos --

    /** Payload mínimo para não depender de Capacitor dentro do serviço. */
    class JSObjectLike {
        val map = LinkedHashMap<String, Any>()

        fun put(key: String, value: Any): JSObjectLike {
            map[key] = value
            return this
        }
    }

    private fun emit(type: String, payload: JSObjectLike) {
        eventSink?.invoke(payload.map + mapOf("type" to type))
    }

    companion object {
        const val ACTION_START = "com.carsaimz.genyassistant.voice.WAKE_START"
        const val ACTION_STOP = "com.carsaimz.genyassistant.voice.WAKE_STOP"
        const val EXTRA_MODEL = "model"
        const val NOTIF_ID = 1002

        /** Ponte para o GenyPlugin (canal `genyWake`), como TtsService.eventSink. */
        @Volatile
        var eventSink: ((Map<String, Any>) -> Unit)? = null
    }
}
