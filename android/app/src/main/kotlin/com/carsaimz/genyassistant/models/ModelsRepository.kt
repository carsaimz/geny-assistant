package com.carsaimz.genyassistant.models

import android.content.Context
import android.os.StatFs
import com.carsaimz.genyassistant.ai.LlmCatalog
import com.carsaimz.genyassistant.ai.ModelManager
import com.carsaimz.genyassistant.voice.PiperTts
import com.carsaimz.genyassistant.voice.PiperVoiceCatalog
import com.carsaimz.genyassistant.voice.VoiceCatalog
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.io.File

/**
 * Estado on-device do catálogo de modelos para a tela nativa
 * (TODO android-03, issue #35).
 *
 * **PT** Lê o disco (`filesDir/models` + marcador do espeak-ng), expõe espaço
 * livre/usado e centraliza download/exclusão pela mesma infraestrutura da
 * ponte web — [ModelManager] com SHA-256 pinado. A guarda estática do
 * [ModelManager] impede que a tela nativa e a UI web baixem o mesmo arquivo
 * ao mesmo tempo.
 * **EN** Reads disk state (`filesDir/models` + the espeak-ng marker), exposes
 * free/used space and funnels download/delete through the same infrastructure
 * as the web bridge — [ModelManager] with pinned SHA-256. The static guard in
 * [ModelManager] keeps the native screen and the web UI from downloading the
 * same file concurrently.
 */
class ModelsRepository(private val context: Context) {

    /** Linha da tela: catálogo + estado do arquivo correspondente. */
    data class Row(
        val entry: ModelEntry,
        val downloaded: Boolean,
        val sizeOnDiskBytes: Long,
        val downloading: Boolean,
    )

    private val modelsDir: File by lazy {
        File(context.filesDir, "models").apply { mkdirs() }
    }

    // -------------------------------------------------------------- status --

    fun snapshot(): List<Row> = ModelsCatalog.all().map { entry ->
        val file = File(modelsDir, entry.fileName)
        val downloaded = when {
            entry.id == PiperVoiceCatalog.ESPEAK_DATA.id -> PiperTts.isEspeakDataReady(context)
            entry.kind == "tts" -> file.exists() && file.length() > 1_000_000L
            else -> file.exists() && file.length() > 0
        }
        Row(
            entry = entry,
            downloaded = downloaded,
            sizeOnDiskBytes = if (file.exists()) file.length() else 0L,
            downloading = ModelManager.isDownloading(entry.fileName),
        )
    }

    /** Espaço livre no volume dos dados do app, em bytes. */
    fun freeDiskBytes(): Long = try {
        StatFs(context.filesDir.path).availableBytes
    } catch (_: Exception) {
        -1L
    }

    /** Uso total do diretório de modelos (arquivos baixados), em bytes. */
    fun modelsDiskBytes(): Long =
        modelsDir.walkTopDown().filter { it.isFile }.sumOf { it.length() }

    // ----------------------------------------------------------- download --

    /**
     * Baixa a entrada com progresso (0..100) e resultado. O espeak-ng-data é
     * extraído para o diretório de dados após o download (mesmo fluxo da
     * ponte web) — o callback [onProgress] recebe -1 durante a extração.
     */
    fun download(
        entry: ModelEntry,
        onProgress: (Int) -> Unit,
        onDone: (Result<File>) -> Unit,
    ) {
        val manager = ModelManager(context)
        val isEspeak = entry.id == PiperVoiceCatalog.ESPEAK_DATA.id
        val espeakInfo = if (isEspeak) PiperVoiceCatalog.ESPEAK_DATA else null
        manager.download(
            url = espeakInfo?.url ?: urlFor(entry),
            name = entry.fileName,
            kind = entry.kind,
            expectedSha256 = entry.sha256,
            onProgress = { bytes, total ->
                val totalSafe = if (total > 0) total else entry.bytes
                onProgress(if (totalSafe > 0) ((bytes * 100) / totalSafe).toInt().coerceIn(0, 100) else 0)
            },
            onDone = { result ->
                if (!isEspeak) {
                    onDone(result)
                    return@download
                }
                result.fold(
                    onSuccess = { file ->
                        // Extração em outra thread para não travar a UI.
                        CoroutineScope(Dispatchers.IO).launch {
                            val ok = PiperTts.extractEspeakData(context, file)
                            onProgress(if (ok) 100 else -1)
                            onDone(
                                if (ok) Result.success(file)
                                else Result.failure(IllegalStateException("extracao falhou")),
                            )
                        }
                    },
                    onFailure = { e -> onDone(Result.failure(e)) },
                )
            },
        )
    }

    /** URL do catálogo de origem para a entrada. */
    private fun urlFor(entry: ModelEntry): String {
        VoiceCatalog.ALL.firstOrNull { it.id == entry.id }?.let { return it.url }
        PiperVoiceCatalog.VOICES.firstOrNull { it.id == entry.id }?.let { return it.url }
        PiperVoiceCatalog.ESPEAK_DATA.takeIf { it.id == entry.id }?.let { return it.url }
        return LlmCatalog.byId(entry.id)?.url.orEmpty()
    }

    // ------------------------------------------------------------- delete --

    /** Remove o modelo (e os dados extraídos, no caso do espeak-ng). */
    fun delete(entry: ModelEntry): Boolean {
        if (entry.id == PiperVoiceCatalog.ESPEAK_DATA.id) {
            PiperTts.deleteEspeakData(context)
        }
        val file = File(modelsDir, File(entry.fileName).name)
        return file.delete()
    }
}
