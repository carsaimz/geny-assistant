package com.privateagent.private_agent

import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.StatFs
import android.provider.MediaStore
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Base64
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Calendar
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * Bridges Flutter -> [AgentAccessibilityService] via `com.privateagent/accessibility`
 * and continuous hands-free voice via `com.privateagent/speech`.
 */
class MainActivity : FlutterActivity() {
    override fun attachBaseContext(base: android.content.Context) {
        super.attachBaseContext(base)
        AppContextHolder.context = base.applicationContext ?: base
    }


    private val channelName = "com.privateagent/accessibility"
    private val speechChannelName = "com.privateagent/speech"
    private var accessibilityChannel: MethodChannel? = null
    private var speechChannel: MethodChannel? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var recognitionIntent: Intent? = null
    private var recognitionLanguage: String? = null
    private var isContinuousListening = false
    private var isRestartPending = false
    private val mainHandler = Handler(Looper.getMainLooper())

    // Background Media / Music protection (avoids audio-focus theft that pauses YouTube / music players)
    private var mediaSuppressionUntil: Long = 0L

    private fun isMediaPlaybackActive(): Boolean {
        return try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            val musicActive = audioManager?.isMusicActive ?: false
            val suppressed = System.currentTimeMillis() < mediaSuppressionUntil
            musicActive || suppressed
        } catch (_: Exception) {
            false
        }
    }

    private var mediaPlayer: android.media.MediaPlayer? = null
    private var playResult: MethodChannel.Result? = null

    private val cameraRequestCode = 9102
    private var pendingCameraResult: MethodChannel.Result? = null
    private var currentPhotoPath: String? = null

    // Sentry Tactical Anti-Theft Watchdog
    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null
    private var isSentryArmed = false
    private var lastAccelMagnitude = 0f
    private var sentryLastTriggerTime = 0L

    // Air Gestures Zero-Touch Proximity Sensor
    private var proximitySensor: Sensor? = null
    private var isAirGesturesArmed = false
    private var proximityNearTime = 0L
    private var lastWaveTime = 0L

    // Charging & Power Telemetry Receiver
    private var powerReceiver: android.content.BroadcastReceiver? = null

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == cameraRequestCode) {
            val result = pendingCameraResult
            pendingCameraResult = null
            if (resultCode == RESULT_OK && currentPhotoPath != null) {
                try {
                    val file = File(currentPhotoPath!!)
                    if (file.exists() && file.length() > 0) {
                        val bytes = file.readBytes()
                        val b64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
                        result?.success(
                            mapOf(
                                "path" to file.absolutePath,
                                "base64" to b64,
                                "size" to bytes.size
                            )
                        )
                        return
                    }
                } catch (e: Exception) {
                    result?.error("CAMERA_ERROR", "Failed to process photo: ${e.message}", null)
                    return
                }
            }
            result?.error("CAMERA_CANCELLED", "User cancelled photo capture", null)
        }
    }

    override fun onDestroy() {
        stopNativeListening()
        try {
            speechRecognizer?.destroy()
            speechRecognizer = null
        } catch (_: Exception) {}
        try {
            mediaPlayer?.let {
                if (it.isPlaying) it.stop()
                it.release()
            }
        } catch (_: Exception) {}
        mediaPlayer = null
        playResult = null
        try {
            sensorManager?.unregisterListener(sentrySensorListener)
        } catch (_: Exception) {}
        try {
            sensorManager?.unregisterListener(airGestureListener)
        } catch (_: Exception) {}
        try {
            if (powerReceiver != null) {
                unregisterReceiver(powerReceiver)
                powerReceiver = null
            }
        } catch (_: Exception) {}
        isSentryArmed = false
        isAirGesturesArmed = false
        super.onDestroy()
    }

    private val sentrySensorListener = object : SensorEventListener {
        override fun onSensorChanged(event: SensorEvent?) {
            if (!isSentryArmed || event == null) return
            val x = event.values[0]
            val y = event.values[1]
            val z = event.values[2]
            val magnitude = sqrt((x * x + y * y + z * z).toDouble()).toFloat()
            if (lastAccelMagnitude == 0f) {
                lastAccelMagnitude = magnitude
                return
            }
            val delta = Math.abs(magnitude - lastAccelMagnitude)
            lastAccelMagnitude = magnitude
            // Sensitivity threshold for pick-up / movement
            if (delta > 2.2f) {
                val now = System.currentTimeMillis()
                if (now - sentryLastTriggerTime > 6000L) { // Debounce 6 seconds
                    sentryLastTriggerTime = now
                    triggerSentryAlarm(delta)
                }
            }
        }
        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    }

    private fun triggerSentryAlarm(deltaMagnitude: Float) {
        mainHandler.post {
            captureFrontCameraPhotoSilent { photoBase64, photoPath ->
                val payload = mapOf(
                    "type" to "sentry_breach",
                    "timestamp" to System.currentTimeMillis(),
                    "delta" to deltaMagnitude.toDouble(),
                    "base64" to (photoBase64 ?: ""),
                    "path" to (photoPath ?: "")
                )
                accessibilityChannel?.invokeMethod("onSentryMovementDetected", payload)
            }
        }
    }

    private fun captureFrontCameraPhotoSilent(onCaptured: (String?, String?) -> Unit) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val cm = getSystemService(Context.CAMERA_SERVICE) as? CameraManager
                val frontCameraId = cm?.cameraIdList?.firstOrNull { id ->
                    val chars = cm.getCameraCharacteristics(id)
                    chars.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_FRONT
                } ?: cm?.cameraIdList?.firstOrNull()

                if (frontCameraId != null && cm != null) {
                    val photoDir = File(cacheDir, "sentry_snapshots").apply { mkdirs() }
                    val photoFile = File(photoDir, "sentry_intruder_${System.currentTimeMillis()}.jpg")

                    val reader = android.media.ImageReader.newInstance(640, 480, android.graphics.ImageFormat.JPEG, 2)
                    reader.setOnImageAvailableListener({ ir ->
                        try {
                            val img = ir.acquireLatestImage()
                            if (img != null) {
                                val buffer = img.planes[0].buffer
                                val bytes = ByteArray(buffer.remaining())
                                buffer.get(bytes)
                                img.close()
                                photoFile.writeBytes(bytes)
                                val b64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
                                onCaptured(b64, photoFile.absolutePath)
                                return@setOnImageAvailableListener
                            }
                        } catch (_: Exception) {}
                        onCaptured(null, null)
                    }, mainHandler)

                    cm.openCamera(frontCameraId, object : CameraDevice.StateCallback() {
                        override fun onOpened(camera: CameraDevice) {
                            try {
                                val captureBuilder = camera.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE)
                                captureBuilder.addTarget(reader.surface)
                                camera.createCaptureSession(listOf(reader.surface), object : android.hardware.camera2.CameraCaptureSession.StateCallback() {
                                    override fun onConfigured(session: android.hardware.camera2.CameraCaptureSession) {
                                        try {
                                            session.capture(captureBuilder.build(), object : android.hardware.camera2.CameraCaptureSession.CaptureCallback() {
                                                override fun onCaptureCompleted(s: android.hardware.camera2.CameraCaptureSession, request: android.hardware.camera2.CaptureRequest, total: android.hardware.camera2.TotalCaptureResult) {
                                                    mainHandler.postDelayed({
                                                        try { camera.close() } catch (_: Exception) {}
                                                    }, 500L)
                                                }
                                            }, mainHandler)
                                        } catch (_: Exception) {
                                            try { camera.close() } catch (_: Exception) {}
                                            onCaptured(null, null)
                                        }
                                    }
                                    override fun onConfigureFailed(session: android.hardware.camera2.CameraCaptureSession) {
                                        try { camera.close() } catch (_: Exception) {}
                                        onCaptured(null, null)
                                    }
                                }, mainHandler)
                            } catch (e: Exception) {
                                try { camera.close() } catch (_: Exception) {}
                                onCaptured(null, null)
                            }
                        }
                        override fun onDisconnected(camera: CameraDevice) {
                            try { camera.close() } catch (_: Exception) {}
                            onCaptured(null, null)
                        }
                        override fun onError(camera: CameraDevice, error: Int) {
                            try { camera.close() } catch (_: Exception) {}
                            onCaptured(null, null)
                        }
                    }, mainHandler)
                    return
                }
            }
        } catch (_: Exception) {}
        onCaptured(null, null)
    }

    // -----------------------------------------------------------------
    // Air Gestures Zero-Touch Proximity Sensor Listener & Dispatcher
    // -----------------------------------------------------------------
    private val airGestureListener = object : SensorEventListener {
        override fun onSensorChanged(event: SensorEvent?) {
            if (!isAirGesturesArmed || event == null) return
            val distance = event.values[0]
            val maxRange = event.sensor.maximumRange
            val isNear = (distance < maxRange && distance <= 4.0f) || distance == 0f

            val now = System.currentTimeMillis()
            if (isNear) {
                if (proximityNearTime == 0L) {
                    proximityNearTime = now
                    android.util.Log.d("GENY_GESTURE", "Proximity near started at $now")
                }
            } else {
                if (proximityNearTime > 0L) {
                    val duration = now - proximityNearTime
                    proximityNearTime = 0L
                    android.util.Log.d("GENY_GESTURE", "Proximity far: duration=${duration}ms")

                    if (duration in 25..800) {
                        val waveDelta = now - lastWaveTime
                        if (waveDelta in 80..1200) {
                            lastWaveTime = 0L
                            dispatchAirGesture("double_wave", duration)
                        } else {
                            lastWaveTime = now
                            mainHandler.postDelayed({
                                if (lastWaveTime == now) {
                                    dispatchAirGesture("wave", duration)
                                }
                            }, 400L)
                        }
                    } else if (duration in 801..3500) {
                        dispatchAirGesture("palm_hover", duration)
                    }
                }
            }
        }
        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    }

    private fun dispatchAirGesture(gesture: String, durationMs: Long) {
        mainHandler.post {
            val payload = mapOf(
                "gesture" to gesture,
                "durationMs" to durationMs,
                "timestamp" to System.currentTimeMillis()
            )
            accessibilityChannel?.invokeMethod("onAirGesture", payload)
        }
    }

    // -----------------------------------------------------------------
    // Arc Reactor Charging & Battery Telemetry Receiver
    // -----------------------------------------------------------------
    private fun setupPowerReceiver() {
        if (powerReceiver != null) return
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_POWER_CONNECTED)
            addAction(Intent.ACTION_POWER_DISCONNECTED)
        }
        powerReceiver = object : android.content.BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val action = intent?.action ?: return
                val isConnected = action == Intent.ACTION_POWER_CONNECTED
                val telemetry = getBatteryTelemetryDetails(isConnected)
                mainHandler.post {
                    if (isConnected) {
                        accessibilityChannel?.invokeMethod("onPowerConnected", telemetry)
                    } else {
                        accessibilityChannel?.invokeMethod("onPowerDisconnected", telemetry)
                    }
                }
            }
        }
        try {
            registerReceiver(powerReceiver, filter)
        } catch (_: Exception) {}
    }

    private fun getBatteryTelemetryDetails(forceChargingState: Boolean? = null): Map<String, Any> {
        val bm = getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
        val batteryIntent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: -1
        val isCharging = forceChargingState ?: (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) bm?.isCharging ?: false else false)
        val voltageMv = batteryIntent?.getIntExtra(BatteryManager.EXTRA_VOLTAGE, 0) ?: 0
        val tempRaw = batteryIntent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) ?: 0
        val tempC = tempRaw / 10.0
        val plugged = batteryIntent?.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1) ?: -1

        val currentUa = bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW) ?: 0
        val currentMa = Math.abs(currentUa) / 1000

        val chargeType = when (plugged) {
            BatteryManager.BATTERY_PLUGGED_AC -> "AC Turbo / Wall Adapter"
            BatteryManager.BATTERY_PLUGGED_USB -> "USB Bus Terminal"
            BatteryManager.BATTERY_PLUGGED_WIRELESS -> "Wireless Inductive Flux"
            else -> if (isCharging) "Direct Power Line" else "Internal Arc Core"
        }

        val volts = if (voltageMv > 0) voltageMv / 1000.0 else 4.0
        val amps = if (currentMa > 0) currentMa / 1000.0 else if (isCharging) 2.5 else 0.4
        val wattage = volts * amps

        return mapOf(
            "isCharging" to isCharging,
            "batteryLevel" to level,
            "voltageMv" to voltageMv,
            "temperatureC" to tempC,
            "currentMa" to currentMa,
            "chargeType" to chargeType,
            "wattage" to (Math.round(wattage * 10.0) / 10.0),
            "timestamp" to System.currentTimeMillis()
        )
    }

    private fun getTargetFolder(name: String?): File {
        return when (name?.lowercase()?.trim()) {
            "documents", "document", "docs" -> {
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS)
            }
            "pictures", "picture", "images", "photos" -> {
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
            }
            "music", "audio" -> {
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC)
            }
            "dcim" -> {
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM)
            }
            "download", "downloads", null, "" -> {
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            }
            else -> {
                val custom = File(Environment.getExternalStorageDirectory(), name)
                if (custom.exists() || custom.mkdirs()) custom else Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            }
        }.apply { mkdirs() }
    }

    private fun obtainSpeechRecognizer(): SpeechRecognizer {
        // ALWAYS use standard SpeechRecognizer.createSpeechRecognizer(this),
        // which connects to Google's robust Speech Services (com.google.android.tts).
        // DO NOT use createOnDeviceSpeechRecognizer on Android 12+ / Motorola,
        // because Motorola delegates it to AiAiSpeechRecognitionService (com.google.android.as)
        // which crashes with java.io.InterruptedIOException in PipedOutputStream.
        return SpeechRecognizer.createSpeechRecognizer(this)
    }

    private fun containsWakeWord(text: String): Boolean {
        val lower = text.lowercase()
        return lower.contains("geny") ||
               lower.contains("javis") ||
               lower.contains("jervis") ||
               lower.contains("jarves") ||
               lower.contains("jarvice") ||
               lower.contains("charvis") ||
               lower.contains("travis") ||
               lower.contains("service") ||
               lower.contains("davis") ||
               lower.contains("davies") ||
               lower.contains("harvest") ||
               lower.contains("jarvi") ||
               lower.contains("google") ||
               lower.contains("j.a.r.v.i.s")
    }

    private fun safeCancelAndDestroy() {
        try {
            speechRecognizer?.destroy()
        } catch (_: Exception) {}
        speechRecognizer = null
    }

    private val restartRunnable = Runnable {
        isRestartPending = false
        if (!isContinuousListening) return@Runnable

        // If background music or media is actively playing on the phone,
        // DO NOT start SpeechRecognizer. Calling startListening() forces Google Speech Services
        // to request audio focus (AUDIOFOCUS_GAIN_TRANSIENT), which causes active media players
        // (YouTube, Spotify, etc.) to pause and resume in an endless loop.
        if (isMediaPlaybackActive()) {
            android.util.Log.d("GENY_VOICE", "Media/Music playback is active on device. Deferring SpeechRecognizer restart.")
            scheduleRestart(1500L)
            return@Runnable
        }

        try {
            safeCancelAndDestroy()
            val recognizer = obtainSpeechRecognizer().apply {
                setRecognitionListener(recognitionListener)
            }
            speechRecognizer = recognizer
            val intent = recognitionIntent ?: buildRecognitionIntent()
            recognizer.startListening(intent)
            android.util.Log.i("GENY_VOICE", "restartRunnable: recognizer restarted cleanly")
        } catch (e: Exception) {
            android.util.Log.e("GENY_VOICE", "restartRunnable failed: ${e.message}")
            safeCancelAndDestroy()
            scheduleRestart(150L)
        }
    }

    private fun scheduleRestart(delayMillis: Long) {
        if (!isContinuousListening) return
        isRestartPending = true
        mainHandler.removeCallbacks(restartRunnable)
        mainHandler.postDelayed(restartRunnable, delayMillis)
    }

    private val recognitionListener = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {
            isRestartPending = false
            mainHandler.post {
                speechChannel?.invokeMethod("onSpeechStatus", "listening")
            }
        }

        override fun onBeginningOfSpeech() {}

        override fun onRmsChanged(rmsdB: Float) {
            mainHandler.post {
                speechChannel?.invokeMethod("onSoundLevel", rmsdB.toDouble())
            }
        }

        override fun onBufferReceived(buffer: ByteArray?) {}

        override fun onEndOfSpeech() {
            mainHandler.post {
                speechChannel?.invokeMethod("onSpeechStatus", "endOfSpeech")
            }
        }

        override fun onError(error: Int) {
            android.util.Log.i("GENY_VOICE", "onError: code=$error, isContinuous=$isContinuousListening")
            mainHandler.post {
                speechChannel?.invokeMethod("onSpeechStatus", "error:$error")
            }

            if (!isContinuousListening) {
                mainHandler.post {
                    speechChannel?.invokeMethod("onSpeechStatus", "notListening")
                }
                return
            }

            // Only stop if user explicitly revoked permission
            if (error == SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS) {
                isContinuousListening = false
                safeCancelAndDestroy()
                mainHandler.post {
                    speechChannel?.invokeMethod("onSpeechStatus", "notListening")
                }
                return
            }

            // For all timeouts, silence, client hiccups, busy signals, audio glitches:
            // Destroy and re-arm cleanly so listening never stops!
            safeCancelAndDestroy()
            val delay = when (error) {
                SpeechRecognizer.ERROR_NO_MATCH,
                SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> 50L
                SpeechRecognizer.ERROR_RECOGNIZER_BUSY,
                SpeechRecognizer.ERROR_CLIENT -> 120L
                else -> 250L
            }
            scheduleRestart(delay)
        }

        override fun onResults(results: Bundle?) {
            val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            val best = matches?.firstOrNull { containsWakeWord(it) } ?: matches?.firstOrNull() ?: ""
            android.util.Log.i("GENY_VOICE", "onResults: best='$best', matches=$matches")
            if (best.isNotEmpty()) {
                mainHandler.post {
                    speechChannel?.invokeMethod(
                        "onSpeechResult",
                        mapOf(
                            "text" to best,
                            "isFinal" to true,
                            "candidates" to (matches ?: emptyList<String>())
                        )
                    )
                }
            }

            if (isContinuousListening) {
                scheduleRestart(50L)
            } else {
                mainHandler.post {
                    speechChannel?.invokeMethod("onSpeechStatus", "notListening")
                }
            }
        }

        override fun onPartialResults(partialResults: Bundle?) {
            val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            val best = matches?.firstOrNull { containsWakeWord(it) } ?: matches?.firstOrNull() ?: ""
            if (best.isNotEmpty()) {
                mainHandler.post {
                    speechChannel?.invokeMethod(
                        "onSpeechResult",
                        mapOf(
                            "text" to best,
                            "isFinal" to false,
                            "candidates" to (matches ?: emptyList<String>())
                        )
                    )
                }
            }
        }

        override fun onSegmentResults(segmentResults: Bundle) {
            val matches = segmentResults.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            val best = matches?.firstOrNull { containsWakeWord(it) } ?: matches?.firstOrNull() ?: ""
            if (best.isNotEmpty()) {
                mainHandler.post {
                    speechChannel?.invokeMethod(
                        "onSpeechResult",
                        mapOf(
                            "text" to best,
                            "isFinal" to false,
                            "candidates" to (matches ?: emptyList<String>())
                        )
                    )
                }
            }
        }

        override fun onEndOfSegmentedSession() {
            if (isContinuousListening) {
                scheduleRestart(50L)
            }
        }

        override fun onEvent(eventType: Int, params: Bundle?) {}
    }

    private fun startNativeListening(continuous: Boolean, manual: Boolean = false, language: String? = null) {
        if (!language.isNullOrBlank() && language != recognitionLanguage) {
            // Locale changed: force a fresh recognizer so the new language applies.
            isContinuousListening = false
            mainHandler.removeCallbacks(restartRunnable)
            isRestartPending = false
            mainHandler.post { safeCancelAndDestroy() }
        }
        recognitionLanguage = language?.takeIf { it.isNotBlank() }
        if (manual) {
            // User explicitly initiated voice command (e.g. tap on HUD or mic);
            // clear media suppression so the command is processed immediately.
            mediaSuppressionUntil = 0L
        } else if (isMediaPlaybackActive()) {
            android.util.Log.i("GENY_VOICE", "startNativeListening: media is playing and manual=false, deferring speech recognition.")
            isContinuousListening = continuous
            scheduleRestart(1500L)
            return
        }

        if (isContinuousListening && continuous && speechRecognizer != null) {
            android.util.Log.i("GENY_VOICE", "startNativeListening: already listening continuously, skipping redundant restart")
            return
        }
        android.util.Log.i("GENY_VOICE", "startNativeListening: continuous=$continuous, manual=$manual")
        isContinuousListening = continuous
        mainHandler.removeCallbacks(restartRunnable)
        isRestartPending = false
        mainHandler.post {
            try {
                safeCancelAndDestroy()
                val recognizer = obtainSpeechRecognizer().apply {
                    setRecognitionListener(recognitionListener)
                }
                speechRecognizer = recognizer
                val intent = buildRecognitionIntent()
                recognitionIntent = intent
                recognizer.startListening(intent)
                speechChannel?.invokeMethod("onSpeechStatus", "listening")
            } catch (e: Exception) {
                android.util.Log.e("GENY_VOICE", "startNativeListening failed: ${e.message}")
                safeCancelAndDestroy()
                speechChannel?.invokeMethod("onSpeechStatus", "error:${e.message}")
            }
        }
    }

    private fun stopNativeListening() {
        android.util.Log.i("GENY_VOICE", "stopNativeListening called")
        isContinuousListening = false
        mainHandler.removeCallbacks(restartRunnable)
        isRestartPending = false
        mainHandler.post {
            safeCancelAndDestroy()
            speechChannel?.invokeMethod("onSpeechStatus", "notListening")
        }
    }

    private fun buildRecognitionIntent(): Intent {
        return Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, packageName)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 3000L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 2500L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 100L)
            // Multilingual support: recognize speech in the assistant's language.
            recognitionLanguage?.takeIf { it.isNotBlank() }?.let {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, it)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, it)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Native Continuous Speech Channel
        val sChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, speechChannelName)
        speechChannel = sChannel
        sChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startListening" -> {
                    val continuous = call.argument<Boolean>("continuous") ?: true
                    val manual = call.argument<Boolean>("manual") ?: false
                    val language = call.argument<String>("language")
                    startNativeListening(continuous, manual, language)
                    result.success(true)
                }
                "stopListening" -> {
                    stopNativeListening()
                    result.success(true)
                }
                "notifyMediaStarted" -> {
                    val durationMs = (call.argument<Number>("durationMs")?.toLong()) ?: 30000L
                    mediaSuppressionUntil = System.currentTimeMillis() + durationMs
                    android.util.Log.i("GENY_VOICE", "notifyMediaStarted: suppressing speech recognition for ${durationMs}ms")
                    safeCancelAndDestroy()
                    scheduleRestart(1500L)
                    result.success(true)
                }
                "isAvailable" -> {
                    val available = SpeechRecognizer.isRecognitionAvailable(this)
                    result.success(available)
                }
                "openTtsSettings" -> {
                    // Lets the user download offline TTS/STT voice data packs
                    // for the selected language (Google Text-to-Speech / Speech
                    // Services by Google manage these downloads).
                    try {
                        startActivity(
                            Intent("com.android.settings.TTS_SETTINGS")
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            startActivity(
                                Intent(Settings.ACTION_SOUND_SETTINGS)
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                            result.success(true)
                        } catch (e2: Exception) {
                            result.success(false)
                        }
                    }
                }
                "openSpeechSettings" -> {
                    try {
                        startActivity(
                            Intent("android.settings.VOICE_INPUT_SETTINGS")
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Accessibility & System Channel
        val aChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        accessibilityChannel = aChannel
        // On-device LLM channel (offline AI models via MediaPipe GenAI)
        GenyLocalLlm.register(flutterEngine)
        setupPowerReceiver()
        aChannel.setMethodCallHandler { call, result ->
                val service = AgentAccessibilityService.instance
                when (call.method) {
                    "isServiceEnabled" -> result.success(
                        AgentAccessibilityService.isConnected
                    )

                    "openAccessibilitySettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(true)
                    }

                    "openAppInfoSettings" -> {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", packageName, null)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    }

                    "getSmsMessages" -> {
                        val limit = (call.argument<Number>("limit") ?: 20).toInt()
                        try {
                            val messages = mutableListOf<Map<String, Any>>()
                            val cursor = contentResolver.query(
                                Uri.parse("content://sms/inbox"),
                                arrayOf("_id", "address", "body", "date", "read"),
                                null, null, "date DESC LIMIT $limit"
                            )
                            cursor?.use {
                                val addressIdx = it.getColumnIndex("address")
                                val bodyIdx = it.getColumnIndex("body")
                                val dateIdx = it.getColumnIndex("date")
                                val readIdx = it.getColumnIndex("read")
                                val idIdx = it.getColumnIndex("_id")
                                while (it.moveToNext()) {
                                    messages.add(
                                        mapOf(
                                            "id" to if (idIdx >= 0) (it.getString(idIdx) ?: "") else "",
                                            "sender" to if (addressIdx >= 0) (it.getString(addressIdx) ?: "") else "",
                                            "body" to if (bodyIdx >= 0) (it.getString(bodyIdx) ?: "") else "",
                                            "date" to if (dateIdx >= 0) it.getLong(dateIdx) else 0L,
                                            "isRead" to (if (readIdx >= 0) it.getInt(readIdx) == 1 else false)
                                        )
                                    )
                                }
                            }
                            if (messages.isEmpty()) {
                                val notifs = InboxNotificationListenerService.getRecentSms()
                                result.success(notifs)
                            } else {
                                result.success(messages)
                            }
                        } catch (e: Exception) {
                            val fallback = InboxNotificationListenerService.getRecentSms()
                            result.success(fallback)
                        }
                    }

                    "getEmailNotifications" -> {
                        result.success(InboxNotificationListenerService.getRecentEmails())
                    }

                    "isNotificationListenerEnabled" -> {
                        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
                        val enabled = flat != null && flat.contains(packageName)
                        result.success(enabled)
                    }

                    "openNotificationListenerSettings" -> {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    }

                    "openOverlaySettings" -> {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        ).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    }

                    "openBatteryOptimizationSettings" -> {
                        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    }

                    "getScreenSize" -> {
                        val metrics = resources.displayMetrics
                        result.success(
                            mapOf(
                                "width" to metrics.widthPixels,
                                "height" to metrics.heightPixels
                            )
                        )
                    }

                    "dumpScreen" -> {
                        if (service == null) {
                            result.error(
                                "SERVICE_OFF",
                                "Geny accessibility service is not enabled",
                                null
                            )
                        } else {
                            try {
                                result.success(service.dumpScreen())
                            } catch (e: Exception) {
                                result.error("DUMP_FAILED", e.message, null)
                            }
                        }
                    }

                    "takeScreenshot" -> {
                        if (service == null) {
                            result.error(
                                "SERVICE_OFF",
                                "Geny accessibility service is not enabled",
                                null
                            )
                        } else {
                            service.takeScreenshotBase64(result)
                        }
                    }

                    "clickAt" -> {
                        val x = (call.argument<Number>("x") ?: 0).toFloat()
                        val y = (call.argument<Number>("y") ?: 0).toFloat()
                        if (service == null) {
                            result.error("SERVICE_OFF", "Accessibility service is not enabled", null)
                        } else {
                            service.clickAt(x, y, result)
                        }
                    }

                    "swipe" -> {
                        val sx = (call.argument<Number>("startX") ?: 0).toFloat()
                        val sy = (call.argument<Number>("startY") ?: 0).toFloat()
                        val ex = (call.argument<Number>("endX") ?: 0).toFloat()
                        val ey = (call.argument<Number>("endY") ?: 0).toFloat()
                        val duration = (call.argument<Number>("durationMs") ?: 350).toLong()
                        if (service == null) {
                            result.error("SERVICE_OFF", "Accessibility service is not enabled", null)
                        } else {
                            service.swipe(sx, sy, ex, ey, duration, result)
                        }
                    }

                    "scroll" -> {
                        val direction = call.argument<String>("direction") ?: "down"
                        if (service == null) {
                            result.error("SERVICE_OFF", "Accessibility service is not enabled", null)
                        } else {
                            service.scroll(direction, result)
                        }
                    }

                    "typeText" -> {
                        val text = call.argument<String>("text") ?: ""
                        if (service == null) {
                            result.error("SERVICE_OFF", "Accessibility service is not enabled", null)
                        } else {
                            result.success(service.typeText(text))
                        }
                    }

                    "pressKey" -> {
                        val key = call.argument<String>("key") ?: ""
                        if (service == null) {
                            result.error("SERVICE_OFF", "Accessibility service is not enabled", null)
                        } else {
                            result.success(service.pressKey(key))
                        }
                    }

                    "getBatteryStatus" -> {
                        try {
                            val bm = getSystemService(android.content.Context.BATTERY_SERVICE) as? android.os.BatteryManager
                            val level = bm?.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: -1
                            val isCharging = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                                bm?.isCharging ?: false
                            } else {
                                false
                            }
                            result.success(mapOf("level" to level, "isCharging" to isCharging))
                        } catch (e: Exception) {
                            result.success(mapOf("level" to -1, "isCharging" to false))
                        }
                    }

                    "setTorch" -> {
                        val enable = call.argument<Boolean>("enable") ?: false
                        try {
                            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                                val cm = getSystemService(android.content.Context.CAMERA_SERVICE) as? android.hardware.camera2.CameraManager
                                val cameraId = cm?.cameraIdList?.firstOrNull()
                                if (cameraId != null) {
                                    cm.setTorchMode(cameraId, enable)
                                    result.success(true)
                                } else {
                                    result.success(false)
                                }
                            } else {
                                result.success(false)
                            }
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }

                    "playAudioFile" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrEmpty()) {
                            result.error("INVALID_PATH", "Audio file path is empty", null)
                            return@setMethodCallHandler
                        }
                        try {
                            playResult?.success(false)
                            playResult = result

                            mediaPlayer?.let {
                                if (it.isPlaying) it.stop()
                                it.release()
                            }
                            mediaPlayer = android.media.MediaPlayer().apply {
                                setDataSource(path)
                                setOnPreparedListener { start() }
                                setOnCompletionListener {
                                    release()
                                    mediaPlayer = null
                                    playResult?.success(true)
                                    playResult = null
                                }
                                setOnErrorListener { _, what, extra ->
                                    release()
                                    mediaPlayer = null
                                    playResult?.error("PLAY_ERROR", "MediaPlayer error $what extra $extra", null)
                                    playResult = null
                                    true
                                }
                                prepareAsync()
                            }
                        } catch (e: Exception) {
                            playResult = null
                            result.error("PLAY_FAILED", e.message, null)
                        }
                    }

                    "stopAudio" -> {
                        try {
                            mediaPlayer?.let {
                                if (it.isPlaying) it.stop()
                                it.release()
                            }
                            mediaPlayer = null
                            playResult?.success(false)
                            playResult = null
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }

                    // ---------------------------------------------------------
                    // Geny Eye Optical Scanner (Camera Capture)
                    // ---------------------------------------------------------
                    "captureCameraPhoto" -> {
                        try {
                            val photoDir = File(cacheDir, "camera_snapshots").apply { mkdirs() }
                            val photoFile = File(photoDir, "geny_eye_${System.currentTimeMillis()}.jpg")
                            currentPhotoPath = photoFile.absolutePath
                            val photoUri = FileProvider.getUriForFile(
                                this,
                                "$packageName.fileprovider",
                                photoFile
                            )
                            val takePictureIntent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
                                putExtra(MediaStore.EXTRA_OUTPUT, photoUri)
                                addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            pendingCameraResult = result
                            startActivityForResult(takePictureIntent, cameraRequestCode)
                        } catch (e: Exception) {
                            pendingCameraResult = null
                            result.error("CAMERA_LAUNCH_FAILED", e.message, null)
                        }
                    }

                    // ---------------------------------------------------------
                    // Autonomous Macro Recorder (Hermes Self-Creating Skills)
                    // ---------------------------------------------------------
                    "startMacroRecording" -> {
                        val s = AgentAccessibilityService.instance
                        if (s == null) {
                            result.error("SERVICE_OFF", "Accessibility service is not enabled", null)
                        } else {
                            s.startMacroRecording()
                            result.success(true)
                        }
                    }

                    "stopMacroRecording" -> {
                        val s = AgentAccessibilityService.instance
                        if (s == null) {
                            result.error("SERVICE_OFF", "Accessibility service is not enabled", null)
                        } else {
                            val events = s.stopMacroRecording()
                            result.success(events)
                        }
                    }

                    "isMacroRecording" -> {
                        val s = AgentAccessibilityService.instance
                        result.success(s?.getMacroRecordingStatus() ?: false)
                    }

                    // ---------------------------------------------------------
                    // 1. Direct Running System Specs Diagnostics (RAM, ROM, Battery, OS)
                    // ---------------------------------------------------------
                    "getSystemDiagnostics" -> {
                        try {
                            val actManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                            val memInfo = ActivityManager.MemoryInfo()
                            actManager.getMemoryInfo(memInfo)
                            val totalRamMb = (memInfo.totalMem / (1024 * 1024)).toInt()
                            val availRamMb = (memInfo.availMem / (1024 * 1024)).toInt()
                            val usedRamMb = totalRamMb - availRamMb

                            val statFs = StatFs(Environment.getDataDirectory().path)
                            val totalRomGb = (statFs.totalBytes.toDouble() / (1024 * 1024 * 1024)).roundToInt()
                            val freeRomGb = (statFs.availableBytes.toDouble() / (1024 * 1024 * 1024)).roundToInt()
                            val usedRomGb = totalRomGb - freeRomGb

                            val bm = getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
                            val batteryLevel = bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: -1
                            val isCharging = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) bm?.isCharging ?: false else false

                            val batteryIntent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                            val rawTemp = batteryIntent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) ?: 0
                            val batteryTempC = rawTemp / 10.0

                            result.success(mapOf(
                                "androidVersion" to "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})",
                                "manufacturer" to Build.MANUFACTURER,
                                "model" to Build.MODEL,
                                "device" to Build.DEVICE,
                                "totalRamMb" to totalRamMb,
                                "availRamMb" to availRamMb,
                                "usedRamMb" to usedRamMb,
                                "totalRomGb" to totalRomGb,
                                "freeRomGb" to freeRomGb,
                                "usedRomGb" to usedRomGb,
                                "batteryLevel" to batteryLevel,
                                "isCharging" to isCharging,
                                "batteryTempC" to batteryTempC
                            ))
                        } catch (e: Exception) {
                            result.error("DIAGNOSTICS_FAILED", e.message, null)
                        }
                    }

                    // ---------------------------------------------------------
                    // 2. Direct Top Installed Apps Tool
                    // ---------------------------------------------------------
                    "getInstalledApps" -> {
                        try {
                            val pm = packageManager
                            val intent = Intent(Intent.ACTION_MAIN, null).apply {
                                addCategory(Intent.CATEGORY_LAUNCHER)
                            }
                            val resolveInfos = pm.queryIntentActivities(intent, 0)
                            val apps = resolveInfos.map { ri ->
                                val appName = ri.loadLabel(pm).toString()
                                val pkgName = ri.activityInfo.packageName
                                mapOf(
                                    "name" to appName,
                                    "packageName" to pkgName
                                )
                            }.distinctBy { it["packageName"] }.sortedBy { (it["name"] ?: "").lowercase() }

                            val limit = (call.argument<Number>("limit") ?: 10).toInt()
                            result.success(apps.take(limit))
                        } catch (e: Exception) {
                            result.error("APPS_FAILED", e.message, null)
                        }
                    }

                    // ---------------------------------------------------------
                    // 3. Most Used Apps & Screen Time Tool
                    // ---------------------------------------------------------
                    "getAppUsageStats" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                                val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
                                val cal = Calendar.getInstance()
                                val endTime = cal.timeInMillis
                                cal.set(Calendar.HOUR_OF_DAY, 0)
                                cal.set(Calendar.MINUTE, 0)
                                cal.set(Calendar.SECOND, 0)
                                val startTime = cal.timeInMillis

                                val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startTime, endTime)
                                if (stats.isNullOrEmpty()) {
                                    result.success(emptyList<Map<String, Any>>())
                                    return@setMethodCallHandler
                                }

                                val pm = packageManager
                                val list = stats.filter { it.totalTimeInForeground > 60000L }
                                    .sortedByDescending { it.totalTimeInForeground }
                                    .take(10)
                                    .map { stat ->
                                        val appName = try {
                                            val appInfo = pm.getApplicationInfo(stat.packageName, 0)
                                            pm.getApplicationLabel(appInfo).toString()
                                        } catch (_: Exception) {
                                            stat.packageName
                                        }
                                        val minutes = stat.totalTimeInForeground / (1000 * 60)
                                        val hours = minutes / 60
                                        val remMin = minutes % 60
                                        val formatted = if (hours > 0) "${hours}h ${remMin}m" else "${remMin}m"
                                        mapOf(
                                            "name" to appName,
                                            "packageName" to stat.packageName,
                                            "minutes" to minutes,
                                            "formatted" to formatted
                                        )
                                    }
                                result.success(list)
                            } else {
                                result.success(emptyList<Map<String, Any>>())
                            }
                        } catch (e: Exception) {
                            result.error("USAGE_STATS_FAILED", e.message, null)
                        }
                    }

                    "hasUsageStatsPermission" -> {
                        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
                        val mode = appOps.checkOpNoThrow(
                            AppOpsManager.OPSTR_GET_USAGE_STATS,
                            Process.myUid(),
                            packageName
                        )
                        result.success(mode == AppOpsManager.MODE_ALLOWED)
                    }

                    "openUsageStatsSettings" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(true)
                    }

                    // ---------------------------------------------------------
                    // 4. Direct Phone Storage CRUD File Tool
                    // ---------------------------------------------------------
                    "manageStorageFile" -> {
                        val action = (call.argument<String>("action") ?: "read").lowercase()
                        val folderName = call.argument<String>("folder") ?: "Download"
                        val fileName = call.argument<String>("fileName") ?: ""
                        val content = call.argument<String>("content") ?: ""
                        val append = call.argument<Boolean>("append") ?: false

                        try {
                            val targetDir = getTargetFolder(folderName)
                            when (action) {
                                "create", "write" -> {
                                    if (fileName.isEmpty()) {
                                        result.error("INVALID_FILE", "File name cannot be empty", null)
                                        return@setMethodCallHandler
                                    }
                                    val file = File(targetDir, fileName)
                                    if (append && file.exists()) {
                                        file.appendText(content)
                                    } else {
                                        file.writeText(content)
                                    }
                                    val uri = Uri.fromFile(file)
                                    sendBroadcast(Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE, uri))
                                    result.success(mapOf(
                                        "success" to true,
                                        "path" to file.absolutePath,
                                        "size" to file.length(),
                                        "message" to "File $fileName successfully written to $folderName."
                                    ))
                                }
                                "read" -> {
                                    val file = File(targetDir, fileName)
                                    if (!file.exists()) {
                                        result.error("NOT_FOUND", "File $fileName not found in $folderName", null)
                                        return@setMethodCallHandler
                                    }
                                    val text = file.readText()
                                    result.success(mapOf(
                                        "success" to true,
                                        "content" to text,
                                        "path" to file.absolutePath,
                                        "size" to file.length()
                                    ))
                                }
                                "list" -> {
                                    val files = targetDir.listFiles()?.map { f ->
                                        mapOf(
                                            "name" to f.name,
                                            "path" to f.absolutePath,
                                            "isDirectory" to f.isDirectory,
                                            "size" to f.length(),
                                            "lastModified" to f.lastModified()
                                        )
                                    } ?: emptyList<Map<String, Any>>()
                                    result.success(mapOf(
                                        "success" to true,
                                        "folder" to targetDir.absolutePath,
                                        "files" to files
                                    ))
                                }
                                "delete" -> {
                                    val file = File(targetDir, fileName)
                                    val deleted = if (file.exists()) file.delete() else false
                                    result.success(mapOf(
                                        "success" to deleted,
                                        "message" to if (deleted) "File $fileName deleted." else "File $fileName could not be deleted."
                                    ))
                                }
                                else -> result.error("UNKNOWN_ACTION", "Action $action not recognized", null)
                            }
                        } catch (e: Exception) {
                            result.error("STORAGE_ERROR", e.message, null)
                        }
                    }

                    // ---------------------------------------------------------
                    // 5. Tactical Sentry Mode Anti-Theft Watchdog
                    // ---------------------------------------------------------
                    "startSentryMode" -> {
                        try {
                            if (sensorManager == null) {
                                sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
                                accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
                            }
                            isSentryArmed = true
                            lastAccelMagnitude = 0f
                            sentryLastTriggerTime = 0L
                            sensorManager?.registerListener(sentrySensorListener, accelerometer, SensorManager.SENSOR_DELAY_NORMAL)
                            result.success(true)
                        } catch (e: Exception) {
                            isSentryArmed = false
                            result.error("SENTRY_FAILED", e.message, null)
                        }
                    }

                    "stopSentryMode" -> {
                        isSentryArmed = false
                        try {
                            sensorManager?.unregisterListener(sentrySensorListener)
                        } catch (_: Exception) {}
                        android.util.Log.i("SENTRY_WATCHDOG", "Sentry mode stopped and sensor listener detached.")
                        result.success(true)
                    }

                    "isSentryArmed" -> {
                        result.success(isSentryArmed)
                    }

                    // ---------------------------------------------------------
                    // 6. Iron Man Zero-Touch Air Gestures
                    // ---------------------------------------------------------
                    "startAirGestures" -> {
                        try {
                            if (sensorManager == null) {
                                sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
                            }
                            proximitySensor = sensorManager?.getDefaultSensor(Sensor.TYPE_PROXIMITY)
                            if (proximitySensor == null) {
                                result.success(false)
                            } else {
                                isAirGesturesArmed = true
                                proximityNearTime = 0L
                                lastWaveTime = 0L
                                sensorManager?.registerListener(airGestureListener, proximitySensor, SensorManager.SENSOR_DELAY_UI)
                                result.success(true)
                            }
                        } catch (e: Exception) {
                            isAirGesturesArmed = false
                            result.error("AIR_GESTURE_ERROR", e.message, null)
                        }
                    }

                    "stopAirGestures" -> {
                        isAirGesturesArmed = false
                        try {
                            sensorManager?.unregisterListener(airGestureListener)
                        } catch (_: Exception) {}
                        result.success(true)
                    }

                    "isAirGesturesArmed" -> {
                        result.success(isAirGesturesArmed)
                    }

                    // ---------------------------------------------------------
                    // 7. Arc Reactor Charging Telemetry
                    // ---------------------------------------------------------
                    "getChargingTelemetry" -> {
                        try {
                            val data = getBatteryTelemetryDetails()
                            result.success(data)
                        } catch (e: Exception) {
                            result.error("BATTERY_ERROR", e.message, null)
                        }
                    }

                    // ---------------------------------------------------------
                    // 8. Network Subnet ARP Table Scanner
                    // ---------------------------------------------------------
                    "getNetworkArpTable" -> {
                        try {
                            val arpList = mutableListOf<Map<String, String>>()
                            val file = File("/proc/net/arp")
                            if (file.exists() && file.canRead()) {
                                file.forEachLine { line ->
                                    val parts = line.trim().split("\\s+".toRegex())
                                    if (parts.size >= 4 && parts[0] != "IP" && parts[3] != "00:00:00:00:00:00") {
                                        arpList.add(mapOf(
                                            "ip" to parts[0],
                                            "mac" to parts[3],
                                            "device" to (if (parts.size > 5) parts[5] else "wlan0")
                                        ))
                                    }
                                }
                            }
                            result.success(arpList)
                        } catch (e: Exception) {
                            result.success(emptyList<Map<String, String>>())
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
