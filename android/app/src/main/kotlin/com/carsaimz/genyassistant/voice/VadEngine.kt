package com.carsaimz.genyassistant.voice

import android.content.Context
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import java.nio.FloatBuffer
import java.nio.LongBuffer
import java.io.File

/**
 * VAD — Voice Activity Detection (docs §7.2, TODO core-01).
 *
 * **PT** Dois motores com a mesma interface: energia RMS (espelho do core
 * Rust `core/src/vad.rs`, sempre disponível) e Silero v5 via ONNX Runtime
 * (quando o modelo está baixado). A escolha é automática: Silero se houver
 * modelo, energia como fallback — o app nunca deixa de gravar por causa do
 * VAD.
 * **EN** Two engines behind one interface: RMS energy (mirror of the Rust
 * core `core/src/vad.rs`, always available) and Silero v5 via ONNX Runtime
 * (when the model is downloaded). Selection is automatic: Silero if the model
 * exists, energy as fallback — recording never fails because of the VAD.
 */
data class VadDecision(
    val level: Float,
    val speech: Boolean,
    val started: Boolean,
    val ended: Boolean,
)

interface VadEngine {
    fun process(frame: ShortArray): VadDecision
    fun reset()
    fun close()
}

/** Configuração compartilhada pelos motores (30 ms @ 16 kHz = 480 amostras). */
data class VadConfig(
    val sampleRate: Int = 16_000,
    val frameMs: Int = 30,
    val rmsThreshold: Float = 0.015f,
    val hangoverFrames: Int = 8,
    val minSpeechFrames: Int = 4,
    val minSilenceFrames: Int = 16,
    /** Probabilidade mínima do Silero para considerar fala. */
    val sileroThreshold: Float = 0.5f,
    /** Frames de contexto guardados ANTES do início da fala (~150 ms = 5). */
    val preRollFrames: Int = 5,
) {
    val frameSamples: Int = sampleRate * frameMs / 1000
}

/** VAD por energia RMS com histerese — espelho de `EnergyVad` no core Rust. */
class EnergyVadEngine(private val config: VadConfig = VadConfig()) : VadEngine {

    private var speaking = false
    private var hangoverLeft = 0
    private var speechFrames = 0
    private var silenceFrames = 0

    override fun process(frame: ShortArray): VadDecision {
        val level = rmsNormalized(frame)
        val above = level >= config.rmsThreshold
        var started = false
        var ended = false

        if (above) {
            speechFrames++
            silenceFrames = 0
            hangoverLeft = config.hangoverFrames
            if (!speaking && speechFrames >= config.minSpeechFrames) {
                speaking = true
                started = true
            }
        } else {
            speechFrames = 0
            if (speaking) {
                if (hangoverLeft > 0) {
                    hangoverLeft--
                } else {
                    silenceFrames++
                    if (silenceFrames >= config.minSilenceFrames) {
                        speaking = false
                        silenceFrames = 0
                        ended = true
                    }
                }
            }
        }
        return VadDecision(level, speaking, started, ended)
    }

    override fun reset() {
        speaking = false
        hangoverLeft = 0
        speechFrames = 0
        silenceFrames = 0
    }

    override fun close() = Unit

    val isSpeaking: Boolean
        get() = speaking

    companion object {
        fun rmsNormalized(frame: ShortArray): Float {
            if (frame.isEmpty()) return 0f
            var sumSq = 0.0
            for (s in frame) {
                val v = s / 32768.0
                sumSq += v * v
            }
            val rms = kotlin.math.sqrt(sumSq / frame.size)
            return rms.toFloat().coerceIn(0f, 1f)
        }
    }
}

/**
 * Silero VAD v5 (ONNX) — entrada `input` [1,512] float normalizada,
 * `state` [2,1,128] float, `sr` int64 escalar; saída `output` [1,1] prob e
 * `stateN`. Estado (LSTM) mantido entre frames; reset a cada gravação.
 */
class SileroVadEngine(
    modelPath: String,
    private val config: VadConfig = VadConfig(),
) : VadEngine {

    private val env: OrtEnvironment = OrtEnvironment.getEnvironment()
    private val session: OrtSession

    private var state: Array<Array<Array<FloatArray>>> = Array(2) { arrayOf(arrayOf(FloatArray(128))) }
    private var speaking = false
    private var hangoverLeft = 0
    private var speechFrames = 0

    init {
        val opts = OrtSession.SessionOptions()
        session = env.createSession(modelPath, opts)
        val names: Set<String> = session.inputNames
        require("input" in names && "state" in names && "sr" in names) {
            "modelo VAD invalido: esperado Silero v5 (input/state/sr)"
        }
    }

    val isNeural: Boolean get() = true

    override fun process(frame: ShortArray): VadDecision {
        val samples = FloatArray(config.frameSamples) { i ->
            (frame.getOrElse(i) { 0 } / 32768f)
        }
        val input = OnnxTensor.createTensor(env, FloatBuffer.wrap(samples), longArrayOf(1, config.frameSamples.toLong()))
        val sr = OnnxTensor.createTensor(env, LongBuffer.wrap(longArrayOf(config.sampleRate.toLong())), longArrayOf())
        val inputs = mutableMapOf<String, OnnxTensor>("input" to input, "sr" to sr)
        var stateTensor: OnnxTensor? = null
        try {
            val prob: Float
            stateTensor = OnnxTensor.createTensor(env, flattenState(state), longArrayOf(2, 1, 128))
            inputs["state"] = stateTensor
            session.run(inputs).use { output ->
                prob = (output[0].value as Array<FloatArray>)[0][0]
                @Suppress("UNCHECKED_CAST")
                val newState = (output[1].value as Array<Array<Array<FloatArray>>>)
                state = newState
            }
            val above = prob >= config.sileroThreshold
            var started = false
            var ended = false
            if (above) {
                speechFrames++
                if (!speaking && speechFrames >= config.minSpeechFrames) {
                    speaking = true
                    started = true
                }
                hangoverLeft = config.hangoverFrames
            } else if (speaking) {
                if (hangoverLeft > 0) hangoverLeft-- else {
                    speaking = false
                    ended = true
                }
            }
            return VadDecision(prob, speaking, started, ended)
        } finally {
            input.close()
            sr.close()
            stateTensor?.close()
        }
    }

    private fun flattenState(s: Array<Array<Array<FloatArray>>>): FloatBuffer {
        val out = FloatBuffer.allocate(2 * 1 * 128)
        for (a in s) for (b in a) for (c in b) out.put(c)
        out.rewind()
        return out
    }

    override fun reset() {
        state = Array(2) { arrayOf(arrayOf(FloatArray(128))) }
        speaking = false
        hangoverLeft = 0
        speechFrames = 0
    }

    override fun close() {
        session.close()
    }

    val isSpeaking: Boolean
        get() = speaking

    companion object {
        /** Caminho do modelo baixado, ou null se ainda não existe. */
        fun modelFile(context: Context): File? {
            val f = File(File(context.filesDir, "models"), VoiceCatalog.VAD_SILERO.fileName)
            return if (f.exists() && f.length() > 0) f else null
        }
    }
}
