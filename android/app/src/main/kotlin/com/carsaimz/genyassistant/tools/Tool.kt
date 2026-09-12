package com.carsaimz.genyassistant.tools

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** Níveis de confirmação humana (docs §12.3), espelham core/src/confirmation.rs. */
enum class ConfirmationLevel {
    NONE, SIMPLE, EXPLICIT, AUTHENTICATED;
}

/** Contexto de execução declarado pela ferramenta (docs §12.2). */
enum class ToolContext {
    APP, SERVICE, ROOT;
}

/** Especificação de um parâmetro da ferramenta. */
data class ParamSpec(
    val name: String,
    val type: String,
    val required: Boolean = false,
    val description: String = "",
    val allowedValues: List<String>? = null,
)

/** Definição completa de uma ferramenta (docs §12.2), espelha ToolDefinition em Rust. */
data class ToolDefinition(
    val id: String,
    val name: String,
    val description: String,
    val params: List<ParamSpec>,
    val permissions: List<String>,
    val confirmation: ConfirmationLevel,
    val context: ToolContext,
    val timeoutMs: Long = 10_000L,
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id)
        put("name", name)
        put("description", description)
        put(
            "params",
            JSONArray().apply {
                params.forEach { p ->
                    put(
                        JSONObject().apply {
                            put("name", p.name)
                            put("type", p.type)
                            put("required", p.required)
                            put("description", p.description)
                            p.allowedValues?.let { put("allowed_values", JSONArray(it)) }
                        },
                    )
                }
            },
        )
        put("permissions", JSONArray(permissions))
        put("confirmation", confirmation.name.lowercase())
        put("context", context.name.lowercase())
        put("timeout_ms", timeoutMs)
    }
}

/** Serviços de plataforma fornecidos às ferramentas. */
interface ToolHost {
    fun appContext(): Context
    fun audit(event: String, detail: String)
}

/**
 * Ferramenta executável. O modelo de IA apenas seleciona; a execução acontece
 * aqui, sempre validada e auditada (docs §12.1).
 */
abstract class Tool(
    val id: String,
    val name: String,
    val description: String,
    val params: List<ParamSpec> = emptyList(),
    val permissions: List<String> = emptyList(),
    val confirmation: ConfirmationLevel = ConfirmationLevel.NONE,
    val context: ToolContext = ToolContext.APP,
) {
    abstract fun execute(params: JSONObject, host: ToolHost): JSONObject

    fun definition(): ToolDefinition = ToolDefinition(
        id = id,
        name = name,
        description = description,
        params = params,
        permissions = permissions,
        confirmation = confirmation,
        context = context,
    )
}
