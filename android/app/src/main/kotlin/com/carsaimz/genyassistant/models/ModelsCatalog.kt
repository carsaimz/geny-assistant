package com.carsaimz.genyassistant.models

import com.carsaimz.genyassistant.ai.LlmCatalog
import com.carsaimz.genyassistant.voice.PiperVoiceCatalog
import com.carsaimz.genyassistant.voice.VoiceCatalog

/**
 * Entrada unificada do catálogo de modelos para a tela nativa
 * (TODO android-03, issue #35).
 *
 * **PT** Espelha os três catálogos existentes (`VoiceCatalog` stt/vad,
 * `PiperVoiceCatalog` tts e `LlmCatalog` llm) numa única lista estável para
 * a UI nativa. Todos os modelos são baixados pelo [com.carsaimz.genyassistant.ai.ModelManager]
 * com SHA-256 pinado — nada é embutido no APK e nada sai do dispositivo.
 * **EN** Mirrors the three existing catalogs (stt/vad, tts and llm) into a
 * single stable list for the native UI. Every model is downloaded by
 * [com.carsaimz.genyassistant.ai.ModelManager] with a pinned SHA-256 — nothing
 * ships inside the APK and nothing leaves the device.
 */
data class ModelEntry(
    val id: String,
    /** stt | vad | tts | llm — agrupamento visual na tela. */
    val kind: String,
    val fileName: String,
    val label: String,
    val bytes: Long,
    val sha256: String,
)

object ModelsCatalog {

    /** Catálogo completo na ordem de exibição: stt → vad → tts → llm. */
    fun all(): List<ModelEntry> {
        val sttAndVad = VoiceCatalog.ALL.map { m ->
            ModelEntry(m.id, m.kind, m.fileName, labelFor(m.id, m.fileName, m.bytes), m.bytes, m.sha256)
        }
        val espeak = PiperVoiceCatalog.ESPEAK_DATA
        val tts = PiperVoiceCatalog.VOICES.map { v ->
            ModelEntry(v.id, v.kind, v.fileName, v.label, v.bytes, v.sha256)
        } + ModelEntry(
            espeak.id, espeak.kind, espeak.fileName,
            labelFor(espeak.id, espeak.fileName, espeak.bytes), espeak.bytes, espeak.sha256,
        )
        val llm = LlmCatalog.MODELS.map { m ->
            ModelEntry(m.id, "llm", m.fileName, m.label, m.bytes, m.sha256)
        }
        return sttAndVad + tts + llm
    }

    /** Rótulo curto quando o catálogo de origem não traz um pronto (stt/vad/espeak). */
    private fun labelFor(id: String, fileName: String, bytes: Long): String {
        val base = when (id) {
            "whisper-tiny" -> "Whisper Tiny"
            "whisper-base" -> "Whisper Base"
            "whisper-small" -> "Whisper Small"
            "whisper-medium" -> "Whisper Medium"
            "silero-vad" -> "Silero VAD"
            "espeak-data" -> "espeak-ng data"
            else -> fileName.substringBeforeLast('.')
        }
        return "$base (${formatBytes(bytes)})"
    }

    /**
     * Formata bytes de forma compacta e determinística: "912 B", "45 KB",
     * "469 MB", "1,4 GB" — 1 casa decimal só abaixo de 100. Puro e testável
     * (JVM); vírgula decimal (pt) sem depender do locale do dispositivo.
     */
    fun formatBytes(bytes: Long): String {
        if (bytes < 0) return "—"
        if (bytes < 1024) return "$bytes B"
        val kb = bytes / 1024.0
        if (kb < 1024) return trimNumber(kb) + " KB"
        val mb = kb / 1024.0
        if (mb < 1024) return trimNumber(mb) + " MB"
        return trimNumber(mb / 1024.0) + " GB"
    }

    private fun trimNumber(value: Double): String {
        val text = if (value >= 100 || value == value.toLong().toDouble()) {
            value.toLong().toString()
        } else {
            String.format(java.util.Locale.US, "%.1f", value)
        }
        return text.replace('.', ',')
    }

    /** Hash curto para o cartão ("be07e048e1e5…"); entrada curta → "—". */
    fun shortSha(sha256: String): String {
        val clean = sha256.trim()
        if (clean.length < 12) return "—"
        return clean.take(12) + "…"
    }
}
