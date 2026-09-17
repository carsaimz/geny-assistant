package com.carsaimz.genyassistant.data

import android.content.Context
import com.carsaimz.genyassistant.ai.CoreBridge
import org.json.JSONArray
import org.json.JSONObject
import uniffi.geny_core.GenyMemory

/**
 * Memória de longo prazo no aparelho (TODO android-08, Fase 5).
 *
 * **PT** Fonte de verdade dos fatos: o Room (`facts`); o índice semântico
 * vive no núcleo Rust via UniFFI ([CoreBridge.memoryOpen]) e é reconstruído
 * a partir do Room na inicialização e sincronizado a cada escrita. Sem o
 * core (builds de dev/testes JVM), tudo degrada com graça: busca vira
 * substring no Room, retenção segue o espelho Kotlin puro em
 * [RetentionLogic]. A política de retenção é persistida em
 * `SharedPreferences("geny_memory")` — 0 significa "sem limite".
 * **EN** Source of truth for facts: Room (`facts`); the semantic index lives
 * in the Rust core via UniFFI ([CoreBridge.memoryOpen]) and is rebuilt from
 * Room on startup and synced on every write. Without the core (dev builds/
 * JVM tests), everything degrades gracefully: search becomes substring over
 * Room, retention follows the pure Kotlin mirror in [RetentionLogic]. The
 * retention policy is persisted in `SharedPreferences("geny_memory")` —
 * 0 means "no limit".
 */
class MemoryManager private constructor(context: Context) {

    private val db = GenyDatabase.get(context.applicationContext)
    private val prefs =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val core: GenyMemory? = CoreBridge.memoryOpen()

    /** true quando o índice semântico do núcleo está disponível. */
    val semanticAvailable: Boolean = core != null

    init {
        // Reconstrói o índice vetorial a partir da fonte de verdade (Room).
        core?.apply {
            setRetention(0u, 0uL, 0uL) // retenção é decisão do Kotlin/Room, não do handle
            for (f in db.facts().listAll()) {
                if (!isInternal(f.key)) remember(f.key, f.value, emptyList())
            }
        }
    }

    // ------------------------------------------------------------- leitura --

    /**
     * Chaves internas (flags de serviço como `wakeword.*`) não aparecem na
     * memória do usuário — são estado de infraestrutura, não fatos aprendidos.
     */
    private fun isInternal(key: String): Boolean = key.startsWith("wakeword.")

    /** Todos os fatos visíveis ao usuário, ordenados pela chave. */
    fun facts(): List<FactEntity> = db.facts().listAll().filter { !isInternal(it.key) }

    /** Valor de um fato; null se ausente. */
    fun valueOf(key: String): String? = db.facts().valueOf(key)

    /** Quantidade de fatos armazenados (visíveis ao usuário). */
    fun count(): Int = facts().size

    /**
     * Busca top-k: semântica (cosseno, via core) quando disponível; senão
     * substring no Room. Cada hit traz `score` (cosseno; 0.0 no fallback).
     */
    fun search(query: String, limit: Int = 5): List<MemorySearchHit> {
        val trimmed = query.trim()
        if (trimmed.isEmpty()) return emptyList()
        val handle = core
        if (handle != null) {
            val hits = handle.searchSemantic(trimmed, limit.toUInt().coerceAtLeast(1u))
            return hits.filter { !isInternal(it.key) }.map { MemorySearchHit(it.key, it.value, it.score) }
        }
        val q = trimmed.lowercase()
        return db.facts()
            .listAll()
            .filter { !isInternal(it.key) }
            .filter { it.key.lowercase().contains(q) || it.value.lowercase().contains(q) }
            .take(limit)
            .map { MemorySearchHit(it.key, it.value, 0.0) }
    }

    // -------------------------------------------------------------- escrita --

    /** Registra (ou atualiza) um fato. Retorna chaves esquecidas pela retenção. */
    fun remember(key: String, value: String, atMs: Long): List<String> {
        db.facts().upsert(FactEntity(key = key, value = value, updatedAtMs = atMs))
        core?.remember(key, value, emptyList())
        return applyRetention(atMs)
    }

    /** Apaga um fato; true se existia. */
    fun delete(key: String): Boolean {
        val removed = db.facts().delete(key) > 0
        if (removed) core?.forget(key)
        return removed
    }

    /** Apaga TODOS os fatos; retorna quantos foram removidos. */
    fun clear(): Int {
        val removed = db.facts().clear()
        core?.clear()
        return removed
    }

    /** Sincroniza o índice do core após operações em lote (import). */
    fun rebuildCoreIndex() {
        val handle = core ?: return
        handle.clear()
        for (f in db.facts().listAll()) {
            if (!isInternal(f.key)) handle.remember(f.key, f.value, emptyList())
        }
    }

    // ----------------------------------------------------------- retenção --

    /** Política atual (0 = sem limite). */
    fun retention(): RetentionSpec = RetentionSpec(
        maxFacts = prefs.getInt(KEY_MAX_FACTS, 0),
        maxAgeDays = prefs.getLong(KEY_MAX_AGE_DAYS, 0L),
        maxValueBytes = prefs.getLong(KEY_MAX_VALUE_BYTES, 0L),
    )

    /** Define a política e aplica imediatamente; retorna chaves esquecidas. */
    fun setRetention(spec: RetentionSpec, nowMs: Long): List<String> {
        prefs.edit()
            .putInt(KEY_MAX_FACTS, spec.maxFacts)
            .putLong(KEY_MAX_AGE_DAYS, spec.maxAgeDays)
            .putLong(KEY_MAX_VALUE_BYTES, spec.maxValueBytes)
            .apply()
        return applyRetention(nowMs)
    }

