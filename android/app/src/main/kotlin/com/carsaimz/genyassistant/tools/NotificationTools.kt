package com.carsaimz.genyassistant.tools

import org.json.JSONArray
import org.json.JSONObject

/** Armazenamento em memória das notificações capturadas pelo listener (§9.3). */
object NotificationStore {
    private const val CAP = 200
    private val items = ArrayDeque<JSONObject>()

    @Synchronized
    fun add(notification: JSONObject) {
        items.addLast(notification)
        while (items.size > CAP) items.removeFirst()
    }

    @Synchronized
    fun remove(id: String) {
        items.removeAll { it.optString("id") == id }
    }

    @Synchronized
    fun snapshot(query: String?): List<JSONObject> {
        val q = query?.lowercase()
        return items.filter {
            q.isNullOrEmpty() ||
                it.optString("title").lowercase().contains(q) ||
                it.optString("text").lowercase().contains(q) ||
                it.optString("package").lowercase().contains(q)
        }
    }
}

/** Ferramentas de notificações (docs §9.3) — leitura via NotificationListener. */
class NotificationReadTool : Tool(
    id = "notifications.read",
    name = "Ler notificações",
    description = "Le as notificacoes ativas de outros aplicativos com filtro opcional.",
    params = listOf(ParamSpec("query", "string", required = false, description = "filtro por texto ou app")),
    confirmation = ConfirmationLevel.NONE,
    context = ToolContext.SERVICE,
) {
    override fun execute(params: JSONObject, host: ToolHost): JSONObject {
        val query = if (params.has("query") && !params.isNull("query")) params.getString("query") else null
        val list = NotificationStore.snapshot(query)
        return JSONObject()
            .put("notifications", JSONArray(list))
            .put("count", list.size)
    }
}

class NotificationDismissTool : Tool(
    id = "notifications.dismiss",
    name = "Descartar notificação",
    description = "Descarta uma notificacao pelo id (acao reversivel via app de origem).",
    params = listOf(ParamSpec("id", "string", required = true, description = "id da notificacao capturada")),
    confirmation = ConfirmationLevel.SIMPLE,
    context = ToolContext.SERVICE,
) {
    override fun execute(params: JSONObject, host: ToolHost): JSONObject {
        val id = params.getString("id")
        val removed = com.carsaimz.genyassistant.listener.NotificationListenerBridge.dismiss(id)
        if (removed) NotificationStore.remove(id)
        return JSONObject().put("dismissed", removed)
    }
}

/**
 * Responder notificações via RemoteInput (TODO android-07, #43): localiza a
 * ação de resposta do app de origem e entrega o texto pelo próprio
 * PendingIntent — sem acessar rede ou credenciais. Nível EXPLICIT: envia
 * mensagem em nome do usuário.
 */
class NotificationReplyTool : Tool(
    id = "notifications.reply",
    name = "Responder notificação",
    description = "Responde uma notificacao pelo id usando a acao de resposta do app de origem.",
    params = listOf(
        ParamSpec("id", "string", required = true, description = "id da notificacao capturada"),
        ParamSpec("text", "string", required = true, description = "texto da resposta"),
    ),
    confirmation = ConfirmationLevel.EXPLICIT,
    context = ToolContext.SERVICE,
) {
    override fun execute(params: JSONObject, host: ToolHost): JSONObject {
        val id = params.getString("id")
        val text = params.getString("text")
        val result = com.carsaimz.genyassistant.listener.NotificationListenerBridge.reply(id, text)
        val sent = result == com.carsaimz.genyassistant.listener.NotificationReplier.SENT
        return JSONObject()
            .put("sent", sent)
            .put("result", result)
    }
}
