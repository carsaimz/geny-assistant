package com.carsaimz.genyassistant.voice

/**
 * Catálogo de modelos de voz (Fase 2 — docs §7.2, TODO core-02/core-01).
 *
 * **PT** Nenhum modelo é embutido no APK: tudo é baixado sob demanda pelo
 * ModelManager com verificação SHA-256 (hashes pinados abaixo, obtidos das
 * fontes oficiais em 2026-09). Modelos nunca saem do dispositivo.
 * **EN** No model ships inside the APK: everything is downloaded on demand by
 * the ModelManager with SHA-256 verification (pinned hashes below, taken from
 * the official sources on 2026-09). Models never leave the device.
 */
data class VoiceModelInfo(
    val id: String,
    val kind: String,
    val fileName: String,
    val url: String,
    val sha256: String,
    val bytes: Long,
)

object VoiceCatalog {

    private const val WHISPER_BASE_URL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main"

    /** Silero VAD v5 — https://github.com/snakers4/silero-vad (MIT). */
    val VAD_SILERO = VoiceModelInfo(
        id = "silero-vad",
        kind = "vad",
        fileName = "silero_vad.onnx",
        url = "https://github.com/snakers4/silero-vad/raw/master/src/silero_vad/data/silero_vad.onnx",
        sha256 = "1a153a22f4509e292a94e67d6f9b85e8deb25b4988682b7e174c65279d8788e3",
        bytes = 2_327_524L,
    )

    /** Whisper GGML (F16) — ggerganov/whisper.cpp, hashes do LFS do HuggingFace. */
    val STT_WHISPER_TINY = VoiceModelInfo(
        id = "whisper-tiny",
        kind = "stt",
        fileName = "ggml-tiny.bin",
        url = "$WHISPER_BASE_URL/ggml-tiny.bin",
        sha256 = "be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21",
        bytes = 77_691_713L,
    )
    val STT_WHISPER_BASE = VoiceModelInfo(
        id = "whisper-base",
        kind = "stt",
        fileName = "ggml-base.bin",
        url = "$WHISPER_BASE_URL/ggml-base.bin",
        sha256 = "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe",
        bytes = 147_951_465L,
    )
    val STT_WHISPER_SMALL = VoiceModelInfo(
        id = "whisper-small",
        kind = "stt",
        fileName = "ggml-small.bin",
        url = "$WHISPER_BASE_URL/ggml-small.bin",
        sha256 = "1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b",
        bytes = 487_601_967L,
    )
    val STT_WHISPER_MEDIUM = VoiceModelInfo(
        id = "whisper-medium",
        kind = "stt",
        fileName = "ggml-medium.bin",
        url = "$WHISPER_BASE_URL/ggml-medium.bin",
        sha256 = "6c14d5adee5f86394037b4e4e8b59f1673b6cee10e3cf0b11bbdbee79c156208",
        bytes = 1_533_763_059L,
    )

    val STT_MODELS: List<VoiceModelInfo> = listOf(
        STT_WHISPER_TINY,
        STT_WHISPER_BASE,
        STT_WHISPER_SMALL,
        STT_WHISPER_MEDIUM,
    )

    val ALL: List<VoiceModelInfo> = STT_MODELS + VAD_SILERO

    fun sttById(id: String): VoiceModelInfo? = STT_MODELS.firstOrNull { it.id == id }
}
