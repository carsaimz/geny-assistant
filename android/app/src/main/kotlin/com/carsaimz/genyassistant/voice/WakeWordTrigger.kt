package com.carsaimz.genyassistant.voice

/**
 * Gatilho de wake word — lógica PURA (sem Android/ONNX), espelhando o
 * comportamento de `openwakeword.model.Model.predict` (warm-up de 5 frames
 * com predição zerada) com refratário próprio para não re-disparar.
 *
 * **PT** Recebe o score bruto (0..1) a cada frame de 80 ms e decide se é um
 * disparo válido: score ≥ limiar APÓS o aquecimento e respeitando o tempo
 * mínimo entre disparos.
 * **EN** Receives the raw score (0..1) for each 80 ms frame and decides
 * whether it is a valid trigger: score ≥ threshold AFTER warm-up and
 * honouring the minimum time between triggers.
 *
 * JVM-testável (Fase 3, TODO android-03b).
 */
class WakeWordTrigger(
    private val threshold: Float = DEFAULT_THRESHOLD,
    private val warmupFrames: Int = WARMUP_FRAMES,
    private val cooldownMs: Long = COOLDOWN_MS,
    private val clock: () -> Long = { System.currentTimeMillis() },
) {

    private var predictions = 0
    private var lastTriggerMs = Long.MIN_VALUE

    /**
     * Registra um score e informa se deve disparar.
     * `false` tanto no aquecimento quanto no refratário.
     */
    fun onScore(score: Float): Boolean {
        predictions++
        if (predictions <= warmupFrames) return false
        if (score < threshold) return false
        val now = clock()
        if (lastTriggerMs != Long.MIN_VALUE && now - lastTriggerMs < cooldownMs) return false
        lastTriggerMs = now
        return true
    }

    fun reset() {
        predictions = 0
        lastTriggerMs = Long.MIN_VALUE
    }

    companion object {
        /** Limiar padrão da comunidade openWakeWord. */
        const val DEFAULT_THRESHOLD = 0.5f

        /** openWakeWord zera as 5 primeiras predições (inicialização). */
        const val WARMUP_FRAMES = 5

        /** Refratário entre disparos (evita detecções duplicadas). */
        const val COOLDOWN_MS = 2_500L
    }
}
