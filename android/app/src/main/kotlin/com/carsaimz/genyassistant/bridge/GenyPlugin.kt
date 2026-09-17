package com.carsaimz.genyassistant.bridge

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import com.carsaimz.genyassistant.ai.CoreBridge
import com.carsaimz.genyassistant.ai.LocalLlmManager
import com.carsaimz.genyassistant.data.GenyDb
import com.carsaimz.genyassistant.models.ModelsActivity
import com.carsaimz.genyassistant.saf.SafOps
import com.carsaimz.genyassistant.saf.SafPaths
import com.carsaimz.genyassistant.saf.SafStore
import com.carsaimz.genyassistant.security.AuditLog
import com.carsaimz.genyassistant.security.ConfirmationManager
import com.carsaimz.genyassistant.security.KeystoreManager
import com.carsaimz.genyassistant.tools.AppTools
import com.carsaimz.genyassistant.tools.ConfirmationLevel
import com.carsaimz.genyassistant.tools.ContactSearchTool
import com.carsaimz.genyassistant.tools.DeviceTools
import com.carsaimz.genyassistant.tools.DialTool
import com.carsaimz.genyassistant.tools.LocationGetTool
import com.carsaimz.genyassistant.tools.NoteCreateTool
import com.carsaimz.genyassistant.tools.NoteListTool
import com.carsaimz.genyassistant.tools.NoteReadTool
import com.carsaimz.genyassistant.tools.NotificationDismissTool
import com.carsaimz.genyassistant.tools.NotificationReadTool
import com.carsaimz.genyassistant.tools.NotificationReplyTool
import com.carsaimz.genyassistant.tools.OcrReadTool
import com.carsaimz.genyassistant.tools.ReminderSetTool
import com.carsaimz.genyassistant.tools.SendSmsTool
import com.carsaimz.genyassistant.tools.ShareTextTool
import com.carsaimz.genyassistant.tools.Tool
import com.carsaimz.genyassistant.tools.ToolHost
import com.carsaimz.genyassistant.tools.ToolRegistry
import com.carsaimz.genyassistant.tools.WebSearchTool
import com.carsaimz.genyassistant.voice.TtsService
import com.carsaimz.genyassistant.voice.VoiceManager
import com.carsaimz.genyassistant.voice.WakeWordCatalog
import com.carsaimz.genyassistant.voice.WakeWordService
import com.getcapacitor.JSArray
import com.getcapacitor.JSObject
import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginMethod
import com.getcapacitor.annotation.CapacitorPlugin
import com.getcapacitor.annotation.ActivityCallback
import com.getcapacitor.annotation.Permission
import com.getcapacitor.annotation.PermissionCallback
import androidx.activity.result.ActivityResult
import android.net.Uri
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Ponte nativa Capacitor (docs §3.5): expõe catálogo de ferramentas, execução
 * validada, confirmação humana nativa, segredos do Keystore, contexto do
 * dispositivo e o pipeline de voz (Fase 2) para a camada web.
 *
 * RECORD_AUDIO é solicitada EM CONTEXTO — só quando o usuário aciona o
 * microfone (docs §14), nunca no arranque do app.
 */
@CapacitorPlugin(
    name = "GenyBridge",
    permissions = [
        Permission(strings = [Manifest.permission.RECORD_AUDIO], alias = "microphone"),
    ],
)
class GenyPlugin : Plugin() {

    private lateinit var registry: ToolRegistry
    private lateinit var keystore: KeystoreManager
    private lateinit var audit: AuditLog
    private lateinit var confirmation: ConfirmationManager
    private lateinit var db: GenyDb
    private lateinit var toolExecutor: java.util.concurrent.ExecutorService
    private var voice: VoiceManager? = null
    private var llm: LocalLlmManager? = null

    private val host = object : ToolHost {
        override fun appContext(): Context = context
        override fun audit(event: String, detail: String) {
            audit.log("tool", "$event — $detail")
        }
    }

