package com.carsaimz.genyassistant.overlay

import android.annotation.SuppressLint
import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import com.carsaimz.genyassistant.MainActivity

/**
 * Overlay HUD flutuante (docs §16.2): serviço com ícone arrastável sobre
 * outros apps que abre o assistente com um toque. Iniciado/parado pela ponte
 * (GenyPlugin.startHud/stopHud) com permissão SYSTEM_ALERT_WINDOW.
 */
class HudOverlayService : Service() {

    private var bubble: View? = null
    private var windowManager: WindowManager? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_HIDE -> {
                removeBubble()
                stopSelf()
            }
            else -> showBubble()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        removeBubble()
        super.onDestroy()
    }

    private fun removeBubble() {
        val view = bubble
        if (view != null) {
            try {
                windowManager?.removeView(view)
            } catch (_: IllegalArgumentException) {
                // view já removida
            }
            bubble = null
        }
    }

    private fun showBubble() {
        if (bubble != null) return
        if (!Settings.canDrawOverlays(this)) {
            stopSelf()
            return
        }
        val wm = getSystemService(WINDOW_SERVICE) as? WindowManager ?: return
        windowManager = wm
        bubble = createBubble().also { wm.addView(it, layoutParams()) }
    }

    @SuppressLint("ClickableViewAccessibility", "InflateParams")
    private fun createBubble(): View {
        val view = TextView(this).apply {
            text = "◉"
            textSize = 20f
            setPadding(28, 20, 28, 20)
            elevation = 12f
        }
        var initialX = 0
        var initialY = 0
        var touchX = 0f
        var touchY = 0f
        var moved = false

        view.setOnTouchListener { v, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = layoutParams().x
                    initialY = layoutParams().y
                    touchX = event.rawX
                    touchY = event.rawY
                    moved = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - touchX).toInt()
                    val dy = (event.rawY - touchY).toInt()
                    if (Math.abs(dx) > 6 || Math.abs(dy) > 6) moved = true
                    val params = layoutParams()
                    params.x = initialX + dx
                    params.y = initialY + dy
                    windowManager?.updateViewLayout(v, params)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!moved) openAssistant()
                    true
                }
                else -> false
            }
        }
        return view
    }

    private fun openAssistant() {
        val intent = Intent(this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    private fun layoutParams(): WindowManager.LayoutParams {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 40
            y = 320
        }
    }

    companion object {
        const val ACTION_HIDE = "com.carsaimz.genyassistant.HUD_HIDE"
    }
}
