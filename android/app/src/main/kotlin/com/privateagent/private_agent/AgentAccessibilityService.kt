package com.privateagent.private_agent

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Bitmap
import android.graphics.Path
import android.graphics.Rect
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.view.Display
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * Geny Accessibility Service.
 *
 * Dumps the visible screen hierarchy for the LLM and emulates user
 * interactions (tap, swipe, scroll, type, global keys, screenshots).
 * Flutter talks to it through MainActivity's MethodChannel bridge using
 * the [instance] companion reference.
 */
class AgentAccessibilityService : AccessibilityService() {

    companion object {
        @Volatile
        var instance: AgentAccessibilityService? = null
            private set

        /** True while the service is bound and connected by the system. */
        val isConnected: Boolean get() = instance != null
    }

    private val mainHandler by lazy { Handler(Looper.getMainLooper()) }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    // ------------------------------------------------------------------
    // Autonomous Macro Recording
    // ------------------------------------------------------------------
    @Volatile
    var isRecordingMacro: Boolean = false
        private set

    private val macroEvents = mutableListOf<Map<String, Any>>()

    fun startMacroRecording() {
        synchronized(macroEvents) {
            macroEvents.clear()
        }
        isRecordingMacro = true
    }

    fun stopMacroRecording(): List<Map<String, Any>> {
        isRecordingMacro = false
        synchronized(macroEvents) {
            return ArrayList(macroEvents)
        }
    }

    fun getMacroRecordingStatus(): Boolean = isRecordingMacro

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (!isRecordingMacro || event == null) return
        val pkg = event.packageName?.toString() ?: ""
        if (pkg == packageName) return // Ignore self-interactions inside Geny