    override fun load() {
        val appContext = context.applicationContext
        audit = AuditLog(File(appContext.filesDir, "audit"))
        keystore = KeystoreManager(appContext)
        confirmation = ConfirmationManager(audit)
        db = GenyDb(appContext)
        toolExecutor = Executors.newSingleThreadExecutor()

        registry = ToolRegistry()
        registry.registerAll(
            listOf(
                DeviceTools(),
                DeviceTools.timeTool(),
                DeviceTools.wifiTool(),
                DeviceTools.openSettingsTool(),
                AppTools(),
                AppTools.listTool(),
                WebSearchTool(),
                DialTool(),
                SendSmsTool(),
                ContactSearchTool(),
                NotificationReadTool(),
                NotificationDismissTool(),
                NotificationReplyTool(),
                NoteCreateTool(),
                NoteListTool(),
                NoteReadTool(),
                OcrReadTool(),
                ShareTextTool(),
                LocationGetTool(),
                ReminderSetTool(),
            ),
        )
        audit.log("bridge", "GenyBridge carregada com ${registry.catalog().size} ferramentas")

        // Progresso da fala (TTS) → canal `genyTts` para a UI (mãos-livres).
        TtsService.eventSink = { state ->
            notifyListeners(EVENT_TTS, JSObject().put("type", state))
        }

        // Wake word (TODO android-03b) → canal `genyWake` para a UI.
        WakeWordService.eventSink = { payload ->
            val obj = JSObject()
            payload.forEach { (k, v) -> obj.put(k, v) }
            notifyListeners(EVENT_WAKE, obj)
        }
    }

    // ------------------------------------------------------------ catálogo --

    @PluginMethod
    fun listTools(call: PluginCall) {
        val ret = JSObject()
        ret.put("tools", JSONArray(registry.catalog().map { it.toJson() }))
        call.resolve(ret)
    }

    // ----------------------------------------------------------- execução --

    @PluginMethod
    fun invokeTool(call: PluginCall) {
        val callId = call.getString("callId") ?: "call-${System.currentTimeMillis()}"
        val toolId = call.getString("toolId")
        val paramsRaw = call.getString("paramsJson") ?: "{}"
        if (toolId == null) {
            call.resolve(OutcomeEnvelope.failed(callId, "", "toolId ausente"))
            return
        }
        val tool = registry.get(toolId)
        if (tool == null) {
            call.resolve(OutcomeEnvelope.failed(callId, toolId, "ferramenta nao registrada: $toolId"))
            return
        }
        val params = try {
            JSONObject(paramsRaw)
        } catch (e: Exception) {
            call.resolve(OutcomeEnvelope.failed(callId, toolId, "paramsJson invalido: ${e.message}"))
            return
        }

        // Defesa em profundidade: SIMPLE+ exige aprovação prévia registrada
        // (via requestConfirmation) mesmo que a web já tenha confirmado.
        if (tool.confirmation != ConfirmationLevel.NONE && !confirmation.isPreApproved(toolId)) {
            call.resolve(OutcomeEnvelope.denied(callId, toolId, "sem aprovacao humana registrada"))
            return
        }

        val def = tool.definition()
        try {
            ToolRegistry.validate(def, params)
        } catch (e: IllegalArgumentException) {
            call.resolve(
                OutcomeEnvelope.failed(callId, toolId, e.message ?: "validacao falhou"),
            )
            return
        }

        toolExecutor.execute {
            val started = System.currentTimeMillis()
            val result = try {
                val data = tool.execute(params, host)
                db.recordToolCall(callId, toolId, params.toString(), "ok", started)
                audit.log("tool", "ok: $toolId em ${System.currentTimeMillis() - started}ms")
                OutcomeEnvelope.ok(callId, toolId, data)
            } catch (e: Exception) {
                db.recordToolCall(callId, toolId, params.toString(), "failed", started)
                audit.log("tool", "falha: $toolId — ${e.message}")
                OutcomeEnvelope.failed(callId, toolId, e.message ?: e.javaClass.simpleName)
            }
            call.resolve(result)
        }
    }

    // ------------------------------------------------------- confirmação --