    /** Aplica a política agora (espelho Kotlin; indiferente ao core). */
    fun applyRetention(nowMs: Long): List<String> {
        val spec = retention()
        if (!spec.isActive()) return emptyList()
        val forgotten = RetentionLogic.apply(facts(), spec, nowMs)
        for (key in forgotten) {
            db.facts().delete(key)
            core?.forget(key)
        }
        return forgotten
    }

    // -------------------------------------------------- envelope (app-04) --

    /**
     * Exporta a memória como envelope JSON v1 — o MESMO formato do core
     * (`GenyMemory.exportJson`): version, exported_at_ms, retention, facts.
     * Tags ficam vazias no Android (a UI de fatos não as expõe).
     */
    fun exportEnvelopeJson(nowMs: Long): String {
        val spec = retention()
        val envelope = JSONObject()
        envelope.put("version", 1)
        envelope.put("exported_at_ms", nowMs)
        val retention = JSONObject()
        spec.maxFacts.takeIf { it > 0 }?.let { retention.put("max_facts", it) }
        spec.maxAgeDays.takeIf { it > 0 }?.let { retention.put("max_age_days", it) }
        spec.maxValueBytes.takeIf { it > 0 }?.let { retention.put("max_value_bytes", it) }
        if (retention.length() > 0) envelope.put("retention", retention)
        val facts = JSONArray()
        for (f in facts()) {
            facts.put(
                JSONObject()
                    .put("key", f.key)
                    .put("value", f.value)
                    .put("tags", JSONArray())
                    .put("updated_at_ms", f.updatedAtMs),
            )
        }
        envelope.put("facts", facts)
        return envelope.toString()
    }

    /**
     * Importa um envelope v1 (ou o array legado v0), SUBSTITUINDO a memória
     * atual. Retorna a quantidade de fatos importados.
     */
    fun importEnvelopeJson(json: String): Int {
        val trimmed = json.trim()
        require(trimmed.startsWith("{") || trimmed.startsWith("[")) {
            "envelope deve ser objeto v1 ou array legado"
        }
        val incoming: List<FactEntity> = if (trimmed.startsWith("[")) {
            parseFacts(JSONArray(trimmed))
        } else {
            val obj = JSONObject(trimmed)
            parseFacts(obj.optJSONArray("facts") ?: JSONArray())
        }
        db.facts().clear()
        for (f in incoming) {
            db.facts().upsert(f)
        }
        rebuildCoreIndex()
        return incoming.size
    }

    private fun parseFacts(array: JSONArray): List<FactEntity> {
        val out = ArrayList<FactEntity>(array.length())
        for (i in 0 until array.length()) {
            val f = array.getJSONObject(i)
            out.add(
                FactEntity(
                    key = f.getString("key"),
                    value = f.getString("value"),
                    updatedAtMs = f.optLong("updated_at_ms", 0L),
                ),
            )
        }
        return out
    }

    companion object {
        private const val PREFS = "geny_memory"
        private const val KEY_MAX_FACTS = "retention.max_facts"
        private const val KEY_MAX_AGE_DAYS = "retention.max_age_days"
        private const val KEY_MAX_VALUE_BYTES = "retention.max_value_bytes"

        @Volatile
        private var instance: MemoryManager? = null

        /** Singleton por processo — Room e índice do core compartilhados. */
        fun get(context: Context): MemoryManager =
            instance ?: synchronized(this) {
                instance ?: MemoryManager(context).also { instance = it }
            }

        /** Só para testes JVM: descarta o singleton. */
        internal fun resetForTests() {
            synchronized(this) {
                instance?.core?.close()
                instance = null
            }
        }
    }
}

/** Hit de busca de memória para a ponte e a UI nativa. */
data class MemorySearchHit(
    val key: String,
    val value: String,
    val score: Double,
)

/** Política de retenção no aparelho (0 = sem limite naquela dimensão). */
data class RetentionSpec(
    val maxFacts: Int,
    val maxAgeDays: Long,
    val maxValueBytes: Long,
) {
    fun isActive(): Boolean = maxFacts > 0 || maxAgeDays > 0 || maxValueBytes > 0
}

/**
 * Espelho Kotlin puro da política de retenção do core (retention.rs) —
 * JVM-testável e independente do core. Mesma semântica: idade máxima,
 * tamanho por valor e limite de quantidade (os mais antigos saem primeiro,
 * chave como desempate).
 */
object RetentionLogic {

    private const val MS_PER_DAY = 86_400_000L

    /** Retorna as chaves que devem ser esquecidas (ordem determinística). */
    fun apply(facts: List<FactEntity>, spec: RetentionSpec, nowMs: Long): List<String> {
        val forgotten = LinkedHashSet<String>()
        if (!spec.isActive()) return emptyList()

        if (spec.maxAgeDays > 0) {
            val cutoff = nowMs - Math.multiplyExact(spec.maxAgeDays, MS_PER_DAY)
            for (f in facts) {
                if (f.updatedAtMs < cutoff) forgotten.add(f.key)
            }
        }

        if (spec.maxValueBytes > 0) {
            for (f in facts) {
                if (f.value.toByteArray(Charsets.UTF_8).size > spec.maxValueBytes) {
                    forgotten.add(f.key)
                }
            }
        }

        if (spec.maxFacts > 0) {
            val remaining = facts.filter { it.key !in forgotten }
            if (remaining.size > spec.maxFacts) {
                val byAge = remaining
                    .sortedWith(compareBy({ it.updatedAtMs }, { it.key }))
                for (f in byAge.take(remaining.size - spec.maxFacts)) {
                    forgotten.add(f.key)
                }
            }
        }

        return forgotten.toList()
    }
}
