package com.carsaimz.genyassistant.tools

import android.app.Notification
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import com.carsaimz.genyassistant.GenyApplication
import com.carsaimz.genyassistant.R

/** Receptor de alarmes de lembrete — publica notificação local. */
class ReminderReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val label = intent.getStringExtra("label") ?: context.getString(R.string.notif_reminder_title)
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return
        val notification: Notification = NotificationCompat.Builder(context, GenyApplication.CHANNEL_ASSISTANT)
            .setSmallIcon(R.drawable.ic_launcher)
            .setContentTitle(context.getString(R.string.notif_reminder_title))
            .setContentText(label)
            .setAutoCancel(true)
            .build()
        manager.notify(label.hashCode(), notification)
    }
}
