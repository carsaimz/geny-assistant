package com.carsaimz.genyassistant.voice

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import java.io.File
import java.nio.FloatBuffer
import kotlin.math.max
import kotlin.random.Random

/**
 * Motor de wake word openWakeWord (TODO android-03b) — porta fiel do
 * `AudioFeatures` + `Model.predict` do openwakeword 0.6 (ONNX), validada
 * numericamente contra o original (scripts/validate_oww.py, 2026-09).
 *
 * **PT** Pipeline por bloco de 80 ms (1280 amostras @ 16 kHz):
 *   1. melspectrogram.onnx: PCM16 (últimas 1280+480 amostras) → frames × 32 bins
 *   2. transformação `spec/10 + 2` (idêntica ao openwakeword)
 *   3. janela dos últimos 76 frames de mel → embedding_model.onnx → 96-d
 *   4. últimos 16 embeddings → modelo de wake → score [0..1]
 * As predições das 5 primeiras chamadas são zeradas (inicialização do
 * original) e o [WakeWordTrigger] aplica limiar + refratário. Frames de
 * tamanho arbitrário são acumulados internamente até fechar 1280 amostras.
 * **EN** Per-80 ms-block pipeline (1280 samples @ 16 kHz) mirroring
 * openwakeword: melspectrogram → spec/10+2 → 76-frame window → embedding →
 * last 16 features → wake model score. First 5 predictions are zeroed and
 * [WakeWordTrigger] applies threshold + refractory. Arbitrary frame sizes
 * are buffered internally until 1280 samples accumulate.
 */