    @PluginMethod
    fun requestConfirmation(call: PluginCall) {
        val toolId = call.getString("toolId") ?: ""
        val summary = call.getString("summary") ?: toolId
        val activity: Activity? = bridge.activity
        if (activity == null || activity.isFinishing) {
            // Fail-safe: sem Activity viva, não há como obter confirmação humana.
            audit.log("confirmation", "negado (sem UI): $toolId")
            call.resolve(JSObject().put("approved", false))
            return
        }
        activity.runOnUiThread {
            showConfirmationDialog(activity, toolId, summary, call)
        }
    }

    private fun showConfirmationDialog(
        activity: Activity,
        toolId: String,
        summary: String,
        call: PluginCall,
    ) {
        val builder = com.google.android.material.dialog.MaterialAlertDialogBuilder(activity)
            .setTitle(activity.getString(com.carsaimz.genyassistant.R.string.app_name))
            .setMessage(summary)
            .setCancelable(false)
            .setPositiveButton(com.carsaimz.genyassistant.R.string.confirm_allow_once) { dialog, _ ->
                confirmation.recordApproval(toolId)
                vibrateTick(activity)
                dialog.dismiss()
                call.resolve(JSObject().put("approved", true))
            }
            .setNegativeButton(com.carsaimz.genyassistant.R.string.confirm_deny) { dialog, _ ->
                audit.log("confirmation", "negado pelo usuario: $toolId")
                dialog.dismiss()
                call.resolve(JSObject().put("approved", false))
            }
        builder.show()
    }

    private fun vibrateTick(activity: Activity) {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vm = activity.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            vm?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            activity.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
        vibrator?.vibrate(VibrationEffect.createOneShot(40, VibrationEffect.DEFAULT_AMPLITUDE))
    }

    // -------------------------------------------------------------- HUD --

    @PluginMethod
    fun startHud(call: PluginCall) {
        val activity = bridge.activity
        if (activity == null || !android.provider.Settings.canDrawOverlays(activity)) {
            call.reject("SYSTEM_ALERT_WINDOW nao concedida — autorize nas configuracoes")
            return
        }
        val intent = android.content.Intent(context, com.carsaimz.genyassistant.overlay.HudOverlayService::class.java)
        context.startService(intent)
        call.resolve()
    }

    @PluginMethod
    fun stopHud(call: PluginCall) {
        val intent = android.content.Intent(
            context,
            com.carsaimz.genyassistant.overlay.HudOverlayService::class.java,
        ).setAction(com.carsaimz.genyassistant.overlay.HudOverlayService.ACTION_HIDE)
        context.startService(intent)
        call.resolve()
    }

    // ------------------------------------------------------- dispositivo --

