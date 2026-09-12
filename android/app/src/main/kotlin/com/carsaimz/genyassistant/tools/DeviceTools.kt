package com.carsaimz.genyassistant.tools

import android.content.Intent
import android.os.Build
import org.json.JSONObject

/** Ferramentas de dispositivo (docs §9.5 contexto): bateria, hora, wifi. */
class DeviceTools : Tool(
    id = "device.battery",
    name = "Estado da bateria",
    description = "Nível de bateria, carregamento e economia de energia.",
    confirmation = ConfirmationLevel.NONE,
    context = ToolContext.APP,
) {
    override fun execute(params: JSONObject, host: ToolHost): JSONObject {
        val ctx = host.appContext()
        val intent = ctx.registerReceiver(null, android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = intent?.getIntExtra(android.os.BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = intent?.getIntExtra(android.os.BatteryManager.EXTRA_SCALE, -1) ?: -1
        val status = intent?.getIntExtra(android.os.BatteryManager.EXTRA_STATUS, -1) ?: -1
        val pct = if (level >= 0 && scale > 0) (level * 100) / scale else -1
        val saver = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val pm = ctx.getSystemService(android.os.PowerManager::class.java)
            pm?.isPowerSaveMode ?: false
        } else {
            false
        }
        return JSONObject()
            .put("levelPct", pct)
            .put("charging", status == android.os.BatteryManager.BATTERY_STATUS_CHARGING)
            .put("saver", saver)
    }

    companion object {
        /** Ferramenta de hora atual. */
        fun timeTool(): Tool = object : Tool(
            id = "time.now",
            name = "Hora atual",
            description = "Data e hora atuais do dispositivo com fuso local.",
            confirmation = ConfirmationLevel.NONE,
            context = ToolContext.APP,
        ) {
            override fun execute(params: JSONObject, host: ToolHost): JSONObject {
                val now = java.time.ZonedDateTime.now()
                return JSONObject()
                    .put("iso", now.toString())
                    .put("tz", now.zone.id)
            }
        }

        /** Informações de Wi-Fi (estado, sem SSID para evitar permissão de local). */
        fun wifiTool(): Tool = object : Tool(
            id = "device.wifi",
            name = "Estado do Wi-Fi",
            description = "Informa se o Wi-Fi esta ativado e se ha conexao.",
            confirmation = ConfirmationLevel.NONE,
            context = ToolContext.APP,
        ) {
            override fun execute(params: JSONObject, host: ToolHost): JSONObject {
                val ctx = host.appContext()
                val wifi = ctx.getSystemService(android.net.wifi.WifiManager::class.java)
                val cm = ctx.getSystemService(android.net.ConnectivityManager::class.java)
                val active = cm?.activeNetwork
                val caps = active?.let { cm.getNetworkCapabilities(it) }
                return JSONObject()
                    .put("wifiEnabled", wifi?.isWifiEnabled ?: false)
                    .put("online", caps?.hasCapability(android.net.NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true)
            }
        }

        /** Abre os ajustes do sistema (ação reversível). */
        fun openSettingsTool(): Tool = object : Tool(
            id = "device.openSettings",
            name = "Abrir ajustes",
            description = "Abre os ajustes do sistema Android.",
            confirmation = ConfirmationLevel.SIMPLE,
            context = ToolContext.APP,
        ) {
            override fun execute(params: JSONObject, host: ToolHost): JSONObject {
                val intent = Intent(Settings.ACTION_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                host.appContext().startActivity(intent)
                return JSONObject().put("opened", "settings")
            }
        }
    }
}
