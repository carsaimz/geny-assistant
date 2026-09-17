package com.carsaimz.genyassistant.data

import android.content.Context
import androidx.room.ColumnInfo
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Entity
import androidx.room.Index
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

/** Registro de modelo baixado (docs §7.5) — API pública da fachada. */
data class ModelRecord(
    val id: Long,
    val kind: String,
    val name: String,
    val path: String,
    val sha256: String,
    val sizeBytes: Long,
    val downloadedAtMs: Long,
)

// ---------------------------------------------------------------- entities --

@Entity(tableName = "messages")
data class MessageEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val role: String,
    val content: String,
    @ColumnInfo(name = "at_ms") val atMs: Long,
)

@Entity(tableName = "tool_calls")
data class ToolCallEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(name = "tool_id") val toolId: String,
    val params: String,
    val status: String,
    @ColumnInfo(name = "at_ms") val atMs: Long,
)

@Entity(
    tableName = "models",
    indices = [Index(value = ["kind", "name"], unique = true)],
)
data class ModelEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val kind: String,
    val name: String,
    val path: String,
    val sha256: String,
    @ColumnInfo(name = "size_bytes") val sizeBytes: Long,
    @ColumnInfo(name = "downloaded_at_ms") val downloadedAtMs: Long,
)

@Entity(tableName = "facts")
data class FactEntity(
    @PrimaryKey val key: String,
    val value: String,
    @ColumnInfo(name = "updated_at_ms") val updatedAtMs: Long,
)

/** Projeção de leitura do histórico (evita carregar o id/at_ms à toa). */
data class RoleContent(val role: String, val content: String)

// -------------------------------------------------------------------- daos --

@Dao
interface MessageDao {
    @Insert
    fun insert(message: MessageEntity)

    @Query("SELECT role, content FROM messages ORDER BY id DESC LIMIT :limit")
    fun recent(limit: Int): List<RoleContent>

    @Query("DELETE FROM messages")
    fun clear()
}

@Dao
interface ToolCallDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun upsert(call: ToolCallEntity)
}

@Dao
interface ModelDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun upsert(model: ModelEntity)

    @Query("SELECT * FROM models WHERE kind = :kind ORDER BY name")
    fun listByKind(kind: String): List<ModelEntity>

    @Query("SELECT * FROM models ORDER BY name")
    fun listAll(): List<ModelEntity>

    @Query("DELETE FROM models WHERE path = :path")
    fun deleteByPath(path: String): Int
}

@Dao
interface FactDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun upsert(fact: FactEntity)

    @Query("SELECT value FROM facts WHERE key = :key")
    fun valueOf(key: String): String?

    @Query("SELECT * FROM facts ORDER BY key")
    fun listAll(): List<FactEntity>

    @Query("DELETE FROM facts WHERE `key` = :key")
    fun delete(key: String): Int

    @Query("DELETE FROM facts")
    fun clear(): Int
}

// --------------------------------------------------------------- database --

/**
 * Banco Room (docs §15, TODO android-04): conversas, chamadas de ferramentas,
 * modelos e fatos aprendidos — o mesmo schema do SQLiteOpenHelper v0, agora
 * validado pelo Room.
 *
 * Migração 1→2: recria `tool_calls`, `models` e `facts` no formato exato que
 * o Room espera (PK TEXT com NOT NULL, índice único nomeado em `models`).
 * `messages` já era compatível e não precisa de reconstrução. Os dados são
 * preservados na migração. Banco vetorial (sqlite-vec): Fase 5 (TODO core-08).
 */
@Database(
    entities = [MessageEntity::class, ToolCallEntity::class, ModelEntity::class, FactEntity::class],
    version = 2,
    exportSchema = false,
)
abstract class GenyDatabase : RoomDatabase() {

    abstract fun messages(): MessageDao
    abstract fun toolCalls(): ToolCallDao
    abstract fun models(): ModelDao
    abstract fun facts(): FactDao

