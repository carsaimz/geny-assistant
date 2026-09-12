package com.carsaimz.genyassistant

import com.carsaimz.genyassistant.tools.ConfirmationLevel
import com.carsaimz.genyassistant.tools.ParamSpec
import com.carsaimz.genyassistant.tools.ToolContext
import com.carsaimz.genyassistant.tools.ToolDefinition
import com.carsaimz.genyassistant.tools.ToolRegistry
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/** Validação estrita de parâmetros — espelha os testes do núcleo Rust. */
class ToolValidatorTest {

    private fun def() = ToolDefinition(
        id = "sms.send",
        name = "Enviar SMS",
        description = "Envia um SMS",
        params = listOf(
            ParamSpec("to", "string", required = true, description = "destino"),
            ParamSpec("body", "string", required = true, description = "texto"),
            ParamSpec(
                "priority",
                "string",
                required = false,
                description = "prioridade",
                allowedValues = listOf("normal", "alta"),
            ),
        ),
        permissions = listOf("android.permission.SEND_SMS"),
        confirmation = ConfirmationLevel.EXPLICIT,
        context = ToolContext.APP,
    )

    @Test
    fun aceitaParametrosValidos() {
        val params = JSONObject().put("to", "+258840000000").put("body", "ola").put("priority", "alta")
        ToolRegistry.validate(def(), params) // nao deve lancar
    }

    @Test
    fun rejeitaObrigatorioAusente() {
        val params = JSONObject().put("to", "+258840000000")
        val ex = assertThrows(IllegalArgumentException::class.java) {
            ToolRegistry.validate(def(), params)
        }
        assertTrue(ex.message!!.contains("obrigatorio"))
    }

    @Test
    fun rejeitaParametroDesconhecido() {
        val params = JSONObject().put("to", "1").put("body", "x").put("hack", true)
        val ex = assertThrows(IllegalArgumentException::class.java) {
            ToolRegistry.validate(def(), params)
        }
        assertTrue(ex.message!!.contains("desconhecido"))
    }

    @Test
    fun rejeitaTipoIncorreto() {
        val params = JSONObject().put("to", 123).put("body", "x")
        val ex = assertThrows(IllegalArgumentException::class.java) {
            ToolRegistry.validate(def(), params)
        }
        assertTrue(ex.message!!.contains("tipo invalido"))
    }

    @Test
    fun rejeitaValorForaDoEnum() {
        val params = JSONObject().put("to", "1").put("body", "x").put("priority", "urgente")
        val ex = assertThrows(IllegalArgumentException::class.java) {
            ToolRegistry.validate(def(), params)
        }
        assertTrue(ex.message!!.contains("nao permitido"))
    }

    @Test
    fun definicaoSerializaCatalogoEmMinusculas() {
        val json = def().toJson()
        assertEquals("explicit", json.getString("confirmation"))
        assertEquals("app", json.getString("context"))
        assertTrue(json.getJSONArray("permissions").length() > 0)
    }

    @Test
    fun registroRejeitaDuplicados() {
        val registry = ToolRegistry()
        val d = def()
        registry.register(object : com.carsaimz.genyassistant.tools.Tool(
            id = d.id, name = d.name, description = d.description,
            params = d.params, permissions = d.permissions,
            confirmation = d.confirmation, context = d.context,
        ) {
            override fun execute(params: JSONObject, host: com.carsaimz.genyassistant.tools.ToolHost): JSONObject =
                JSONObject()
        })
        assertThrows(IllegalStateException::class.java) {
            registry.register(object : com.carsaimz.genyassistant.tools.Tool(
                id = d.id, name = d.name, description = d.description,
                params = d.params, permissions = d.permissions,
                confirmation = d.confirmation, context = d.context,
            ) {
                override fun execute(params: JSONObject, host: com.carsaimz.genyassistant.tools.ToolHost): JSONObject =
                    JSONObject()
            })
        }
    }
}
