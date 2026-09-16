package com.carsaimz.genyassistant.listener

import android.app.Notification
import android.app.PendingIntent
import android.app.RemoteInput
import android.content.Context
import android.content.Intent
import android.os.Bundle

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
        remoteInput: RemoteInput,
        text: String,
    ): Boolean {
        val pending = action.actionIntent ?: return false
        return try {
            val intent = Intent().addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            val results = Bundle()
            results.putCharSequence(remoteInput.resultKey, text)
            // Equivalente ao contrato de RemoteInput.addResultsTo: o app de
            // origem lê EXTRA_RESULTS com RemoteInput.getResultsFromIntent.
            intent.putExtra(RemoteInput.EXTRA_RESULTS, results)
            pending.send(context, 0, intent)
            true
        } catch (_: PendingIntent.CanceledException) {
            false
        } catch (_: Exception) {
            false
        }
    }
}
