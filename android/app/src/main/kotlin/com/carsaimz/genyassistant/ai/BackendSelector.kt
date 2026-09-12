package com.carsaimz.genyassistant.ai

/**
 * Seleção dinâmica de backend (docs §7.6) — heurística v0 espelhando
 * core/src/backend.rs::select_backend. Fase 6 refina com complexidade da tarefa.
 */
object BackendSelector {

    enum class Mode { LOCAL, REMOTE, SELFHOSTED }

    data class DeviceContext(
        val online: Boolean,
        val batteryPct: Int,
        val batterySaver: Boolean,
        val thermalHigh: Boolean,
    )

    data class Candidate(val id: String, val mode: Mode)

    /**
     * Escolhe o backend: offline força local; economia de bateria/thermal alto
     * preferem local; tarefa complexa com bateria saudável prefere remoto.
     */
    fun select(
        candidates: List<Candidate>,
        ctx: DeviceContext,
        complexTask: Boolean = false,
    ): Candidate? {
        if (candidates.isEmpty()) return null
        if (!ctx.online) {
            return candidates.firstOrNull { it.mode == Mode.LOCAL }
        }
        if (ctx.batterySaver || ctx.thermalHigh) {
            return candidates.firstOrNull { it.mode == Mode.LOCAL } ?: candidates.first()
        }
        if (complexTask && ctx.batteryPct > 30) {
            candidates.firstOrNull { it.mode == Mode.REMOTE || it.mode == Mode.SELFHOSTED }
                ?.let { return it }
        }
        return candidates.first()
    }
}