    @PluginMethod
    fun getDeviceContext(call: PluginCall) {
        val ctx = context
        val cm = ctx.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
        val online = cm?.getNetworkCapabilities(cm.activeNetwork)
            ?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true
        val battery = ctx.registerReceiver(null, android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = battery?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = battery?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val batteryPct = if (level >= 0 && scale > 0) (level * 100) / scale else 0
        val ret = JSObject()
            .put("online", online)
            .put("batteryPct", batteryPct)
            .put("batterySaver", isBatterySaver())
            .put("thermalHigh", false) // Fase 10: OnThermalStatusChangedListener
            .put("rootAvailable", hasRootBinary())
            .put("locale", java.util.Locale.getDefault().toLanguageTag())
        call.resolve(JSObject().put("json", ret.toString()))
    }

    private fun isBatterySaver(): Boolean {
        val pm = context.getSystemService(Context.POWER_SERVICE) as? android.os.PowerManager
        return pm?.isPowerSaveMode ?: false
    }

    private fun hasRootBinary(): Boolean {
        return try {
            val process = Runtime.getRuntime().exec(arrayOf("which", "su"))
            val ok = process.inputStream.read() > 0
            process.destroy()
            ok
        } catch (_: Exception) {
            false
        }
    }

    // ---------------------------------------------------------- segredos --

    @PluginMethod
    fun setApiSecret(call: PluginCall) {
        val name = call.getString("name") ?: "api-key"
        val value = call.getString("value")
        if (value.isNullOrEmpty()) {
            call.reject("value obrigatorio")
            return
        }
        keystore.storeSecret(name, value)
        audit.log("security", "segredo armazenado: $name")
        call.resolve()
    }

    @PluginMethod
    fun getApiSecret(call: PluginCall) {
        val name = call.getString("name") ?: "api-key"
        val secret = keystore.readSecret(name)
        audit.log("security", "segredo lido pelo app: $name")
        call.resolve(JSObject().put("value", secret ?: ""))
    }

    // ---------------------------------------------------------------- voz --
    // Fase 2 (docs §7): captura em contexto, STT sistema/whisper, TTS local.

    /** Canal de eventos de voz: notifyListeners("genyVoice", {type, ...}). */
    private fun voiceEmit(): (JSObject) -> Unit = { payload ->
        notifyListeners(EVENT_VOICE, payload)
    }

    private fun voiceManager(): VoiceManager =
        voice ?: VoiceManager(context, voiceEmit()).also { voice = it }

    /** Captura com rede de proteção: exceção vira evento de erro, não crash. */
    private fun startCaptureSafe(call: PluginCall, engine: VoiceManager.Engine, language: String, vadAutoStop: Boolean, modelId: String) {
        val ok = try {
            voiceManager().startCapture(engine, language, vadAutoStop, modelId)
        } catch (e: Exception) {
            voiceEmit()(
                JSObject()
                    .put("type", "error")
                    .put("code", "unavailable")
                    .put("message", e.message ?: "erro"),
            )
            false
        }
        call.resolve(JSObject().put("started", ok))
    }

    @PluginMethod
    fun getVoiceCapabilities(call: PluginCall) {
        call.resolve(JSObject().put("json", voiceManager().capabilities().toString()))
    }

    @PluginMethod
    fun startVoiceCapture(call: PluginCall) {
        val engineRaw = call.getString("engine") ?: "system"
        val engine = if (engineRaw == "whisper") VoiceManager.Engine.WHISPER else VoiceManager.Engine.SYSTEM
        val language = call.getString("language") ?: java.util.Locale.getDefault().toLanguageTag()
        val vadAutoStop = call.getBoolean("vadAutoStop", true) ?: true
        val modelId = call.getString("modelId") ?: "whisper-tiny"

        // Permissão EM CONTEXTO: pede só agora, no toque no microfone.
        if (getPermissionStates()["microphone"] != com.getcapacitor.PermissionState.GRANTED) {
            requestPermissionForAlias("microphone", call, "onMicPermission")
            return
        }
        startCaptureSafe(call, engine, language, vadAutoStop, modelId)
        audit.log("voice", "captura iniciada: engine=$engine lang=$language")
    }

    @PermissionCallback
    fun onMicPermission(call: PluginCall) {
        if (getPermissionStates()["microphone"] == com.getcapacitor.PermissionState.GRANTED) {
            // Repete o fluxo agora com a permissão concedida.
            val engineRaw = call.getString("engine") ?: "system"
            val engine = if (engineRaw == "whisper") VoiceManager.Engine.WHISPER else VoiceManager.Engine.SYSTEM
            val language = call.getString("language") ?: java.util.Locale.getDefault().toLanguageTag()
            val vadAutoStop = call.getBoolean("vadAutoStop", true) ?: true
            val modelId = call.getString("modelId") ?: "whisper-tiny"
            startCaptureSafe(call, engine, language, vadAutoStop, modelId)
            audit.log("voice", "captura iniciada pós-permissão: engine=$engine")
        } else {
            audit.log("voice", "permissão de microfone negada")
            voiceEmit()(JSObject().put("type", "error").put("code", "denied"))
            call.resolve(JSObject().put("started", false))
        }
    }

    @PluginMethod
    fun stopVoiceCapture(call: PluginCall) {
        voiceManager().stopCapture("user")
        call.resolve()
    }

    @PluginMethod
    fun cancelVoiceCapture(call: PluginCall) {
        voiceManager().cancelCapture()
        call.resolve()
    }

    @PluginMethod
    fun downloadVoiceModel(call: PluginCall) {
        val kind = call.getString("kind") ?: "stt"
        val id = call.getString("id") ?: ""
        if (id.isEmpty()) {
            call.reject("id obrigatorio")
            return
        }
        audit.log("voice", "download de modelo: $kind/$id")
        voiceManager().downloadModel(kind, id)
        call.resolve()
    }

    @PluginMethod
    fun deleteVoiceModel(call: PluginCall) {
        val file = call.getString("file") ?: ""
        if (file.isEmpty()) {
            call.reject("file obrigatorio")
            return
        }
        val ok = voiceManager().deleteModel(file)
        audit.log("voice", "modelo removido: $file ok=$ok")
        call.resolve(JSObject().put("deleted", ok))
    }

    @PluginMethod
    fun speak(call: PluginCall) {
        val text = call.getString("text").orEmpty()
        if (text.isBlank()) {
            call.reject("text obrigatorio")
            return
        }
        val language = call.getString("language") ?: java.util.Locale.getDefault().toLanguageTag()
        // engine: "system" (padrão) ou "piper" (TODO core-03) — o serviço
        // cai para o sistema sozinho se o piper não estiver pronto.
        val engine = call.getString("engine") ?: "system"
        audit.log("voice", "tts: engine=$engine lang=$language chars=${text.length}")
        com.carsaimz.genyassistant.voice.TtsService.speak(context, text, language, engine)
        call.resolve()
    }

    @PluginMethod
    fun stopSpeaking(call: PluginCall) {
        com.carsaimz.genyassistant.voice.TtsService.stop(context)
        call.resolve()
    }

    // ----------------------------------------------------------------- LLM --
    // Fase 3 (docs §6): modelo GGUF local — download, carga e geração.

    /** Canal de eventos do LLM: notifyListeners(EVENT_LLM, {type, ...}). */
    private fun llmManager(): LocalLlmManager =
        llm ?: LocalLlmManager(context) { payload ->
            notifyListeners(EVENT_LLM, JSObject.fromJSONObject(payload))
        }.also { llm = it }

    @PluginMethod
    fun getLlmCapabilities(call: PluginCall) {
        call.resolve(JSObject().put("json", llmManager().capabilities().toString()))
    }

    @PluginMethod
    fun downloadLlmModel(call: PluginCall) {
        val id = call.getString("id").orEmpty()
        if (id.isEmpty()) {
            call.reject("id obrigatorio")
            return
        }
        audit.log("llm", "download do modelo: $id")
        llmManager().downloadModel(id)
        call.resolve()
    }

    @PluginMethod
    fun deleteLlmModel(call: PluginCall) {
        val file = call.getString("file").orEmpty()
        if (file.isEmpty()) {
            call.reject("file obrigatorio")
            return
        }
        val ok = llmManager().deleteModel(file)
        audit.log("llm", "modelo removido: $file ok=$ok")
        call.resolve(JSObject().put("deleted", ok))
    }

    @PluginMethod
    fun loadLocalModel(call: PluginCall) {
        val file = call.getString("file").orEmpty()
        if (file.isEmpty()) {
            call.reject("file obrigatorio")
            return
        }
        audit.log("llm", "carga do modelo: $file")
        llmManager().load(file)
        call.resolve()
    }

    @PluginMethod
    fun unloadLocalModel(call: PluginCall) {
        audit.log("llm", "descarga do modelo")
        llmManager().unload()
        call.resolve()
    }

    @PluginMethod
    fun generateLocal(call: PluginCall) {
        // Contrato corrigido (TODO Fase 3): o app envia `messagesJson`
        // (string). Por robustez, aceita também `messages` (array JS) —
        // antes o app mandava a chave errada e todo pedido caía em
        // `sem_mensagens`. `system` traz o prompt de sistema por
        // idioma/cultura construído no app (buildSystemPrompt).
        val messagesJson = call.getString("messagesJson")
            ?: call.getArray("messages")?.toString()
            ?: "[]"
        val systemRaw = call.getString("system").orEmpty()
        // Fallback do prompt no lado nativo (TODO core-04): quando o app não
        // envia o prompt (buildSystemPrompt), o núcleo Rust real (UniFFI)
        // constrói o prompt por idioma/cultura com o catálogo REAL de
        // ferramentas; sem libgeny_core.so, cai no fallback do manager.
        val system = systemRaw.ifBlank {
            CoreBridge.buildSystemPrompt(
                java.util.Locale.getDefault().toLanguageTag(),
                registry.catalogJson(),
                privacyStatement = true,
            ).orEmpty()
        }
        val maxTokens = call.getInt("maxTokens", 256) ?: 256
        val temperature = call.getFloat("temperature", 0.7f) ?: 0.7f
        val topP = call.getFloat("topP", 0.9f) ?: 0.9f
        val seed = call.getInt("seed", -1) ?: -1
        val stream = call.getBoolean("stream", false) ?: false
        val started = System.currentTimeMillis()
        val finish: (JSONObject) -> Unit = { result ->
            if (result.has("error")) {
                audit.log("llm", "geracao falhou: ${result.optString("error")}")
            } else {
                db.recordToolCall(
                    "llm-$started",
                    "llm.generate",
                    messagesJson.take(512),
                    "ok",
                    started,
                )
                audit.log(
                    "llm",
                    "geracao ok em ${System.currentTimeMillis() - started}ms" +
                        if (result.optBoolean("stopped", false)) " (parada pelo usuario)" else "",
                )
            }
            call.resolve(JSObject().put("json", result.toString()))
        }
        if (stream) {
            // Streaming (TODO core-05b): cada peça sai pelo canal `genyLlm`
            // (evento llmToken) — a UI desenha progressivo e resolve no fim.
            llmManager().generateStreamAsync(
                messagesJson, system, maxTokens, temperature, topP, seed,
                onToken = { piece ->
                    try {
                        notifyListeners(
                            EVENT_LLM,
                            JSObject().put("type", "llmToken").put("text", piece),
                        )
                    } catch (_: Exception) {
                        // evento nunca derruba a geração
                    }
                },
                onDone = finish,
            )
        } else {
            llmManager().generateAsync(messagesJson, system, maxTokens, temperature, topP, seed, finish)
        }
    }

    @PluginMethod
    fun stopLocalGenerate(call: PluginCall) {
        audit.log("llm", "parada de geracao pedida pela UI")
        llmManager().stopGeneration()
        call.resolve()
    }

    // ------------------------------------------------ Wake word (Fase 3) --
    // TODO android-03b: wake word opcional (openWakeWord/ONNX), DESLIGADO por
    // padrão. Estado persistido nos fatos do Room; serviço em primeiro plano
    // com microfone; eventos no canal `genyWake`.

    @PluginMethod
    fun getWakeWordStatus(call: PluginCall) {
        val enabled = db.recallFact(FACT_WAKE_ENABLED) == "1"
        val modelId = db.recallFact(FACT_WAKE_MODEL) ?: WakeWordCatalog.WAKE_WORDS.first().id
        val modelsDir = File(context.filesDir, "models")
        val ready = com.carsaimz.genyassistant.voice.OpenWakeWordEngine.featuresReady(modelsDir)
        val models = JSArray()
        for (m in WakeWordCatalog.ALL) {
            val file = File(modelsDir, m.fileName)
            models.put(
                JSObject()
                    .put("id", m.id)
                    .put("label", m.label)
                    .put("file", m.fileName)
                    .put("bytes", m.bytes)
                    .put("downloaded", file.exists() && file.length() > 0),
            )
        }
        call.resolve(
            JSObject().put(
                "json",
                JSObject()
                    .put("enabled", enabled)
                    .put("modelId", modelId)
                    .put("ready", ready)
                    .put("models", models)
                    .toString(),
            ),
        )
    }

    @PluginMethod
    fun setWakeWordEnabled(call: PluginCall) {
        val enabled = call.getBoolean("enabled") ?: false
        val modelId = call.getString("modelId") ?: WakeWordCatalog.WAKE_WORDS.first().id
        val model = WakeWordCatalog.wakeWordById(modelId)
        if (enabled && model == null) {
            call.resolve(JSObject().put("ok", false).put("error", "modelo desconhecido"))
            return
        }
        if (!enabled) {
            db.rememberFact(FACT_WAKE_ENABLED, "0", System.currentTimeMillis())
            context.startService(
                Intent(context, WakeWordService::class.java).setAction(WakeWordService.ACTION_STOP),
            )
            audit.log("voice", "wake word desativado")
            call.resolve(JSObject().put("ok", true))
            return
        }
        // Permissão EM CONTEXTO: pede só no toque do usuário (docs §14).
        if (getPermissionStates()["microphone"] != com.getcapacitor.PermissionState.GRANTED) {
            requestPermissionForAlias("microphone", call, "onWakeWordPermission")
            return
        }
        val modelsDir = File(context.filesDir, "models")
        val modelFile = File(modelsDir, model!!.fileName)
        if (!com.carsaimz.genyassistant.voice.OpenWakeWordEngine.featuresReady(modelsDir) ||
            !(modelFile.exists() && modelFile.length() > 0)
        ) {
            call.resolve(JSObject().put("ok", false).put("error", "model_missing"))
            return
        }
        db.rememberFact(FACT_WAKE_ENABLED, "1", System.currentTimeMillis())
        db.rememberFact(FACT_WAKE_MODEL, modelId, System.currentTimeMillis())
        val service = Intent(context, WakeWordService::class.java)
            .setAction(WakeWordService.ACTION_START)
            .putExtra(WakeWordService.EXTRA_MODEL, model.fileName)
        context.startForegroundService(service)
        audit.log("voice", "wake word ativado: model=$modelId")
        call.resolve(JSObject().put("ok", true))
    }

    @PermissionCallback
    fun onWakeWordPermission(call: PluginCall) {
        if (getPermissionStates()["microphone"] == com.getcapacitor.PermissionState.GRANTED) {
            audit.log("voice", "permissão concedida: ativando wake word")
            setWakeWordEnabled(call)
        } else {
            audit.log("voice", "permissão de microfone negada (wake word)")
            call.resolve(JSObject().put("ok", false).put("error", "denied"))
        }
    }

    // ---------------------------------------------------------------- SAF --
    // Pastas autorizadas (TODO android-05, issue #40): o usuário autoriza
    // pastas com ACTION_OPEN_DOCUMENT_TREE e a ponte oferece criar/ler/
    // editar/excluir DENTRO do escopo autorizado, sempre auditado.

    private fun safStore(): SafStore = SafStore(db)

    @PluginMethod
    fun safPickFolder(call: PluginCall) {
        val intent =
            Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION,
            )
        startActivityForResult(call, intent, "onSafFolderPicked")
    }

