package com.carsaimz.genyassistant.security

import com.carsaimz.genyassistant.tools.ToolDefinition
import com.carsaimz.genyassistant.tools.ToolRegistry
import org.json.JSONObject
import java.io.File
import java.util.concurrent.ConcurrentHashMap

/**
 * Gerenciador de confirmação humana (docs §12.3, §13.4).
 *
 * Aprovações são concedidas pela UI (diálogo na Activity) e consumidas uma
 * única vez por invocação de ferramenta — defesa em profundidade mesmo que a
 * camada web já tenha confirmado. Sem UI disponível, a decisão é SEMPRE negar
 * (fail-safe).
 */
class ConfirmationManager(private val audit: AuditLog) {

    /** Aprovações pendentes por toolId → número de usos autorizados. */
    private val approvals = ConcurrentHashMap<String, Int>()

    /** Chamado pela UI quando o humano responde. */
    fun recordApproval(toolId: String, uses: Int = 1) {
        approvals.merge(toolId, uses, Int::plus)
        audit.log("confirmation", "aprovado: $toolId (usos=$uses)")
    }

    /** Consome uma aprovação pendente, se existir. */
    fun consumeApproval(toolId: String): Boolean {
        val remaining = approvals[toolId] ?: return false
        if (remaining <= 1) approvals.remove(toolId) else approvals[toolId] = remaining - 1
        return true
    }

    /** Política fail-safe: sem UI, exige aprovação prévia registrada. */
    fun isPreApproved(toolId: String): Boolean = (approvals[toolId] ?: 0) > 0

    /** Resumo legível para o diálogo de confirmação. */
    fun summaryFor(def: ToolDefinition, params: JSONObject): String {
        return "${def.name} (${def.id})\nparams: ${params.toString().take(200)}"
    }

    /** Verificação extra para nível AUTHENTICATED (docs §12.3 nível 4). */
    fun canAuthenticate(deviceSecure: Boolean): Boolean = deviceSecure

    companion object {
        /** Registra negação para auditoria. */
        fun deny(audit: AuditLog, def: ToolDefinition) {
            audit.log("confirmation", "negado: ${def.id}")
        }
    }
}

/**
 * Log de auditoria local (docs §13.6): JSON Lines rotativo em filesDir/audit/.
 * Nada sai do dispositivo — exportação só por ação explícita do usuário.
 */
class AuditLog(private val dir: File) {

    private val file: File by lazy {
        File(dir.apply { mkdirs() }, "audit.log")
    }

    @Synchronized
    fun log(category: String, message: String) {
        rotateIfNeeded()
        val entry = JSONObject()
            .put("at", System.currentTimeMillis())
            .put("category", category)
            .put("message", message)
        file.appendText(entry.toString() + "\n")
    }

    @Synchronized
    fun readLast(lines: Int): List<String> {
        if (!file.exists()) return emptyList()
        return file.readLines().takeLast(lines)
    }

    @Synchronized
    fun clear() {
        if (file.exists()) file.delete()
    }

    private fun rotateIfNeeded() {
        if (file.exists() && file.length() > MAX_BYTES) {
            val rotated = File(dir, "audit.1.log")
            if (rotated.exists()) rotated.delete()
            file.renameTo(rotated)
        }
    }

    private companion object {
        const val MAX_BYTES = 512L * 1024L
    }
}
