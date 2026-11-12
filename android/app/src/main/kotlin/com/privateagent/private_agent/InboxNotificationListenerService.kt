package com.privateagent.private_agent

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.util.concurrent.CopyOnWriteArrayList

/**
 * Captures email and SMS notifications from Gmail, Outlook, Yahoo, and native messengers
 * so J.A.R.V.I.S. can triage and read inboxes in real-time.
 */
class InboxNotificationListenerService : NotificationListenerService() {

    companion object {
        @Volatile
        var isConnected: Boolean = false
            private set

        val capturedEmailNotifications = CopyOnWriteArrayList<Map<String, Any>>()
        val capturedSmsNotifications = CopyOnWriteArrayList<Map<String, Any>>()

        private const val MAX_SAVED = 40

        fun getRecentEmails(): List<Map<String, Any>> = capturedEmailNotifications.toList()
        fun getRecentSms(): List<Map<String, Any>> = capturedSmsNotifications.toList()
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        isConnected = true
        try {
            val active = activeNotifications
            if (active != null) {
                for (sbn in active) {
                    processNotification(sbn)
                }
            }
        } catch (_: Exception) {}
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        isConnected = false
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return
        processNotification(sbn)
    }

    private fun processNotification(sbn: StatusBarNotification) {
        val pkg = sbn.packageName ?: ""
        val extras = sbn.notification?.extras ?: return

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
            ?: extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""
        val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString() ?: ""
        val postTime = sbn.postTime

        if (title.isBlank() && text.isBlank()) return

        val item = mapOf(
            "package" to pkg,
            "title" to title,
            "text" to text,
            "subText" to subText,
            "timestamp" to postTime,
            "id" to sbn.id.toString()
        )

        val isEmail = pkg.contains("mail", ignoreCase = true) ||
                pkg.contains("outlook", ignoreCase = true) ||
                pkg == "com.google.android.gm" ||
                pkg == "com.microsoft.office.outlook" ||
                pkg == "com.yahoo.mobile.client.android.mail" ||
                pkg == "com.samsung.android.email.provider"

        val isSms = pkg.contains("messaging", ignoreCase = true) ||
                pkg.contains("mms", ignoreCase = true) ||
                pkg == "com.google.android.apps.messaging" ||
                pkg == "com.samsung.android.messaging"

        if (isEmail) {
            capturedEmailNotifications.removeIf { it["title"] == title && it["text"] == text }
            capturedEmailNotifications.add(0, item)
            if (capturedEmailNotifications.size > MAX_SAVED) {
                capturedEmailNotifications.removeAt(capturedEmailNotifications.size - 1)
            }
        } else if (isSms) {
            capturedSmsNotifications.removeIf { it["title"] == title && it["text"] == text }
            capturedSmsNotifications.add(0, item)
            if (capturedSmsNotifications.size > MAX_SAVED) {
                capturedSmsNotifications.removeAt(capturedSmsNotifications.size - 1)
            }
        }
    }
}

