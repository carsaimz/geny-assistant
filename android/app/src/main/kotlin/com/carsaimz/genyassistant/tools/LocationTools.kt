package com.carsaimz.genyassistant.tools

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import androidx.core.content.ContextCompat
import org.json.JSONObject

/** Ferramentas de localização (docs §9.5) — leitura única, com permissão explícita. */
class LocationGetTool : Tool(
    id = "location.get",
    name = "Obter localização",
    description = "Obtem a ultima localizacao conhecida do dispositivo. Dados sensiveis.",
    permissions = listOf(
        Manifest.permission.ACCESS_FINE_LOCATION,
        Manifest.permission.ACCESS_COARSE_LOCATION,
    ),
    confirmation = ConfirmationLevel.SIMPLE,
    context = ToolContext.APP,
) {
    override fun execute(params: JSONObject, host: ToolHost): JSONObject {
        val ctx = host.appContext()
        val fine = ContextCompat.checkSelfPermission(
            ctx,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(
            ctx,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        if (!fine && !coarse) {
            throw SecurityException("permissao de localizacao nao concedida")
        }
        val lm = ctx.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
            ?: throw IllegalStateException("LocationManager indisponivel")
        val providers = lm.getProviders(true)
        var best: android.location.Location? = null
        for (p in providers) {
            val last = try {
                lm.getLastKnownLocation(p)
            } catch (_: SecurityException) {
                null
            }
            if (last != null && (best == null || last.accuracy < best.accuracy)) {
                best = last
            }
        }
        if (best == null) {
            return JSONObject().put("available", false)
        }
        return JSONObject()
            .put("available", true)
            .put("lat", best.latitude)
            .put("lon", best.longitude)
            .put("accuracyM", best.accuracy.toDouble())
            .put("provider", best.provider)
            .put("atMs", best.time)
    }
}
