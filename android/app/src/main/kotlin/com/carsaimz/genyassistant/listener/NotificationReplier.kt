package com.carsaimz.genyassistant.listener

import android.app.Notification
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.RemoteInput

/**
 * Envio de resposta a uma notificação via RemoteInput (TODO android-07, #43).
 *
 * Localiza a ação de resposta da notificação (remoteInputs), preenche o
 * texto e dispara o PendingIntent do app de origem. Nenhum conteúdo sai do
 * dispositivo: quem entrega é o próprio app que postou a notificação.
 *
 * Os códigos de resultado são curtos e estáveis: viram o contrato do tool
 * `notifications.reply` e do log de auditoria.
 */
object NotificationReplier {
    /** Resposta entregue ao app de origem. */
    const val SENT = "sent"

    /** Notificação sem nenhuma ação de resposta remota. */
    const val NO_REPLY_ACTION = "sem_acao_de_resposta"

    /** PendingIntent.send lançou exceção (app de origem recusou, etc.). */
    const val SEND_FAILED = "falha_no_envio"

    /** Notificação ausente no snapshot do listener. */
    const val NOT_FOUND = "nao_encontrada"

    /** Serviço de listener não está conectado. */
    const val NO_SERVICE = "sem_servico"

    /**
     * Responde a uma notificação usando a primeira ação com RemoteInput.
     * Retorna um dos códigos acima.
     */
    fun replyTo(
        context: Context,
        notification: Notification,
        text: String,
    ): String {
        val actions = notification.actions ?: return NO_REPLY_ACTION
        for (action in actions) {
            val inputs = action.remoteInputs
            if (inputs.isNullOrEmpty()) continue
            if (trySend(context, action, inputs[0], text)) return SENT
        }
        return NO_REPLY_ACTION
    }

    private fun trySend(
        context: Context,
        action: Notification.Action,
        remoteInput: android.app.RemoteInput,
        text: String,
    ): Boolean {
        val pending = action.actionIntent ?: return false
        return try {
            val intent = Intent().addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            // androidx.core.app.RemoteInput.addResultsTo embute o mecanismo
            // correto por versão (extra/clipData) que o app de origem lê com
            // RemoteInput.getResultsFromIntent.
            val compatInput = RemoteInput.Builder(remoteInput.resultKey).build()
            RemoteInput.addResultsTo(arrayOf(compatInput), intent)
            pending.send(context, 0, intent)
            true
        } catch (_: PendingIntent.CanceledException) {
            false
        } catch (_: Exception) {
            false
        }
    }
}
