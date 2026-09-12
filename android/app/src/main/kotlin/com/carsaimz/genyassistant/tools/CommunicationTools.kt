package com.carsaimz.genyassistant.tools

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.ContactsContract
import android.telephony.SmsManager
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject

/** Comunicação (docs §9.2): discar, SMS e contatos — sempre com confirmação explícita. */
class DialTool : Tool(
    id = "call.dial",
    name = "Discar telefone",
    description = "Abre o discador com o numero preenchido (nao liga automaticamente).",
    params = listOf(ParamSpec("number", "string", required = true, description = "numero a discar")),
    confirmation = ConfirmationLevel.EXPLICIT,
    context = ToolContext.APP,
) {
    override fun execute(params: JSONObject, host: ToolHost): JSONObject {
        val number = params.getString("number")
        val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$number"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        host.appContext().startActivity(intent)
        return JSONObject().put("dialed", number)
    }
}

class SendSmsTool : Tool(
    id = "sms.send",
    name = "Enviar SMS",
    description = "Envia uma mensagem SMS. Acao com impacto: exige confirmacao.",
    params = listOf(
        ParamSpec("to", "string", required = true, description = "numero de destino"),
        ParamSpec("body", "string", required = true, description = "texto da mensagem"),
    ),
    permissions = listOf(Manifest.permission.SEND_SMS),
    confirmation = ConfirmationLevel.EXPLICIT,
    context = ToolContext.APP,
) {
    override fun execute(params: JSONObject, host: ToolHost): JSONObject {
        val ctx = host.appContext()
        ensurePermission(ctx)
        val to = params.getString("to")
        val body = params.getString("body")
        val manager = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            ctx.getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        } ?: throw IllegalStateException("SmsManager indisponivel")
        manager.sendTextMessage(to, null, body, null, null)
        return JSONObject().put("sent", true).put("to", to).put("length", body.length)
    }

    private fun ensurePermission(ctx: android.content.Context) {
        val granted = ContextCompat.checkSelfPermission(
            ctx,
            Manifest.permission.SEND_SMS,
        ) == PackageManager.PERMISSION_GRANTED
        if (!granted) {
            throw SecurityException("permissao SEND_SMS nao concedida — solicite em contexto")
        }
    }
}

class ContactSearchTool : Tool(
    id = "contacts.search",
    name = "Buscar contato",
    description = "Busca contatos pelo nome (somente leitura).",
    params = listOf(ParamSpec("query", "string", required = true, description = "nome a buscar")),
    permissions = listOf(Manifest.permission.READ_CONTACTS),
    confirmation = ConfirmationLevel.NONE,
    context = ToolContext.APP,
) {
    override fun execute(params: JSONObject, host: ToolHost): JSONObject {
        val ctx = host.appContext()
        val granted = ContextCompat.checkSelfPermission(
            ctx,
            Manifest.permission.READ_CONTACTS,
        ) == PackageManager.PERMISSION_GRANTED
        if (!granted) {
            throw SecurityException("permissao READ_CONTACTS nao concedida")
        }
        val query = params.getString("query")
        val results = JSONArray()
        ctx.contentResolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            arrayOf(
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                ContactsContract.CommonDataKinds.Phone.NUMBER,
            ),
            "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} LIKE ?",
            arrayOf("%$query%"),
            null,
        )?.use { cursor ->
            while (cursor.moveToNext() && results.length() < 20) {
                results.put(
                    JSONObject()
                        .put("name", cursor.getString(0) ?: "")
                        .put("phone", cursor.getString(1) ?: ""),
                )
            }
        }
        return JSONObject().put("results", results).put("count", results.length())
    }
}
