package com.carsaimz.genyassistant.voice

/**
 * Catálogo de vozes Piper (TODO core-03 — docs §7.4).
 *
 * **PT** Vozes neurais VITS do projeto Piper (rhasspy/piper-voices, tag v1.0.0)
 * baixadas sob demanda pelo ModelManager com SHA-256 pinado (hashes obtidos
 * das fontes oficiais em 2026-09). Os JSON de configuração (phoneme_id_map,
 * escalas, sample rate) são arquivos pequenos (~5 KB) embarcados em assets —
 * config, não modelo. Os dados de fonemização do espeak-ng (dicionários +
 * fonotab, ~9 MB) vêm de um único download compartilhado entre vozes, do
 * release tts-models do sherpa-onnx, reempacotado em ZIP para extração com
 * java.util.zip (Android não tem bzip2). Nada disso sai do dispositivo.
 * **EN** Piper VITS neural voices (rhasspy/piper-voices, tag v1.0.0)
 * downloaded on demand by ModelManager with pinned SHA-256 (hashes from the
 * official sources on 2026-09). The config JSONs (phoneme_id_map, scales,
 * sample rate) are small (~5 KB) assets — config, not model. The espeak-ng
 * phonemization data (dicts + phontab, ~9 MB) is a single shared download
 * for all voices, from sherpa-onnx's tts-models release, repacked as ZIP for
 * java.util.zip extraction (Android has no bzip2). None of it leaves the
 * device.
 */
data class PiperVoiceInfo(
    val id: String,
    val kind: String,
    val fileName: String,
    val url: String,
    val sha256: String,
    val bytes: Long,
    /** BCP47 preferido (ex.: "pt-BR") — usado na escolha automática. */
    val languageTag: String,
    /** Voz espeak-ng (campo espeak.voice do .onnx.json). */
    val espeakVoice: String,
    /** JSON de configuração embarcado em assets/piper/. */
    val jsonAsset: String,
    val label: String,
)

data class EspeakDataInfo(
    val id: String,
    val kind: String,
    val fileName: String,
    val url: String,
    val sha256: String,
    val bytes: Long,
)

object PiperVoiceCatalog {

    private const val VOICES_BASE = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0"

    /**
     * Dados de fonemização espeak-ng (pt/en e todos os idiomas do projeto).
     * Origem: k2-fsa/sherpa-onnx release tts-models (espeak-ng-data.tar.bz2,
     * sha256 4135ccf8…), reempacotado como ZIP — mesmo conteúdo.
     */
    val ESPEAK_DATA = EspeakDataInfo(
        id = "espeak-data",
        kind = "tts",
        fileName = "espeak-ng-data.zip",
        url = "https://github.com/carsaimz/geny-assistant/releases/download/models-espeak-data-v1/espeak-ng-data.zip",
        sha256 = "2925ddcd97dfff6d27412c2656ef573f540c7dcfc1c4594ebe6ce6aaff67bb40",
        bytes = 9_037_020L,
    )

    val VOICE_FABER_PT_BR = PiperVoiceInfo(
        id = "piper-pt-br-faber-medium",
        kind = "tts",
        fileName = "pt_BR-faber-medium.onnx",
        url = "$VOICES_BASE/pt/pt_BR/faber/medium/pt_BR-faber-medium.onnx",
        sha256 = "858555e3a064209c57088fe6bd70c4c3dc54d03eaa00c45d5ecaf43a33f95aa7",
        bytes = 63_201_294L,
        languageTag = "pt-BR",
        espeakVoice = "pt-br",
        jsonAsset = "piper/pt_BR-faber-medium.json",
        label = "Faber (pt-BR, ~63 MB)",
    )

    val VOICE_TUGAO_PT_PT = PiperVoiceInfo(
        id = "piper-pt-pt-tugao-medium",
        kind = "tts",
        fileName = "pt_PT-tugao-medium.onnx",
        // O caminho no HuggingFace usa "tugão" — codificado na URL.
        url = "$VOICES_BASE/pt/pt_PT/tug%C3%A3o/medium/pt_PT-tug%C3%A3o-medium.onnx",
        sha256 = "223a7aaca69a155c61897e8ada7c3b13bc306e16c72dbb9c2fed733e2b0927d4",
        bytes = 63_201_294L,
        languageTag = "pt-PT",
        espeakVoice = "pt",
        jsonAsset = "piper/pt_PT-tugao.json",
        label = "Tugão (pt-PT, ~63 MB)",
    )

    val VOICE_AMY_EN = PiperVoiceInfo(
        id = "piper-en-us-amy-medium",
        kind = "tts",
        fileName = "en_US-amy-medium.onnx",
        url = "$VOICES_BASE/en/en_US/amy/medium/en_US-amy-medium.onnx",
        sha256 = "b3a6e47b57b8c7fbe6a0ce2518161a50f59a9cdd8a50835c02cb02bdd6206c18",
        bytes = 63_201_294L,
        languageTag = "en",
        espeakVoice = "en-us",
        jsonAsset = "piper/en_US-amy.json",
        label = "Amy (en-US, ~63 MB)",
    )

    val VOICES: List<PiperVoiceInfo> = listOf(
        VOICE_FABER_PT_BR,
        VOICE_TUGAO_PT_PT,
        VOICE_AMY_EN,
    )

    fun voiceById(id: String): PiperVoiceInfo? = VOICES.firstOrNull { it.id == id }

    fun voiceByFileName(fileName: String): PiperVoiceInfo? =
        VOICES.firstOrNull { it.fileName.equals(fileName, ignoreCase = true) }

    /**
     * Escolhe a voz para o idioma da conversa: match exato de BCP47
     * ("pt-BR" → Faber), depois pelo idioma base ("pt" → Tugão — variante
     * europeia cobre Moçambique/Angola; "en" → Amy). Sem match, null.
     */
    fun voiceForLanguage(tag: String): PiperVoiceInfo? {
        val normalized = tag.replace('_', '-').trim()
        val exact = VOICES.firstOrNull { it.languageTag.equals(normalized, ignoreCase = true) }
        if (exact != null) return exact
        val base = normalized.substringBefore('-').lowercase()
        if (base == "pt") return VOICE_TUGAO_PT_PT
        return VOICES.firstOrNull { it.languageTag.substringBefore('-') == base }
    }
}
