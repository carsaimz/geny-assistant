package com.carsaimz.genyassistant.memory

import android.os.Bundle
import android.text.InputType
import android.view.View
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import com.carsaimz.genyassistant.R
import com.carsaimz.genyassistant.data.FactEntity
import com.carsaimz.genyassistant.data.MemoryManager
import com.carsaimz.genyassistant.data.MemorySearchHit
import com.carsaimz.genyassistant.data.RetentionSpec
import com.carsaimz.genyassistant.security.AuditLog
import com.google.android.material.button.MaterialButton
import com.google.android.material.card.MaterialCardView
import java.io.File
import java.text.DateFormat
import java.util.Date

/**
 * Tela nativa de Memória (TODO android-08, Fase 5) — fatos aprendidos.
 *
 * **PT** Lista dos fatos que a Geny aprendeu (Room), com busca semântica do
 * núcleo (fallback substring), adicionar, editar, apagar (confirmação) e
 * limpar tudo. A retenção (core-09) aparece como resumo editável — limite de
 * fatos/idade/tamanho, 0 = sem limite. UI montada por código (sem XML de
 * item), mesmo estilo da tela de Modelos: tema `Theme.Geny`, Material3.
 * **EN** Native list of facts Geny has learned (Room) with core semantic
 * search (substring fallback), add, edit, delete (with confirmation) and
 * clear all. Retention (core-09) shows as an editable summary — facts/age/
 * size limits, 0 = unlimited. Code-built UI (no item XML), same style as the
 * Models screen: `Theme.Geny` theme, Material3.
 */
class MemoryActivity : AppCompatActivity() {

