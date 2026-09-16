package com.carsaimz.genyassistant.listener

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import com.carsaimz.genyassistant.tools.NotificationStore
import org.json.JSONObject

/**
 * Leitura de notificações (docs §9.3) via NotificationListenerService.
 * Guarda um snapshot local (máx. 200) consultável pela ferramenta
 * notifications.read; nenhum dado sai do dispositivo.
 */
class GenyNotificationListenerService : NotificationListenerService() {

    override fun onListenerConnected() {
        super.onListenerConnected()
        NotificationListenerBridge.setInstance(this)
        activeNotifications?.forEach { push(it) }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        push(sbn)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        NotificationStore.remove(sbn.key ?: return)
    }

    override fun onDestroy() {
        NotificationListenerBridge.clear(this)
        super.onDestroy()
    }

    private fun push(sbn: StatusBarNotification) {
        val extras = sbn.notification?.extras ?: return
        val title = extras.getCharSequence("android.title")?.toString() ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        NotificationStore.add(
            JSONObject()
                .put("id", sbn.key ?: "")
                .put("package", sbn.packageName)
                .put("title", title)
                .put("text", text)
                .put("atMs", sbn.postTime),
        )
    }
}

/** Ponte estática entre ferramentas e o listener ativo (para descartar). */
object NotificationListenerBridge {
    @Volatile
    private var instance: GenyNotificationListenerService? = null

    fun setInstance(service: GenyNotificationListenerService) {
        instance = service
    }

    fun clear(service: GenyNotificationListenerService) {
        if (instance === service) instance = null
    }

    /** Descarta uma notificação pelo id (key). Retorna true se bem-sucedido. */
    fun dismiss(id: String): Boolean {
        val service = instance ?: return false
        return try {
            val active = service.activeNotifications ?: return false
            val target = active.firstOrNull { it.key == id } ?: return false
            service.cancelNotification(target.key)
            true
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Responde uma notificação via RemoteInput (TODO android-07, #43).
     * Retorna o código de resultado de [NotificationReplier].
     */
    fun reply(id: String, text: String): String {
        val service = instance ?: return NotificationReplier.NO_SERVICE
        return try {
            val active = service.activeNotifications ?: return NotificationReplier.NO_SERVICE
            val target = active.firstOrNull { it.key == id }
                ?: return NotificationReplier.NOT_FOUND
            val notification = target.notification
                ?: return NotificationReplier.NOT_FOUND
            NotificationReplier.replyTo(service.applicationContext, notification, text)
        } catch (_: Exception) {
            NotificationReplier.SEND_FAILED
        }
    }
}