    @ActivityCallback
    fun onSafFolderPicked(call: PluginCall?, result: ActivityResult) {
        val data = result?.data
        val uri = data?.data
        if (call == null || uri == null) {
            call?.resolve(JSObject().put("ok", false).put("error", "pasta nao selecionada"))
            return
        }
        try {
            context.contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
            safStore().add(uri.toString())
            audit.log("saf", "pasta autorizada: $uri")
            call.resolve(
                JSObject()
                    .put("ok", true)
                    .put("treeUri", uri.toString()),
            )
        } catch (e: Exception) {
            audit.log("saf", "falha ao autorizar pasta: ${e.message}")
            call.resolve(JSObject().put("ok", false).put("error", e.message ?: "falha saf"))
        }
    }

    @PluginMethod
    fun safAuthorized(call: PluginCall) {
        val resolver = context.contentResolver
        val persisted =
            resolver.persistedUriPermissions
                .filter { it.isReadPermission || it.isWritePermission }
                .map { it.uri.toString() }
                .toSet()
        val folders = JSArray()
        for (tree in safStore().list()) {
            folders.put(
                JSObject()
                    .put("treeUri", tree)
                    .put("persisted", tree in persisted),
            )
        }
        call.resolve(JSObject().put("ok", true).put("folders", folders))
    }

