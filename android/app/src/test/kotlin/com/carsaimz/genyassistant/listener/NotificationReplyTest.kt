package com.carsaimz.genyassistant.listener

import android.app.Notification
import android.app.PendingIntent
import android.app.RemoteInput
import android.content.Context
import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Testes JVM do envio de resposta via RemoteInput (TODO android-07, #43)
 * com Robolectric: notificação real com ação de resposta, e casos sem
 * ação remota.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class NotificationReplyTest {

    private val context: Context = ApplicationProvider.getApplicationContext()

    /** Notificação com uma ação de resposta válida (RemoteInput + PendingIntent). */
    private fun notificationWithReplyAction(): Notification {
        val replyRemoteInput = RemoteInput.Builder("key_reply").build()
        val intent = Intent(context, NotificationReplyTest::class.java)
        val pending =
            PendingIntent.getBroadcast(
                context,
                0,
                intent,
                PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        val action =
            Notification.Action.Builder(
                android.graphics.drawable.Icon.createWithResource(context, android.R.drawable.ic_menu_send),
                "Reply",
                pending,
            )
                .addRemoteInput(replyRemoteInput)
                .build()
        return Notification.Builder(context, "chan")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .addAction(action)
            .build()
    }

    @Test
    fun resposta_e_entregue_quando_ha_acao_remota() {
        val notification = notificationWithReplyAction()
        val result = NotificationReplier.replyTo(context, notification, "Olá do Geny!")
        assertEquals(NotificationReplier.SENT, result)
    }

    @Test
    fun notificacao_sem_acoes_reporta_sem_acao_de_resposta() {
        val notification =
            Notification.Builder(context, "chan")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .build()
        val result = NotificationReplier.replyTo(context, notification, "texto")
        assertEquals(NotificationReplier.NO_REPLY_ACTION, result)
    }

    @Test
    fun acao_sem_remoteinput_reporta_sem_acao_de_resposta() {
        val pending =
            PendingIntent.getBroadcast(
                context,
                1,
                Intent(context, NotificationReplyTest::class.java),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        val action =
            Notification.Action.Builder(
                android.graphics.drawable.Icon.createWithResource(context, android.R.drawable.ic_menu_view),
                "Abrir",
                pending,
            )
                .build()
        val notification =
            Notification.Builder(context, "chan")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .addAction(action)
                .build()
        val result = NotificationReplier.replyTo(context, notification, "texto")
        assertEquals(NotificationReplier.NO_REPLY_ACTION, result)
    }

    @Test
    fun codigos_de_resultado_sao_estaveis_para_o_contrato_da_ponte() {
        // O tool notifications.reply usa estes códigos no envelope JSON.
        assertEquals("sent", NotificationReplier.SENT)
        assertEquals("sem_acao_de_resposta", NotificationReplier.NO_REPLY_ACTION)
        assertEquals("falha_no_envio", NotificationReplier.SEND_FAILED)
        assertEquals("nao_encontrada", NotificationReplier.NOT_FOUND)
        assertEquals("sem_servico", NotificationReplier.NO_SERVICE)
        assertFalse(NotificationReplier.SENT == NotificationReplier.NO_REPLY_ACTION)
    }
}
