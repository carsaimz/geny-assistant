package com.carsaimz.genyassistant.bridge

import com.getcapacitor.JSObject
import org.json.JSONObject

/**
 * Envelope do contrato de `invokeTool` entre web e nativo (docs §12.4).
 *
 * **PT** A camada web declara `invokeTool(): Promise<{ outcomeJson: string }>`
 * (app/src/core/bridge.ts) e faz `JSON.parse(outcomeJson)`. O nativo deve
 * SEMPRE resolver com o outcome serializado dentro do campo `outcomeJson` —
 * devolver o objeto cru faz `outcomeJson === undefined` e a web quebra com
 * `"undefined" is not valid JSON" (bug da alpha.2: toda execução de
 * ferramenta no Android aparecia como falha mesmo quando executava).
 * **EN** The web layer declares `invokeTool(): Promise<{ outcomeJson: string }>`
 * (app/src/core/bridge.ts) and runs `JSON.parse(outcomeJson)`. The native
 * side must ALWAYS resolve with the serialized outcome inside `outcomeJson` —
 * returning the raw object makes `outcomeJson === undefined` and the web side
 * breaks with `"undefined" is not valid JSON` (alpha.2 bug: every Android
 * tool call showed as failed even when it executed).
 */
internal object OutcomeEnvelope {

    fun ok(callId: String, toolId: String, data: JSONObject): JSObject =
        wrap(
            callId,
            JSObject()
                .put("status", "ok")
                .put("tool_id", toolId)
                .put("data", data),
        )

    fun failed(callId: String, toolId: String, error: String): JSObject =
        wrap(
            callId,
            JSObject()
                .put("status", "failed")
                .put("tool_id", toolId)
                .put("error", error),
        )

    fun denied(callId: String, toolId: String, reason: String): JSObject =
        wrap(
            callId,
            JSObject()
                .put("status", "denied")
                .put("tool_id", toolId)
                .put("reason", reason),
        )

    private fun wrap(callId: String, outcome: JSObject): JSObject =
        JSObject()
            .put("outcomeJson", outcome.toString())
            .put("callId", callId)
}
