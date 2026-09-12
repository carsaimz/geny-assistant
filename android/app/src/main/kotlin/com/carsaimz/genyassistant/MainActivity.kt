package com.carsaimz.genyassistant

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.content.ContextCompat
import com.carsaimz.genyassistant.bridge.GenyPlugin
import com.getcapacitor.BridgeActivity

/**
 * Activity principal: hospeda a WebView do app (Capacitor) e registra a ponte
 * nativa [GenyPlugin] que expõe ferramentas, confirmação e contexto.
 */
class MainActivity : BridgeActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        // Plugins devem ser registrados antes do super.onCreate().
        registerPlugin(GenyPlugin::class.java)
        super.onCreate(savedInstanceState)
        requestNotificationsIfNeeded()
    }

    /** POST_NOTIFICATIONS é solicitada em contexto (§14.1); aqui é o primeiro uso. */
    private fun requestNotificationsIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
        if (!granted) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQ_NOTIF)
        }
    }

    private companion object {
        const val REQ_NOTIF = 4001
    }
}
