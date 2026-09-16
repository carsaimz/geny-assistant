package com.carsaimz.genyassistant.voice

/**
 * Catálogo de wake word (Fase 3, TODO android-03b) — modelos openWakeWord
 * (https://github.com/dscripka/openWakeWord, Apache-2.0).
 *
 * **PT** O pipeline precisa de TRÊS peças: dois modelos de características
 * compartilhados (melspectrogram + embedding do Google speech_embedding) e um
 * modelo específico de frase de ativação. Nada é embutido no APK: tudo é
 * baixado sob demanda pelo ModelManager com SHA-256 pinado (hashes obtidos
 * dos assets oficiais da release v0.5.1 em 2026-09). Desligado por padrão.
 * **EN** The pipeline needs THREE pieces: two shared feature models
 * (melspectrogram + Google speech_embedding embedding) and one wake-phrase
 * model. Nothing ships inside the APK: everything is downloaded on demand by
 * the ModelManager with pinned SHA-256 (hashes from the official v0.5.1
 * release assets on 2026-09). Off by default.
 */
data class WakeWordModelInfo(
    val id: String,
    val kind: String,
    val fileName: String,
    val url: String,
    val sha256: String,
    val bytes: Long,
    val label: String,
)

object WakeWordCatalog {

    private const val BASE_URL =
        "https://github.com/dscripka/openWakeWord/releases/download/v0.5.1"

    /** Melspectrogram (compartilhado) — 16 kHz PCM16 → 32 bins mel. */
    val MELSPECTROGRAM = WakeWordModelInfo(
        id = "oww-melspectrogram",
        kind = "wakeword",
        fileName = "melspectrogram.onnx",
        url = "$BASE_URL/melspectrogram.onnx",
        sha256 = "ba2b0e0f8b7b875369a2c89cb13360ff53bac436f2895cced9f479fa65eb176f",
        bytes = 1_087_958L,
        label = "openWakeWord melspectrogram",
    )

    /** Embeddings do Google speech_embedding (compartilhado) — 76×32 mel → 96-d. */
    val EMBEDDING = WakeWordModelInfo(
        id = "oww-embedding",
        kind = "wakeword",
        fileName = "embedding_model.onnx",
        url = "$BASE_URL/embedding_model.onnx",
        sha256 = "70d164290c1d095d1d4ee149bc5e00543250a7316b59f31d056cff7bd3075c1f",
        bytes = 1_326_578L,
        label = "openWakeWord speech embedding",
    )

    /** Modelos de frase de ativação (entrada [1,16,96] → score [1,1]). */
    val WAKE_WORDS: List<WakeWordModelInfo> = listOf(
        WakeWordModelInfo(
            id = "oww-hey-jarvis",
            kind = "wakeword",
            fileName = "hey_jarvis_v0.1.onnx",
            url = "$BASE_URL/hey_jarvis_v0.1.onnx",
            sha256 = "94a13cfe60075b132f6a472e7e462e8123ee70861bc3fb58434a73712ee0d2cb",
            bytes = 1_271_370L,
            label = "\u201cHey Jarvis\u201d",
        ),
        WakeWordModelInfo(
            id = "oww-hey-mycroft",
            kind = "wakeword",
            fileName = "hey_mycroft_v0.1.onnx",
            url = "$BASE_URL/hey_mycroft_v0.1.onnx",
            sha256 = "c2a311e8fa1338de89c31b3b46dc4dffd4af2f9a8d6ddead48893c2d301b1f18",
            bytes = 857_691L,
            label = "\u201cHey Mycroft\u201d",
        ),
        WakeWordModelInfo(
            id = "oww-alexa",
            kind = "wakeword",
            fileName = "alexa_v0.1.onnx",
            url = "$BASE_URL/alexa_v0.1.onnx",
            sha256 = "6ff566a01d12670e8d9e3c59da32651db1575d17272a601b7f8a39283dfbae3e",
            bytes = 854_246L,
            label = "\u201cAlexa\u201d",
        ),
        WakeWordModelInfo(
            id = "oww-hey-rhasspy",
            kind = "wakeword",
            fileName = "hey_rhasspy_v0.1.onnx",
            url = "$BASE_URL/hey_rhasspy_v0.1.onnx",
            sha256 = "5a9b3ed3be2910e35780e097905aa9f35a9c10038df47914cf2b3ec4d670f6ea",
            bytes = 204_081L,
            label = "\u201cHey Rhasspy\u201d",
        ),
    )

    val ALL: List<WakeWordModelInfo> = listOf(MELSPECTROGRAM, EMBEDDING) + WAKE_WORDS

    fun byId(id: String): WakeWordModelInfo? = ALL.firstOrNull { it.id == id }

    /** Frase de ativação selecionável (sem os modelos de características). */
    fun wakeWordById(id: String): WakeWordModelInfo? = WAKE_WORDS.firstOrNull { it.id == id }
}
