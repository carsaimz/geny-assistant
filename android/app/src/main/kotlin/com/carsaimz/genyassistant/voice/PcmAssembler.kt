package com.carsaimz.genyassistant.voice

/**
 * Montador do segmento de fala (espelho de `SegmentBuffer` em
 * core/src/vad.rs, TODO core-01/android-01).
 *
 * **PT** Guarda um pré-roll circular ANTES da fala começar, coleta a partir
 * da decisão do VAD e informa quando o silêncio é longo o bastante para
 * encerrar a captura automaticamente (modo "apertar-para-falar" pode usar
 * esse fim de fala como o fim da frase).
 * **EN** Keeps a circular pre-roll BEFORE speech starts, collects from the
 * VAD decision on, and reports when silence has lasted long enough to end
 * capture automatically (push-to-talk can use that end-of-speech as the end
 * of the utterance).
 */
class PcmAssembler(private val config: VadConfig = VadConfig()) {

    private val preRoll = ArrayDeque<ShortArray>()
    private val collected = ArrayList<ShortArray>()

    var speechDetected = false
        private set

    /** Amostras coletadas até agora (áudio útil, sem pré-roll). */
    var collectedSamples = 0
        private set

    fun push(frame: ShortArray, speech: Boolean) {
        if (!speech) {
            if (!speechDetected) {
                preRoll.addLast(frame.copyOf())
                while (preRoll.size > config.preRollFrames) preRoll.removeFirst()
            }
            return
        }
        if (!speechDetected) {
            speechDetected = true
            while (preRoll.isNotEmpty()) collected.add(preRoll.removeFirst())
        }
        collected.add(frame.copyOf())
        collectedSamples += frame.size
    }

    /** Devolve o PCM útil concatenado, ou null se nenhuma fala foi detectada. */
    fun finish(): ShortArray? {
        if (!speechDetected || collected.isEmpty()) return null
        val out = ShortArray(collected.sumOf { it.size })
        var off = 0
        for (chunk in collected) {
            chunk.copyInto(out, off)
            off += chunk.size
        }
        return out
    }
}
