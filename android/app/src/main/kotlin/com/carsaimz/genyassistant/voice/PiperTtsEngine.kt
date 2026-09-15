package com.carsaimz.genyassistant.voice

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.res.AssetManager
import android.util.Log
import java.io.File
import java.nio.FloatBuffer
import java.nio.LongBuffer
import java.text.Normalizer
import org.json.JSONObject

/**
 * Motor TTS neural Piper (TODO core-03 — docs §7.4).
 *
 * **PT** Inferência VITS do modelo .onnx do Piper com o ONNX Runtime que já
 * vem no app (mesma dependência do Silero VAD — nenhum nativo extra). O
 * pipeline replica o piper: texto → fonemas IPA (EspeakPhonemizer) →
 * decomposição NFD → IDs pelo phoneme_id_map do .onnx.json (config em
 * assets) com BOS "^" + pad "_" entre fonemas + EOS "$" → tensores
 * input/input_lengths/scales → áudio float [-1,1] no sample rate do modelo
 * (22050 Hz nas vozes do catálogo).
 * **EN** Piper's VITS .onnx inference with the ONNX Runtime already in the
 * app (same dependency as Silero VAD — no extra native code). The pipeline
 * mirrors piper: text → IPA phonemes (EspeakPhonemizer) → NFD decomposition
 * → IDs from the .onnx.json phoneme_id_map (asset config) with BOS "^" +
 * "_" pad between phonemes + EOS "$" → input/input_lengths/scales tensors →
 * float audio [-1,1] at the model's sample rate (22050 Hz for catalog
 * voices).
 */
class PiperTtsEngine(
    modelFile: File,
    jsonAsset: String,
    assets: AssetManager,
) : AutoCloseable {

    private val env: OrtEnvironment = OrtEnvironment.getEnvironment()
    private val session: OrtSession
    private val phonemeIdMap: Map<String, List<Long>>
    private val noiseScale: Float
    private val lengthScale: Float
    private val noiseW: Float
    val sampleRate: Int
    private val hasSidInput: Boolean

    init {
        val json = assets.open(jsonAsset).use { stream ->
            stream.bufferedReader().use { it.readText() }
        }
        val root = JSONObject(json)
        sampleRate = root.getJSONObject("audio").optInt("sample_rate", 22_050)
        val inference = root.getJSONObject("inference")
        noiseScale = inference.optDouble("noise_scale", 0.667).toFloat()
        lengthScale = inference.optDouble("length_scale", 1.0).toFloat()
        noiseW = inference.optDouble("noise_w", 0.8).toFloat()
        val map = mutableMapOf<String, MutableList<Long>>()
        val rawMap = root.getJSONObject("phoneme_id_map")
        for (key in rawMap.keys()) {
            val ids = mutableListOf<Long>()
            val arr = rawMap.getJSONArray(key)
            for (i in 0 until arr.length()) ids.add(arr.getLong(i))
            map[key] = ids
        }
        phonemeIdMap = map
        session = env.createSession(modelFile.absolutePath, OrtSession.SessionOptions())
        hasSidInput = session.inputNames.contains("sid")
    }

    /**
     * Texto → IDs de fonemas (piper: BOS + [id + pad por fonema] + EOS,
     * NFD antes do mapeamento; fonemas fora do mapa são descartados).
     */
    fun phonemeIds(text: String): LongArray {
        val phonemes = Normalizer.normalize(EspeakPhonemizer.phonemize(text), Normalizer.Form.NFD)
        val bos = idListOf(BOS) ?: listOf(1L)
        val pad = idListOf(PAD) ?: listOf(0L)
        val eos = idListOf(EOS) ?: listOf(2L)
        val ids = mutableListOf<Long>()
        ids.addAll(bos)
        ids.addAll(pad)
        for (cp in codePoints(phonemes)) {
            val mapped = idListOf(cp) ?: continue
            ids.addAll(mapped)
            ids.addAll(pad)
        }
        ids.addAll(eos)
        return ids.toLongArray()
    }

    /** Roda o VITS e devolve o áudio float [-1,1]. */
    fun synthesize(text: String): FloatArray {
        val ids = phonemeIds(text)
        if (ids.size <= 2) return FloatArray(0)
        val shape = longArrayOf(1, ids.size.toLong())
        OnnxTensor.createTensor(env, LongBuffer.wrap(ids), shape).use { input ->
            OnnxTensor.createTensor(env, LongBuffer.wrap(longArrayOf(ids.size.toLong())), longArrayOf(1)).use { lengths ->
                OnnxTensor.createTensor(
                    env,
                    FloatBuffer.wrap(floatArrayOf(noiseScale, lengthScale, noiseW)),
                    longArrayOf(3),
                ).use { scales ->
                    val inputs = mutableMapOf<String, OnnxTensor>(
                        "input" to input,
                        "input_lengths" to lengths,
                        "scales" to scales,
                    )
                    if (hasSidInput) {
                        OnnxTensor.createTensor(env, LongBuffer.wrap(longArrayOf(0L)), longArrayOf(1)).use { sid ->
                            inputs["sid"] = sid
                            return runWith(inputs)
                        }
                    }
                    return runWith(inputs)
                }
            }
        }
    }

    private fun runWith(inputs: Map<String, OnnxTensor>): FloatArray {
        session.run(inputs).use { output ->
            val tensor = output[0] as? OnnxTensor ?: return FloatArray(0)
            val buffer = tensor.floatBuffer ?: return FloatArray(0)
            val audio = FloatArray(buffer.remaining())
            buffer.get(audio)
            return audio
        }
    }

    private fun idListOf(key: String): List<Long>? = phonemeIdMap[key]

    private fun codePoints(s: String): List<String> {
        val out = mutableListOf<String>()
        var i = 0
        while (i < s.length) {
            val cp = s.codePointAt(i)
            out.add(String(Character.toChars(cp)))
            i += Character.charCount(cp)
        }
        return out
    }

    override fun close() {
        try {
            session.close()
        } catch (_: Exception) {
        }
    }

    private companion object {
        const val TAG = "geny-piper"
        const val BOS = "^"
        const val PAD = "_"
        const val EOS = "\$"
    }
}
