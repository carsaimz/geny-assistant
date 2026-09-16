package com.carsaimz.genyassistant.models

import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.carsaimz.genyassistant.R
import com.google.android.material.button.MaterialButton
import com.google.android.material.card.MaterialCardView
import java.io.File

/**
 * Tela nativa de Modelos (TODO android-03, issue #35) — espelho da seção web.
 *
 * **PT** Lista única dos catálogos stt/vad/tts/llm com estado do arquivo,
 * SHA-256 pinado, download com barra de progresso e exclusão — tudo offline,
 * pela mesma infraestrutura (`ModelsRepository` → `ModelManager`) da ponte
 * web. UI montada por código (sem XML de item): 13 cartões fixos, tema
 * `Theme.Geny` (Material3 DayNight).
 * **EN** Single list of the stt/vad/tts/llm catalogs with file state, pinned
 * SHA-256, download progress bar and delete — all offline, through the same
 * infrastructure (`ModelsRepository` → `ModelManager`) as the web bridge. UI
 * built in code (no item XML): 13 fixed cards, `Theme.Geny` theme
 * (Material3 DayNight).
 */
class ModelsActivity : AppCompatActivity() {

    private lateinit var repository: ModelsRepository
    private lateinit var diskSummary: TextView
    private val cards = mutableMapOf<String, CardViews>()

    /** Referências das views de um cartão, para atualizar estado/progresso. */
    private class CardViews(
        val status: TextView,
        val progress: ProgressBar,
        val download: MaterialButton,
        val delete: MaterialButton,
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        repository = ModelsRepository(this)
        setContentView(buildContent())
    }

    override fun onResume() {
        super.onResume()
        refresh()
    }

    // -------------------------------------------------------------- layout --

