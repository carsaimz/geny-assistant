package com.carsaimz.genyassistant.ai

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * Backend remoto/self-hosted compatível com a API OpenAI (docs §7.3, §7.4).
 * TLS obrigatório (cleartext desativado no manifest); a chave vive no Keystore.
 */
object RemoteBackend {

    data class Config(
        val baseUrl: String,
        val apiKey: String,
        val model: String,
        val timeoutMs: Int = 60_000,
    )

    /** Chamada chat/completions; retorna o texto da resposta. */
    suspend fun chatComplete(config: Config, messages: List<Pair<String, String>>): String {
        return withContext(Dispatchers.IO) {
            val url = config.baseUrl.trimEnd('/') + "/chat/completions"
            val body = JSONObject()
                .put("model", config.model)
                .put("temperature", 0.7)
                .put("max_tokens", 1024)
                .put(
                    "messages",
                    JSONArray().apply {
                        messages.forEach { (role, content) ->
                            put(JSONObject().put("role", role).put("content", content))
                        }
                    },
                )
            val connection = URL(url).openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.connectTimeout = 15_000
            connection.readTimeout = config.timeoutMs
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json")
            if (config.apiKey.isNotEmpty()) {
                connection.setRequestProperty("Authorization", "Bearer ${config.apiKey}")
            }
            try {
                connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
                val code = connection.responseCode
                if (code !in 200..299) {
                    throw IllegalStateException("backend respondeu $code")
                }
                val response = connection.inputStream.readBytes().toString(Charsets.UTF_8)
                parseContent(response)
            } finally {
                connection.disconnect()
            }
        }
    }

    /** Extrai `choices[0].message.content` da resposta OpenAI-compatível. */
    fun parseContent(raw: String): String {
        val root = JSONObject(raw)
        return root
            .getJSONArray("choices")
            .getJSONObject(0)
            .getJSONObject("message")
            .optString("content")
    }

    /** Procura um pedido de tool call `{"tool": ..., "params": {...}}` no texto. */
    fun tryParseToolCall(content: String): Pair<String, JSONObject>? {
        val start = content.indexOf('{')
        val end = content.lastIndexOf('}')
        if (start < 0 || end <= start) return null
        return try {
            val parsed = JSONObject(content.substring(start, end + 1))
            val tool = parsed.optString("tool")
            if (tool.isNotEmpty()) tool to parsed.optJSONObject("params") ?: JSONObject() else null
        } catch (_: Exception) {
            null
        }
    }
}