    companion object {
        @Volatile
        private var instance: GenyDatabase? = null

        /** Singleton por processo — fachadas compartilham a mesma conexão. */
        fun get(context: Context): GenyDatabase =
            instance ?: synchronized(this) {
                instance ?: build(context.applicationContext).also { instance = it }
            }

        private fun build(context: Context): GenyDatabase =
            Room.databaseBuilder(context, GenyDatabase::class.java, "geny.db")
                .addMigrations(MIGRATION_1_2)
                .build()

        /**
         * Fecha e limpa a instância em cache. Uso exclusivo de testes JVM
         * (Robolectric), onde singletons sobrevivem entre métodos da mesma
         * classe e precisam ser recriados por teste.
         */
        internal fun resetForTests() {
            synchronized(this) {
                instance?.close()
                instance = null
            }
        }

        val MIGRATION_1_2: Migration = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                // tool_calls: PK TEXT passa a ser NOT NULL (formato Room).
                db.execSQL(
                    "CREATE TABLE tool_calls_new(" +
                        "id TEXT NOT NULL, tool_id TEXT NOT NULL, params TEXT NOT NULL, " +
                        "status TEXT NOT NULL, at_ms INTEGER NOT NULL, PRIMARY KEY(id))",
                )
                db.execSQL(
                    "INSERT INTO tool_calls_new(id, tool_id, params, status, at_ms) " +
                        "SELECT id, tool_id, params, status, at_ms FROM tool_calls",
                )
                db.execSQL("DROP TABLE tool_calls")
                db.execSQL("ALTER TABLE tool_calls_new RENAME TO tool_calls")

                // models: UNIQUE inline vira índice único nomeado do Room.
                db.execSQL(
                    "CREATE TABLE models_new(" +
                        "id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL, " +
                        "name TEXT NOT NULL, path TEXT NOT NULL, sha256 TEXT NOT NULL, " +
                        "size_bytes INTEGER NOT NULL, downloaded_at_ms INTEGER NOT NULL)",
                )
                db.execSQL(
                    "INSERT INTO models_new(id, kind, name, path, sha256, size_bytes, downloaded_at_ms) " +
                        "SELECT id, kind, name, path, sha256, size_bytes, downloaded_at_ms FROM models",
                )
                db.execSQL("DROP TABLE models")
                db.execSQL("ALTER TABLE models_new RENAME TO models")
                db.execSQL(
                    "CREATE UNIQUE INDEX IF NOT EXISTS index_models_kind_name " +
                        "ON models (kind, name)",
                )

                // facts: PK TEXT passa a ser NOT NULL (formato Room).
                db.execSQL(
                    "CREATE TABLE facts_new(" +
                        "key TEXT NOT NULL, value TEXT NOT NULL, " +
                        "updated_at_ms INTEGER NOT NULL, PRIMARY KEY(key))",
                )
                db.execSQL(
                    "INSERT INTO facts_new(key, value, updated_at_ms) " +
                        "SELECT key, value, updated_at_ms FROM facts",
                )
                db.execSQL("DROP TABLE facts")
                db.execSQL("ALTER TABLE facts_new RENAME TO facts")
            }
        }
    }
}

/**
 * Persistência (docs §15, TODO android-04): fachada do Room com a MESMA API
 * síncrona do SQLiteOpenHelper v0 — chamadores (GenyPlugin, ModelManager) não
 * mudam. As consultas rodam na thread do chamador (pool do Capacitor /
 * Dispatchers.IO), nunca na principal. Fase 5 expõe DAOs Flow/suspend para a
 * UI de memória (TODO android-08).
 */
class GenyDb(context: Context) {

    private val db = GenyDatabase.get(context)

    fun insertMessage(role: String, content: String, atMs: Long) {
        db.messages().insert(MessageEntity(role = role, content = content, atMs = atMs))
    }

    fun recentMessages(limit: Int): List<Pair<String, String>> =
        db.messages().recent(limit).map { it.role to it.content }.reversed()

    fun recordToolCall(callId: String, toolId: String, params: String, status: String, atMs: Long) {
        db.toolCalls().upsert(
            ToolCallEntity(id = callId, toolId = toolId, params = params, status = status, atMs = atMs),
        )
    }

    fun upsertModel(kind: String, name: String, path: String, sha256: String, sizeBytes: Long, atMs: Long) {
        db.models().upsert(
            ModelEntity(
                kind = kind, name = name, path = path,
                sha256 = sha256, sizeBytes = sizeBytes, downloadedAtMs = atMs,
            ),
        )
    }

    fun listModels(kind: String? = null): List<ModelRecord> {
        val rows = if (kind == null) db.models().listAll() else db.models().listByKind(kind)
        return rows.map {
            ModelRecord(
                id = it.id,
                kind = it.kind,
                name = it.name,
                path = it.path,
                sha256 = it.sha256,
                sizeBytes = it.sizeBytes,
                downloadedAtMs = it.downloadedAtMs,
            )
        }
    }

    fun deleteModelByPath(path: String) {
        db.models().deleteByPath(path)
    }

    fun rememberFact(key: String, value: String, atMs: Long) {
        db.facts().upsert(FactEntity(key = key, value = value, updatedAtMs = atMs))
    }

    fun recallFact(key: String): String? = db.facts().valueOf(key)
}