    private fun buildContent(): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(16), dp(16), dp(16))
        }

        val title = TextView(this).apply {
            text = getString(R.string.models_title)
            textSize = 22f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        }
        root.addView(title)

        diskSummary = TextView(this).apply {
            textSize = 13f
            setPadding(0, dp(4), 0, dp(12))
        }
        root.addView(diskSummary)

        val scroll = ScrollView(this).apply { isFillViewport = true }
        val list = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        scroll.addView(list)
        root.addView(scroll, LinearLayout.LayoutParams(MATCH_PARENT, 0, 1f))

        var lastKind = ""
        for (row in repository.snapshot()) {
            if (row.entry.kind != lastKind) {
                lastKind = row.entry.kind
                list.addView(sectionHeader(lastKind))
            }
            list.addView(buildCard(row))
        }
        return root
    }

    private fun sectionHeader(kind: String): TextView {
        val resId = when (kind) {
            "stt" -> R.string.models_section_stt
            "vad" -> R.string.models_section_vad
            "tts" -> R.string.models_section_tts
            else -> R.string.models_section_llm
        }
        return TextView(this).apply {
            text = getString(resId)
            textSize = 14f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            setPadding(0, dp(12), 0, dp(6))
        }
    }

    private fun buildCard(row: ModelsRepository.Row): View {
        val entry = row.entry
        val status = TextView(this).apply { textSize = 13f }
        val progress = ProgressBar(
            this, null, android.R.attr.progressBarStyleHorizontal,
        ).apply {
            max = 100
            visibility = View.GONE
        }
        val download = MaterialButton(this).apply {
            text = getString(R.string.models_action_download)
            textSize = 13f
        }
        val delete = MaterialButton(
            this, null, com.google.android.material.R.attr.materialButtonOutlinedStyle,
        ).apply {
            text = getString(R.string.models_action_delete)
            textSize = 13f
        }
        download.setOnClickListener { startDownload(entry) }
        delete.setOnClickListener { deleteModel(entry) }

        val buttonsRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
            addView(delete)
            addView(download, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginStart = dp(8)
            })
        }

        val body = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(12), dp(10), dp(12), dp(10))
            addView(TextView(context).apply {
                text = entry.label
                textSize = 16f
                setTypeface(typeface, android.graphics.Typeface.BOLD)
            })
            addView(TextView(context).apply {
                text = getString(
                    R.string.models_sha_label,
                    kindLabel(entry.kind),
                    ModelsCatalog.formatBytes(entry.bytes),
                    ModelsCatalog.shortSha(entry.sha256),
                )
                textSize = 12f
                alpha = 0.75f
                setPadding(0, dp(2), 0, dp(4))
            })
            addView(status)
            addView(progress, LinearLayout.LayoutParams(MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                setMargins(0, dp(4), 0, dp(4))
            })
            addView(buttonsRow)
        }

        cards[entry.id] = CardViews(status, progress, download, delete)
        return MaterialCardView(this).apply {
            radius = dp(10).toFloat()
            setContentPadding(0, 0, 0, 0)
            addView(body)
            layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                setMargins(0, 0, 0, dp(10))
            }
        }
    }

    // ---------------------------------------------------------------- ações --

    private fun startDownload(entry: ModelEntry) {
        val card = cards[entry.id] ?: return
        card.download.isEnabled = false
        card.delete.isEnabled = false
        card.status.text = getString(R.string.models_status_downloading, 0)
        card.progress.visibility = View.VISIBLE
        card.progress.isIndeterminate = false
        repository.download(
            entry,
            onProgress = { pct -> runOnUiThread { onProgressUpdate(entry.id, pct) } },
            onDone = { result -> runOnUiThread { onDownloadDone(entry, result) } },
        )
    }

    private fun onProgressUpdate(id: String, pct: Int) {
        val card = cards[id] ?: return
        if (pct < 0) {
            // Extração do espeak-ng em andamento (download já completou).
            card.status.text = getString(R.string.models_status_extracting)
            card.progress.isIndeterminate = true
            return
        }
        card.progress.isIndeterminate = false
        card.progress.progress = pct
        card.status.text = getString(R.string.models_status_downloading, pct)
    }

    private fun onDownloadDone(entry: ModelEntry, result: Result<File>) {
        result.fold(
            onSuccess = {
                Toast.makeText(this, getString(R.string.models_status_done, entry.label), Toast.LENGTH_SHORT).show()
            },
            onFailure = { e ->
                Toast.makeText(
                    this,
                    getString(R.string.models_error_download, e.message ?: "erro"),
                    Toast.LENGTH_LONG,
                ).show()
            },
        )
        refresh()
    }

    private fun deleteModel(entry: ModelEntry) {
        val ok = repository.delete(entry)
        if (!ok) {
            Toast.makeText(this, getString(R.string.models_error_delete), Toast.LENGTH_SHORT).show()
        }
        refresh()
    }

    // ------------------------------------------------------------ atualização --

    /** Redesenha estados (disco + cartões) a partir do disco. */
    private fun refresh() {
        diskSummary.text = getString(
            R.string.models_disk_free,
            ModelsCatalog.formatBytes(repository.freeDiskBytes().coerceAtLeast(0)),
            ModelsCatalog.formatBytes(repository.modelsDiskBytes()),
        )
        for (row in repository.snapshot()) {
            val card = cards[row.entry.id] ?: continue
            if (row.downloading) {
                card.download.isEnabled = false
                card.delete.isEnabled = false
                card.progress.visibility = View.VISIBLE
                card.status.text = getString(R.string.models_status_downloading, card.progress.progress)
                continue
            }
            card.progress.visibility = View.GONE
            card.progress.isIndeterminate = false
            card.download.isEnabled = !row.downloaded
            card.delete.isEnabled = row.downloaded
            card.status.text = if (row.downloaded) {
                getString(R.string.models_status_downloaded, ModelsCatalog.formatBytes(row.sizeOnDiskBytes))
            } else {
                getString(R.string.models_status_not_downloaded)
            }
        }
    }

    private fun kindLabel(kind: String): String = when (kind) {
        "stt" -> getString(R.string.models_kind_stt)
        "vad" -> getString(R.string.models_kind_vad)
        "tts" -> getString(R.string.models_kind_tts)
        else -> getString(R.string.models_kind_llm)
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private companion object {
        const val MATCH_PARENT = LinearLayout.LayoutParams.MATCH_PARENT
    }
}