class OpenWakeWordEngine(
    modelsDir: File,
    modelFileName: String,
    private val trigger: WakeWordTrigger = WakeWordTrigger(),
) : AutoCloseable {

    data class Result(val score: Float, val triggered: Boolean)

    private val env: OrtEnvironment = OrtEnvironment.getEnvironment()
    private val melSession: OrtSession
    private val embSession: OrtSession
    private val wakeSession: OrtSession

    /** Amostras ainda não processadas (int16). */
    private val pending = ArrayDeque<Short>()

    /** Contexto bruto para o melspectrogram (últimas CHUNK+CONTEXT amostras). */
    private val rawBuffer = ArrayDeque<Short>()

    /** Buffer de mel linear (frames × MEL_BINS); inicia com 76 linhas de 1. */
    private var melBuffer = FloatArray(MEL_FRAMES * MEL_BINS) { 1f }

    /** Embeddings 96-d concatenados (frame mais novo no fim). */
    private var featureBuffer = FloatArray(0)

    private var wakeInput: String? = null

    init {
        val opts = OrtSession.SessionOptions().apply {
            setInterOpNumThreads(1)
            setIntraOpNumThreads(1)
        }
        melSession = env.createSession(File(modelsDir, WakeWordCatalog.MELSPECTROGRAM.fileName).absolutePath, opts)
        embSession = env.createSession(File(modelsDir, WakeWordCatalog.EMBEDDING.fileName).absolutePath, opts)
        wakeSession = env.createSession(File(modelsDir, modelFileName).absolutePath, opts)
        warmStart()
    }

    /**
     * Processa um frame de áudio PCM16 (qualquer tamanho; tipicamente 480
     * amostras = 30 ms) e retorna score/trigger do ÚLTIMO bloco de 80 ms
     * processado. Sem bloco completo, retorna score 0 sem disparo.
     */
    fun process(frame: ShortArray): Result {
        for (s in frame) {
            pending.addLast(s)
            rawBuffer.addLast(s)
        }
        while (rawBuffer.size > RAW_BUFFER_MAX) rawBuffer.removeFirst()

        var result = Result(0f, false)
        while (pending.size >= CHUNK_SAMPLES) {
            val chunk = ShortArray(CHUNK_SAMPLES)
            repeat(CHUNK_SAMPLES) { i -> chunk[i] = pending.removeFirst() }
            result = processChunk(chunk)
        }
        return result
    }

    private fun processChunk(chunk: ShortArray): Result {
        // 1) melspectrogram com 480 amostras de contexto (como o original).
        val needed = CHUNK_SAMPLES + CONTEXT_SAMPLES
        val context = ShortArray(minOf(rawBuffer.size, needed))
        val skip = rawBuffer.size - context.size
        repeat(context.size) { i -> context[i] = rawBuffer.elementAt(skip + i) }
        val melInput = FloatArray(context.size) { context[it].toFloat() }
        val spec = runMel(melInput)
        appendMelFrames(spec)

        // 2) embedding: janela dos últimos 76 frames de mel.
        val window = melBuffer.copyOfRange(melBuffer.size - MEL_WINDOW_SAMPLES, melBuffer.size)
        val embedding = runEmbeddingBatch(window, 1)
        appendFeature(embedding)

        // 3) wake model: últimos 16 embeddings.
        val feats = lastFeatures(WAKE_FRAMES)
        val score = runWake(feats)
        return Result(score, trigger.onScore(score))
    }

    // ------------------------------------------------------------ buffers --

    private fun appendMelFrames(spec: FloatArray) {
        val frames = spec.size / MEL_BINS
        if (frames <= 0) return
        val keepOldFrames = max(MEL_BUFFER_MAX_FRAMES - frames, 0)
        val old = if (keepOldFrames > 0 && melBuffer.size > keepOldFrames * MEL_BINS) {
            melBuffer.copyOfRange(melBuffer.size - keepOldFrames * MEL_BINS, melBuffer.size)
        } else {
            FloatArray(0)
        }
        // transformação do openwakeword: spec/10 + 2
        val transformed = FloatArray(spec.size) { i -> spec[i] / 10f + 2f }
        melBuffer = old + transformed
    }

    private fun appendFeature(emb: FloatArray) {
        val keep = (FEATURE_BUFFER_MAX - 1).coerceAtLeast(0) * EMBEDDING_DIM
        val old = if (featureBuffer.size > keep) {
            featureBuffer.copyOfRange(featureBuffer.size - keep, featureBuffer.size)
        } else {
            featureBuffer
        }
        featureBuffer = old + emb
    }

    private fun lastFeatures(n: Int): FloatArray {
        val need = n * EMBEDDING_DIM
        val have = featureBuffer.copyOfRange(max(featureBuffer.size - need, 0), featureBuffer.size)
        if (have.size == need) return have
        // Aquecimento insuficiente: completa com zeros (scores ainda zerados).
        return FloatArray(need) { i -> have.getOrElse(i) { 0f } }
    }

    // ------------------------------------------------------------- ONNX --

    private fun runMel(input: FloatArray): FloatArray =
        melSession.run(
            mapOf(
                "input" to OnnxTensor.createTensor(
                    env, FloatBuffer.wrap(input), longArrayOf(1, input.size.toLong()),
                ),
            ),
        ).use { output ->
            flattenLastDims(output[0].value)
        }

    /**
     * Roda o embedding em lote e achata a saída [W,1,1,96] → W×96 floats
     * (o openwakeword faz `.squeeze()`; aqui mantemos o layout linear).
     */
    private fun runEmbeddingBatch(window: FloatArray, batch: Int): FloatArray {
        val shape = longArrayOf(batch.toLong(), MEL_FRAMES.toLong(), MEL_BINS.toLong(), 1)
        return embSession.run(
            mapOf("input_1" to OnnxTensor.createTensor(env, FloatBuffer.wrap(window), shape)),
        ).use { output ->
            val flat = flattenAll(output[0].value)
            val expected = batch * EMBEDDING_DIM
            when {
                flat.size == expected -> flat
                flat.size > expected -> flat.copyOfRange(flat.size - expected, flat.size)
                else -> flat
            }
        }
    }

    private fun runWake(feats: FloatArray): Float =
        wakeSession.run(
            mapOf(
                wakeInputName() to OnnxTensor.createTensor(
                    env, FloatBuffer.wrap(feats), longArrayOf(1, WAKE_FRAMES.toLong(), EMBEDDING_DIM.toLong()),
                ),
            ),
        ).use { output ->
            extractScore(output[0].value)
        }

    private fun wakeInputName(): String {
        wakeInput?.let { return it }
        wakeInput = wakeSession.inputNames.firstOrNull() ?: "x.1"
        return wakeInput!!
    }

    // -------------------------------------------------------- warm start --

    /**
     * Espelha o `__init__` do openwakeword: um lote de janelas de mel de 4 s
     * de ruído preenche o feature buffer inicial (sem inferência de wake).
     * RNG semeado — determinístico.
     */
    private fun warmStart() {
        val rng = Random(1_601)
        val noise = FloatArray(WARM_SECONDS * SAMPLE_RATE) { rng.nextInt(-1000, 1000).toFloat() }
        val spec = runMel(noise)
        val frames = spec.size / MEL_BINS
        if (frames < MEL_FRAMES) return
        var windows = 0
        var i = 0
        while (i + MEL_FRAMES <= frames) {
            windows++
            i += 8
        }
        if (windows <= 0) return
        val batch = FloatArray(windows * MEL_WINDOW_SAMPLES)
        var w = 0
        i = 0
        while (i + MEL_FRAMES <= frames) {
            for (f in 0 until MEL_FRAMES) {
                System.arraycopy(spec, (i + f) * MEL_BINS, batch, (w * MEL_FRAMES + f) * MEL_BINS, MEL_BINS)
            }
            w++
            i += 8
        }
        for (b in batch.indices) batch[b] = batch[b] / 10f + 2f
        featureBuffer = runEmbeddingBatch(batch, windows)
    }

    // ------------------------------------------------------------ helpers --

    /** Achata QUALQUER rank de saída ONNX numa lista linear de floats. */
    private fun flattenAll(value: Any): FloatArray {
        val out = ArrayList<Float>(1024)
        fun walk(v: Any) {
            when (v) {
                is Float -> out.add(v)
                is FloatArray -> v.forEach { f -> out.add(f) }
                is Array<*> -> v.forEach { e -> e?.let { walk(it) } }
            }
        }
        walk(value)
        return FloatArray(out.size) { out[it] }
    }

    /** Achata a saída do melspectrogram ([1,1,frames,32] ou [1,frames,32]). */
    private fun flattenLastDims(value: Any): FloatArray {
        val all = flattenAll(value)
        val rem = all.size % MEL_BINS
        return if (rem == 0) all else all.copyOfRange(rem, all.size)
    }

    private fun extractScore(value: Any): Float = when (value) {
        is Float -> value
        is FloatArray -> value[0]
        is Array<*> -> {
            var probe: Any? = value
            while (probe is Array<*>) probe = probe[0]
            if (probe is Float) probe as Float else (probe as? FloatArray)?.get(0) ?: 0f
        }
        else -> 0f
    }

    override fun close() {
        melSession.close()
        embSession.close()
        wakeSession.close()
    }

    companion object {
        const val SAMPLE_RATE = 16_000
        const val CHUNK_SAMPLES = 1_280 // 80 ms
        const val CONTEXT_SAMPLES = 480 // 160*3, como no openwakeword
        const val RAW_BUFFER_MAX = CHUNK_SAMPLES + CONTEXT_SAMPLES
        const val MEL_FRAMES = 76
        const val MEL_BINS = 32
        const val MEL_WINDOW_SAMPLES = MEL_FRAMES * MEL_BINS
        const val MEL_BUFFER_MAX_FRAMES = 970 // 10 s de frames (~97/s)
        const val EMBEDDING_DIM = 96
        const val WAKE_FRAMES = 16
        const val FEATURE_BUFFER_MAX = 120 // ~10 s de histórico
        const val WARM_SECONDS = 4

        /** Arquivos de características presentes e não vazios? */
        fun featuresReady(modelsDir: File): Boolean =
            listOf(WakeWordCatalog.MELSPECTROGRAM, WakeWordCatalog.EMBEDDING).all {
                val f = File(modelsDir, it.fileName)
                f.exists() && f.length() > 0
            }
    }
}