    @PluginMethod
    fun safRevoke(call: PluginCall) {
        val tree = call.getString("treeUri") ?: ""
        if (tree.isEmpty()) {
            call.resolve(JSObject().put("ok", false).put("error", "treeUri ausente"))
            return
        }
        try {
            val uri = Uri.parse(tree)
            context.contentResolver.releasePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
            safStore().remove(tree)
            audit.log("saf", "pasta revogada: $tree")
            call.resolve(JSObject().put("ok", true))
        } catch (e: Exception) {
            call.resolve(JSObject().put("ok", false).put("error", e.message ?: "falha saf"))
        }
    }

    private fun safTree(call: PluginCall): Uri? {
        val raw = call.getString("treeUri") ?: ""
        if (raw.isEmpty()) {
            call.resolve(JSObject().put("ok", false).put("error", "treeUri ausente"))
            return null
        }
        // Defesa: só executa em pastas que o usuário autorizou de fato.
        if (raw !in safStore().list()) {
            audit.log("saf", "acesso a pasta nao autorizada: $raw")
            call.resolve(JSObject().put("ok", false).put("error", "pasta nao autorizada"))
            return null
        }
        return Uri.parse(raw)
    }

    @PluginMethod
    fun safList(call: PluginCall) {
        val tree = safTree(call) ?: return
        val path = call.getString("path") ?: ""
        call.resolve(JSObject.fromJSONObject(SafOps.list(context.contentResolver, tree, path)))
    }