    private lateinit var memory: MemoryManager
    private lateinit var summary: TextView
    private lateinit var searchInput: EditText
    private lateinit var listHost: LinearLayout
    private lateinit var audit: AuditLog

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        memory = MemoryManager.get(this)
        audit = AuditLog(File(filesDir, "audit"))
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
            text = getString(R.string.memory_title)
            textSize = 22f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        }
        root.addView(title)

        summary = TextView(this).apply {
            textSize = 13f
            setPadding(0, dp(4), 0, dp(8))
        }
        root.addView(summary)

        val addBtn = MaterialButton(this).apply {
            text = getString(R.string.memory_add)
            setOnClickListener { showEditDialog(null) }
        }
        root.addView(addBtn)

        val clearBtn = MaterialButton(this, null, com.google.android.material.R.attr.materialButtonOutlinedStyle).apply {
            text = getString(R.string.memory_clear)
            setOnClickListener { confirmClearAll() }
        }
        root.addView(clearBtn)

        val retentionBtn = MaterialButton(this, null, com.google.android.material.R.attr.materialButtonOutlinedStyle).apply {
            text = getString(R.string.memory_retention_edit)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = dp(8) }
            setOnClickListener { showRetentionDialog() }
        }
        root.addView(retentionBtn)

        searchInput = EditText(this).apply {
            hint = getString(R.string.memory_search_hint)
            inputType = InputType.TYPE_CLASS_TEXT
            setSingleLine(true)
            setPadding(dp(12), dp(12), dp(12), dp(12))
            addTextChangedListener(
                object : android.text.TextWatcher {
                    override fun beforeTextChanged(s: CharSequence?, a: Int, b: Int, c: Int) = Unit
                    override fun onTextChanged(s: CharSequence?, a: Int, b: Int, c: Int) = Unit
                    override fun afterTextChanged(s: android.text.Editable?) {
                        refresh(s?.toString().orEmpty())
                    }
                },
            )
        }
        root.addView(searchInput)

        val scroll = ScrollView(this).apply { isFillViewport = true }
        listHost = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        scroll.addView(listHost)
        root.addView(scroll, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f))

        return root
    }

    private fun refresh(query: String = "") {
        summary.text = getString(
            R.string.memory_summary,
            memory.count(),
            describeRetention(memory.retention()),
        )

        listHost.removeAllViews()
        val hits: List<MemorySearchHit> = if (query.isBlank()) {
            memory.facts().map { MemorySearchHit(it.key, it.value, Double.NaN) }
        } else {
            memory.search(query, limit = 20)
        }
        if (hits.isEmpty()) {
            listHost.addView(
                TextView(this).apply {
                    text = if (query.isBlank()) {
                        getString(R.string.memory_empty)
                    } else {
                        getString(R.string.memory_no_matches)
                    }
                    setPadding(0, dp(16), 0, dp(16))
                },
            )
            return
        }
        val byKey = memory.facts().associateBy({ it.key }, { it })
        for (hit in hits) {
            val fact = byKey[hit.key] ?: FactEntity(hit.key, hit.value, 0L)
            listHost.addView(factCard(fact, hit.score > 0.0))
        }
    }

    private fun factCard(fact: FactEntity, semantic: Boolean): View {
        val card = MaterialCardView(this).apply {
            radius = dp(12).toFloat()
            setContentPadding(dp(12), dp(10), dp(12), dp(10))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { bottomMargin = dp(8) }
        }
        val column = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        card.addView(column)

        column.addView(
            TextView(this).apply {
                text = if (semantic) "⭐ ${fact.key}" else fact.key
                textSize = 14f
                setTypeface(typeface, android.graphics.Typeface.BOLD)
            },
        )
        column.addView(
            TextView(this).apply {
                text = fact.value
                textSize = 14f
                setPadding(0, dp(2), 0, dp(2))
            },
        )
        column.addView(
            TextView(this).apply {
                text = DateFormat.getDateInstance(DateFormat.SHORT).format(Date(fact.updatedAtMs))
                textSize = 11f
                setPadding(0, dp(2), 0, dp(4))
            },
        )

        val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        val edit = MaterialButton(this, null, com.google.android.material.R.attr.materialButtonOutlinedStyle).apply {
            text = getString(R.string.memory_edit)
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            setOnClickListener { showEditDialog(fact) }
        }
        row.addView(edit)
        val del = MaterialButton(this, null, com.google.android.material.R.attr.materialButtonOutlinedStyle).apply {
            text = getString(R.string.memory_delete)
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            setOnClickListener { confirmDelete(fact) }
        }
        row.addView(del)
        column.addView(row)
        return card
    }

    // ------------------------------------------------------------- diálogos --

    private fun showEditDialog(existing: FactEntity?) {
        val host = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(8), dp(20), 0)
        }
        val keyInput = EditText(this).apply {
            hint = getString(R.string.memory_key)
            setSingleLine(true)
            setText(existing?.key.orEmpty())
            isEnabled = existing == null // chave é a PK: não edita
        }
        val valueInput = EditText(this).apply {
            hint = getString(R.string.memory_value)
            setText(existing?.value.orEmpty())
            minLines = 2
        }
        host.addView(keyInput)
        host.addView(valueInput)

        AlertDialog.Builder(this)
            .setTitle(if (existing == null) R.string.memory_add else R.string.memory_edit)
            .setView(host)
            .setPositiveButton(R.string.memory_save) { _, _ ->
                val key = keyInput.text.toString().trim()
                val value = valueInput.text.toString()
                if (key.isEmpty() || value.isEmpty()) {
                    toast(R.string.memory_error_empty)
                    return@setPositiveButton
                }
                memory.remember(key, value, System.currentTimeMillis())
                audit.log("memory", if (existing == null) "fato adicionado: $key" else "fato atualizado: $key")
                refresh(searchInput.text.toString())
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    private fun confirmDelete(fact: FactEntity) {
        AlertDialog.Builder(this)
            .setTitle(R.string.memory_delete)
            .setMessage(getString(R.string.memory_delete_confirm, fact.key))
            .setPositiveButton(R.string.memory_delete) { _, _ ->
                memory.delete(fact.key)
                audit.log("memory", "fato apagado: ${fact.key}")
                refresh(searchInput.text.toString())
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    private fun confirmClearAll() {
        AlertDialog.Builder(this)
            .setTitle(R.string.memory_clear)
            .setMessage(getString(R.string.memory_clear_confirm, memory.count()))
            .setPositiveButton(R.string.memory_clear) { _, _ ->
                val n = memory.clear()
                audit.log("memory", "$n fatos apagados em lote")
                refresh(searchInput.text.toString())
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    private fun showRetentionDialog() {
        val spec = memory.retention()
        val host = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(8), dp(20), 0)
        }
        val maxFacts = numberField(spec.maxFacts.toLong(), getString(R.string.memory_retention_max_facts))
        val maxAge = numberField(spec.maxAgeDays, getString(R.string.memory_retention_max_age))
        val maxBytes = numberField(spec.maxValueBytes, getString(R.string.memory_retention_max_bytes))
        host.addView(maxAge.first)
        host.addView(maxFacts.first)
        host.addView(maxBytes.first)
        AlertDialog.Builder(this)
            .setTitle(R.string.memory_retention_edit)
            .setView(host)
            .setPositiveButton(R.string.memory_save) { _, _ ->
                val newSpec = RetentionSpec(
                    maxFacts = maxFacts.second.text.toString().toLongOrNull()?.coerceAtLeast(0L)
                        ?.coerceAtMost(Int.MAX_VALUE.toLong())?.toInt() ?: 0,
                    maxAgeDays = maxAge.second.text.toString().toLongOrNull()?.coerceAtLeast(0L) ?: 0L,
                    maxValueBytes = maxBytes.second.text.toString().toLongOrNull()?.coerceAtLeast(0L) ?: 0L,
                )
                val forgotten = memory.setRetention(newSpec, System.currentTimeMillis())
                audit.log("memory", "retenção definida; ${forgotten.size} fato(s) esquecido(s)")
                toast(
                    if (forgotten.isEmpty()) R.string.memory_saved
                    else R.string.memory_retention_applied,
                )
                refresh(searchInput.text.toString())
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    /** Campo numérico rotulado: (rótulo, campo). */
    private fun numberField(initial: Long, label: String): Pair<TextView, EditText> {
        val labelView = TextView(this).apply {
            text = label
            textSize = 12f
            setPadding(0, dp(8), 0, dp(2))
        }
        val input = EditText(this).apply {
            setText(initial.toString())
            inputType = InputType.TYPE_CLASS_NUMBER
            setSingleLine(true)
        }
        return labelView to input
    }

    // ------------------------------------------------------------- helpers --

    private fun describeRetention(spec: RetentionSpec): String = buildString {
        if (!spec.isActive()) {
            append(getString(R.string.memory_retention_off))
        } else {
            val parts = mutableListOf<String>()
            if (spec.maxFacts > 0) parts.add(getString(R.string.memory_retention_facts, spec.maxFacts))
            if (spec.maxAgeDays > 0) parts.add(getString(R.string.memory_retention_age, spec.maxAgeDays))
            if (spec.maxValueBytes > 0) parts.add(getString(R.string.memory_retention_bytes, spec.maxValueBytes))
            append(parts.joinToString(" · "))
        }
    }

    private fun toast(res: Int) {
        Toast.makeText(this, res, Toast.LENGTH_SHORT).show()
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()
}
