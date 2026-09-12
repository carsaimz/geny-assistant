package com.carsaimz.genyassistant.tools

import org.json.JSONArray
import org.json.JSONObject

/**
 * Registro central de ferramentas + validação estrita de parâmetros (docs §12.5).
 * Espelha core/src/tools/registry.rs e tools/validator.rs.
 */
class ToolRegistry {

    private val tools = LinkedHashMap<String, Tool>()

    /** Registra uma ferramenta; falha em caso de id vazio ou duplicado. */
    fun register(tool: Tool) {
        require(tool.id.isNotBlank()) { "id de ferramenta vazio" }
        check(!tools.containsKey(tool.id)) { "ferramenta duplicada: ${tool.id}" }
        tools[tool.id] = tool
    }

    fun registerAll(tools: List<Tool>) {
        tools.forEach { register(it) }
    }

    fun get(id: String): Tool? = tools[id]

    fun catalog(): List<ToolDefinition> = tools.values.map { it.definition() }

    fun catalogJson(): String {
        val array = JSONArray()
        catalog().forEach { array.put(it.toJson()) }
        return array.toString()
    }

    fun hasRootTools(): Boolean = tools.values.any { it.context == ToolContext.ROOT }

    companion object {
        private val TYPES = setOf("string", "number", "integer", "boolean", "array", "object")

        /**
         * Valida `params` contra a definição: rejeita desconhecidos, ausentes
         * obrigatórios, tipos incorretos e valores fora de allowed_values.
         */
        fun validate(def: ToolDefinition, params: JSONObject) {
            for (key in params.keys()) {
                if (def.params.none { it.name == key }) {
                    throw IllegalArgumentException("parametro desconhecido: $key")
                }
            }
            for (p in def.params) {
                require(p.type in TYPES) { "tipo invalido no esquema: ${p.type}" }
                val present = params.has(p.name) && !params.isNull(p.name)
                if (!present) {
                    if (p.required) {
                        throw IllegalArgumentException("parametro obrigatorio ausente: ${p.name}")
                    }
                    continue
                }
                checkType(p, params.get(p.name))
                val allowed = p.allowedValues
                if (allowed != null) {
                    val value = params.getString(p.name)
                    require(allowed.contains(value)) {
                        "valor '$value' nao permitido para '${p.name}'; permitidos: ${allowed.joinToString(", ")}"
                    }
                }
            }
        }

        private fun checkType(spec: ParamSpec, value: Any) {
            val ok = when (spec.type) {
                "string" -> value is String
                "number" -> value is Number
                "integer" -> value is Number && value.toDouble() % 1.0 == 0.0
                "boolean" -> value is Boolean
                "array" -> value is JSONArray
                "object" -> value is JSONObject
                else -> false
            }
            require(ok) {
                "tipo invalido para '${spec.name}': esperado ${spec.type}, obtido ${value::class.java.simpleName}"
            }
        }
    }
}