    @PluginMethod
    fun safRead(call: PluginCall) {
        val tree = safTree(call) ?: return
        val path = call.getString("path") ?: ""
        if (path.isBlank()) {
            call.resolve(JSObject().put("ok", false).put("error", "path ausente"))
            return
        }
        call.resolve(JSObject.fromJSONObject(SafOps.readText(context.contentResolver, tree, path)))
    }

    @PluginMethod
    fun safWrite(call: PluginCall) {
        val tree = safTree(call) ?: return
        val path = call.getString("path") ?: ""
        val content = call.getString("content") ?: ""
        val append = call.getBoolean("append") ?: false
        if (path.isBlank()) {
            call.resolve(JSObject().put("ok", false).put("error", "path ausente"))
            return
        }
        val result = SafOps.writeText(context.contentResolver, tree, path, content, append)
        audit.log("saf", "escrita: $path (append=$append) -> ${result.optBoolean("ok")}")
        call.resolve(JSObject.fromJSONObject(result))
    }

    @PluginMethod
    fun safDelete(call: PluginCall) {
        val tree = safTree(call) ?: return
        val path = call.getString("path") ?: ""
        if (path.isBlank()) {
            call.resolve(JSObject().put("ok", false).put("error", "path ausente"))
            return
        }
        val result = SafOps.delete(context.contentResolver, tree, path)
        audit.log("saf", "exclusao: $path -> ${result.optBoolean("ok")}")
        call.resolve(JSObject.fromJSONObject(result))
    }

