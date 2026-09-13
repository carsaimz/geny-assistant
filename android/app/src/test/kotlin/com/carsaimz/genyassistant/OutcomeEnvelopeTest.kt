package com.carsaimz.genyassistant.bridge

import org.json.JSONException
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/**
 * Contrato do envelope de invokeTool (TODO android-05): a web faz
 * `JSON.parse(outcomeJson)` — o campo TEM que existir e ser JSON válido com
 * status/tool_id. Regressão do bug `"undefined" is not valid JSON` (alpha.2).
 */
class OutcomeEnvelopeTest {

    @Test
    fun ok_envolve_o_outcome_em_outcomeJson() {
        val data = JSONObject().put("opened", "com.android.calculator2")
        val env = OutcomeEnvelope.ok("call-1", "apps.open", data)

        assertTrue(env.has("outcomeJson"))
        assertEquals("call-1", env.getString("callId"))

        val parsed = JSONObject(env.getString("outcomeJson"))
        assertEquals("ok", parsed.getString("status"))
        assertEquals("apps.open", parsed.getString("tool_id"))
        assertEquals("com.android.calculator2", parsed.getJSONObject("data").getString("opened"))
    }

    @Test
    fun failed_envolve_erro() {
        val env = OutcomeEnvelope.failed("call-2", "apps.open", "aplicativo nao encontrado: x")
        val parsed = JSONObject(env.getString("outcomeJson"))
        assertEquals("failed", parsed.getString("status"))
        assertEquals("aplicativo nao encontrado: x", parsed.getString("error"))
    }

    @Test
    fun denied_envolve_motivo() {
        val env = OutcomeEnvelope.denied("call-3", "notes.create", "sem aprovacao humana registrada")
        val parsed = JSONObject(env.getString("outcomeJson"))
        assertEquals("denied", parsed.getString("status"))
        assertEquals("sem aprovacao humana registrada", parsed.getString("reason"))
    }

    @Test
    fun outcomeJson_eh_sempre_json_parseavel() {
        val envelopes = listOf(
            OutcomeEnvelope.ok("c", "time.now", JSONObject().put("iso", "2026-09-13T00:00:00Z")),
            OutcomeEnvelope.failed("c", "x", "erro com \"aspas\" e {chaves}"),
            OutcomeEnvelope.denied("c", "y", "motivo"),
        )
        for (env in envelopes) {
            try {
                JSONObject(env.getString("outcomeJson"))
            } catch (e: JSONException) {
                fail("outcomeJson deveria ser JSON válido: ${e.message}")
            }
        }
    }
}
