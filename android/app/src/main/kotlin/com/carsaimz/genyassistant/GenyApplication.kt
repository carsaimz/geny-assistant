package com.carsaimz.genyassistant

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager

/** Application do Geny Assistant — inicializa canais de notificação. */
class GenyApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            CHANNEL_ASSISTANT,
            getString(R.string.notif_channel_assistant),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = getString(R.string.notif_channel_assistant_desc)
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val CHANNEL_ASSISTANT = "geny_assistant"
    }
}
