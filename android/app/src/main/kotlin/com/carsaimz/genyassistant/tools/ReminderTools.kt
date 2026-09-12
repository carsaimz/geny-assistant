package com.carsaimz.genyassistant.tools

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject

/** Ferramenta de lembretes (docs §9.7) — alarmes via AlarmManager. */
class ReminderSetTool : Tool(
    id = "reminders.set",
    name = "Definir lembrete",
    description = "Define um lembrete para um horario especifico (reversivel).",
    params = listOf(
        ParamSpec("when", "string", required = true, description = "horario ISO-8601 local, ex.: 2025-12-25T08:00"),
        ParamSpec("label", "string", required = true, description = "descricao do lembrete"),
    ),
    permissions = listOf("com.android.alarm.permission.SET_ALARM"),
    confirmation = ConfirmationLevel.SIMPLE,
    context = ToolContext.APP,
) {
    override fun execute(params: JSONObject, host: ToolHost): JSONObject {
        val ctx = host.appContext()
        val whenStr = params.getString("when")
        val label = params.getString("label")
        val target = java.time.LocalDateTime.parse(whenStr)
            .atZone(java.time.ZoneId.systemDefault())
            .toInstant()
            .toEpochMilli()
        if (target <= System.currentTimeMillis()) {
            throw IllegalArgumentException("horario do lembrete ja passou: $whenStr")
        }
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            ?: throw IllegalStateException("AlarmManager indisponivel")
        val intent = Intent(ctx, ReminderReceiver::class.java)
            .putExtra("label", label)
        val pending = PendingIntent.getBroadcast(
            ctx,
            label.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val canExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()
        if (canExact) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target, pending)
        } else {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target, pending)
        }
        host.audit("reminders.set", "lembrete: $label @ $whenStr")
        return JSONObject()
            .put("scheduled", true)
            .put("atMs", target)
            .put("exact", canExact)
            .put("label", label)
    }
}