        when (event.eventType) {
            AccessibilityEvent.TYPE_VIEW_CLICKED -> {
                val node = event.source
                val rect = Rect()
                node?.getBoundsInScreen(rect)
                val text = event.text?.joinToString(" ")?.trim() ?: ""
                val desc = event.contentDescription?.toString()?.trim() ?: ""
                val label = if (text.isNotEmpty()) text else desc
                val viewId = node?.viewIdResourceName ?: ""

                val map = mutableMapOf<String, Any>(
                    "type" to "click",
                    "label" to label,
                    "x" to rect.centerX(),
                    "y" to rect.centerY(),
                    "package" to pkg,
                    "viewId" to viewId,
                    "timestamp" to System.currentTimeMillis()
                )
                synchronized(macroEvents) {
                    macroEvents.add(map)
                }
            }
            AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED -> {
                val text = event.text?.joinToString("") ?: ""
                if (text.isNotEmpty()) {
                    val map = mutableMapOf<String, Any>(
                        "type" to "type",
                        "text" to text,
                        "package" to pkg,
                        "timestamp" to System.currentTimeMillis()
                    )
                    synchronized(macroEvents) {
                        if (macroEvents.isNotEmpty() && macroEvents.last()["type"] == "type") {
                            macroEvents[macroEvents.size - 1] = map
                        } else {
                            macroEvents.add(map)
                        }
                    }
                }
            }
            AccessibilityEvent.TYPE_VIEW_SCROLLED -> {
                val map = mutableMapOf<String, Any>(
                    "type" to "scroll",
                    "direction" to "down",
                    "package" to pkg,
                    "timestamp" to System.currentTimeMillis()
                )
                synchronized(macroEvents) {
                    val last = macroEvents.lastOrNull()
                    val lastTime = (last?.get("timestamp") as? Long) ?: 0L
                    if (last?.get("type") != "scroll" || (System.currentTimeMillis() - lastTime > 600)) {
                        macroEvents.add(map)
                    }
                }
            }
        }
    }

    override fun onInterrupt() {
        // No-op: automation is driven explicitly by the Dart side.
    }

    override fun onUnbind(intent: android.content.Intent?): Boolean {
        if (instance === this) instance = null
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        super.onDestroy()
    }

    // ------------------------------------------------------------------
    // Screen dump
    // ------------------------------------------------------------------

    /**
     * Recursively traverses the foreground app's window tree and flattens
     * "interesting" nodes (visible nodes with a label or an interaction
     * affordance) into a list of maps.
     *
     * Window selection strategy, in order:
     * 1. [rootInActiveWindow], unless it belongs to Geny itself while
     *    another app is visibly in front (our own task never feeds the LLM —
     *    otherwise the agent reads its own transcript and gets confused).
     * 2. Otherwise the active/focused window from [windows].
     * 3. Otherwise the first non-Geny application window.
     *
     * Our own package is only dumped as a last resort (e.g. the user runs a
     * task that stays inside Geny).
     */
    fun dumpScreen(): List<Map<String, Any>> {
        val self = packageName

        val active = rootInActiveWindow
        if (active != null && active.packageName != self) {
            return traverseAll(listOf(active))
        }

        val wins = try {
            windows?.toList() ?: emptyList()
        } catch (_: Exception) {
            emptyList() // windows may throw SecurityException on some OEM builds.
        }

        val foreign = wins.mapNotNull { it.root }
            .filter { it.packageName != self }
        val focused = wins.firstOrNull { it.isActive || it.isFocused }?.root
            ?.takeIf { it.packageName != self }

        val chosen = focused ?: foreign.firstOrNull() ?: active
        return if (chosen != null) traverseAll(listOf(chosen)) else emptyList()
    }

    private fun traverseAll(
        roots: List<AccessibilityNodeInfo>
    ): List<Map<String, Any>> {
        val out = mutableListOf<Map<String, Any>>()
        var index = 0
        for (root in roots) {
            index = traverse(root, index, out)
        }
        return out
    }
    private fun traverse(
        node: AccessibilityNodeInfo?,
        startIndex: Int,
        out: MutableList<Map<String, Any>>
    ): Int {
        if (node == null) return startIndex
        var index = startIndex

        val rect = Rect()
        node.getBoundsInScreen(rect)

        val text = node.text?.toString().orEmpty()
        val desc = node.contentDescription?.toString().orEmpty()
        val className = node.className?.toString().orEmpty()
        val viewId = node.viewIdResourceName.orEmpty()

        val interactive =
            node.isClickable || node.isEditable || node.isScrollable ||
                node.isCheckable || node.isLongClickable
        val hasLabel = text.isNotBlank() || desc.isNotBlank()
        val onScreen = rect.width() > 0 && rect.height() > 0

        if (node.isVisibleToUser && onScreen && (interactive || hasLabel)) {
            out.add(
                hashMapOf(
                    "index" to index,
                    "text" to text,
                    "contentDescription" to desc,
                    "className" to className,
                    "viewId" to viewId,
                    "isClickable" to node.isClickable,
                    "isEditable" to node.isEditable,
                    "isScrollable" to node.isScrollable,
                    "isCheckable" to node.isCheckable,
                    "isEnabled" to node.isEnabled,
                    "left" to rect.left,
                    "top" to rect.top,
                    "right" to rect.right,
                    "bottom" to rect.bottom,
                    "centerX" to rect.centerX(),
                    "centerY" to rect.centerY()
                )
            )
            index++
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            index = traverse(child, index, out)
        }
        return index
    }

    // ------------------------------------------------------------------
    // Gestures
    // ------------------------------------------------------------------

    /** Short tap at absolute screen coordinates. */
    fun clickAt(x: Float, y: Float, result: MethodChannel.Result) {
        val path = Path().apply { moveTo(x, y) }
        val stroke = GestureDescription.StrokeDescription(path, 0L, 80L)
        dispatch(GestureDescription.Builder().addStroke(stroke).build(), result)
    }

    /** Linear swipe between two points over [durationMs] milliseconds. */
    fun swipe(
        startX: Float,
        startY: Float,
        endX: Float,
        endY: Float,
        durationMs: Long,
        result: MethodChannel.Result
    ) {
        val path = Path().apply {
            moveTo(startX, startY)
            lineTo(endX, endY)
        }
        val clamped = durationMs.coerceIn(50L, 5000L)
        val stroke = GestureDescription.StrokeDescription(path, 0L, clamped)
        dispatch(GestureDescription.Builder().addStroke(stroke).build(), result)
    }
    /**
     * Scrolls the screen. Semantics: [direction] is the content direction to
     * reveal, so "down" reveals content further down the page (finger swipes
     * up). Prefers a native scroll action on the first scrollable node and
     * falls back to a swipe gesture.
     */
    fun scroll(direction: String, result: MethodChannel.Result) {
        val forward = direction.lowercase() == "down" || direction.lowercase() == "right"
        val vertical =
            direction.lowercase() == "down" || direction.lowercase() == "up"

        val scrollable = findFirstScrollable(rootInActiveWindow)
        if (scrollable != null) {
            val action = if (forward) {
                AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
            } else {
                AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
            }
            if (scrollable.performAction(action)) {
                result.success(true)
                return
            }
        }

        // Gesture fallback.
        val metrics = resources.displayMetrics
        val w = metrics.widthPixels.toFloat()
        val h = metrics.heightPixels.toFloat()
        val cx = w / 2f
        val cy = h / 2f
        val dy = h * 0.30f
        val dx = w * 0.30f
        when (direction.lowercase()) {
            "down" -> swipe(cx, cy + dy / 2, cx, cy - dy / 2, 380, result)
            "up" -> swipe(cx, cy - dy / 2, cx, cy + dy / 2, 380, result)
            "left" -> swipe(cx - dx / 2, cy, cx + dx / 2, cy, 380, result)
            "right" -> swipe(cx + dx / 2, cy, cx - dx / 2, cy, 380, result)
            else -> {
                if (vertical) swipe(cx, cy + dy / 2, cx, cy - dy / 2, 380, result)
                else result.success(false)
            }
        }
    }

    private fun dispatch(gesture: GestureDescription, result: MethodChannel.Result) {
        val accepted = dispatchGesture(
            gesture,
            object : GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    mainHandler.post { result.success(true) }
                }

                override fun onCancelled(gestureDescription: GestureDescription?) {
                    mainHandler.post { result.success(false) }
                }
            },
            mainHandler
        )
        if (!accepted) result.success(false)
    }

    private fun findFirstScrollable(node: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
        if (node == null) return null
        if (node.isScrollable && node.isVisibleToUser) return node
        for (i in 0 until node.childCount) {
            val found = findFirstScrollable(node.getChild(i))
            if (found != null) return found
        }
        return null
    }
    // ------------------------------------------------------------------
    // Text input
    // ------------------------------------------------------------------

    /**
     * Sets [text] into the currently focused editable node, or the first
     * editable node found on screen. Returns false when no input exists.
     */
    fun typeText(text: String): Boolean {
        val root = rootInActiveWindow ?: return false
        var target = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
        if (target == null || !target.isEditable) {
            target = findFirstEditable(root)
        }
        if (target == null) return false

        target.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
        val args = Bundle().apply {
            putCharSequence(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                text
            )
        }
        return target.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }

    private fun findFirstEditable(node: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
        if (node == null) return null
        if (node.isEditable && node.isVisibleToUser && node.isEnabled) return node
        for (i in 0 until node.childCount) {
            val found = findFirstEditable(node.getChild(i))
            if (found != null) return found
        }
        return null
    }

    // ------------------------------------------------------------------
    // Global keys
    // ------------------------------------------------------------------

    /** Handles back/home/recents/notifications/lock plus IME enter. */
    fun pressKey(key: String): Boolean = when (key.lowercase()) {
        "back" -> performGlobalAction(GLOBAL_ACTION_BACK)
        "home" -> performGlobalAction(GLOBAL_ACTION_HOME)
        "recents", "recent" -> performGlobalAction(GLOBAL_ACTION_RECENTS)
        "notifications" -> performGlobalAction(GLOBAL_ACTION_NOTIFICATIONS)
        "quick_settings" -> performGlobalAction(GLOBAL_ACTION_QUICK_SETTINGS)
        "power_dialog" -> performGlobalAction(GLOBAL_ACTION_POWER_DIALOG)
        "lock" -> Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
            performGlobalAction(GLOBAL_ACTION_LOCK_SCREEN)
        "enter" -> pressImeEnter()
        else -> false
    }

    private fun pressImeEnter(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return false
        val root = rootInActiveWindow ?: return false
        val target = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT) ?: return false
        return target.performAction(
            AccessibilityNodeInfo.AccessibilityAction.ACTION_IME_ENTER.id
        )
    }

    // ------------------------------------------------------------------
    // Screenshot (Android 11+ / API 30+)
    // ------------------------------------------------------------------

    /** Captures the screen and delivers a Base64-encoded PNG via [result]. */
    fun takeScreenshotBase64(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            result.error(
                "UNSUPPORTED",
                "Screenshots require Android 11 (API 30) or newer",
                null
            )
            return
        }
        takeScreenshot(
            Display.DEFAULT_DISPLAY,
            mainExecutor,
            object : TakeScreenshotCallback {
                override fun onSuccess(screenshotResult: ScreenshotResult) {
                    try {
                        val hwBuffer = screenshotResult.hardwareBuffer
                        val hwBitmap =
                            Bitmap.wrapHardwareBuffer(hwBuffer, screenshotResult.colorSpace)
                        hwBuffer.close()
                        if (hwBitmap == null) {
                            mainHandler.post {
                                result.error("FAILED", "wrapHardwareBuffer returned null", null)
                            }
                            return
                        }
                        val soft = hwBitmap.copy(Bitmap.Config.ARGB_8888, false)
                        hwBitmap.recycle()
                        val stream = ByteArrayOutputStream()
                        soft.compress(Bitmap.CompressFormat.PNG, 85, stream)
                        soft.recycle()
                        val b64 = Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
                        mainHandler.post { result.success(b64) }
                    } catch (e: Exception) {
                        mainHandler.post { result.error("FAILED", e.message, null) }
                    }
                }

                override fun onFailure(errorCode: Int) {
                    mainHandler.post {
                        result.error("FAILED", "takeScreenshot failed with code $errorCode", null)
                    }
                }
            }
        )
    }
}