    @PluginMethod
    fun safMkdir(call: PluginCall) {
        val tree = safTree(call) ?: return
        val path = call.getString("path") ?: ""
        if (path.isBlank()) {
            call.resolve(JSObject().put("ok", false).put("error", "path ausente"))
            return
        }
        val result = SafOps.mkdir(context.contentResolver, tree, path)
        audit.log("saf", "mkdir: $path -> ${result.optBoolean("ok")}")
        call.resolve(JSObject.fromJSONObject(result))
    }

    // -------------------------------------------------------- Modelos (UI) --
    // Fase 3 (TODO android-03, issue #35): abre a tela nativa de Modelos —
    // espelho offline da seção web, com progresso, SHA-256 e espaço em disco.

    @PluginMethod
    fun openModelsScreen(call: PluginCall) {
        audit.log("bridge", "abrir tela nativa de modelos")
        val intent = Intent(context, ModelsActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
        call.resolve()
    }

    override fun handleOnDestroy() {
        voice?.release()
        voice = null
        llm?.release()
        llm = null
        toolExecutor.shutdown()
        toolExecutor.awaitTermination(2, TimeUnit.SECONDS)
        super.handleOnDestroy()
    }

    private companion object {
        const val EVENT_VOICE = "genyVoice"
        const val EVENT_TTS = "genyTts"
        const val EVENT_LLM = "genyLlm"
        const val EVENT_WAKE = "genyWake"
        const val FACT_WAKE_ENABLED = "wakeword.enabled"
        const val FACT_WAKE_MODEL = "wakeword.model"
    }
}
