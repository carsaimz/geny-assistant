package com.carsaimz.genyassistant.data

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/** Registro de modelo baixado (docs §7.5). */
data class ModelRecord(
    val id: Long,
    val kind: String,
    val name: String,
    val path: String,
    val sha256: String,
    val sizeBytes: Long,
    val downloadedAtMs: Long,
)

/**
 * Persistência v0 (docs §15): SQLiteOpenHelper com tabelas de conversas,
 * chamadas de ferramentas, modelos e fatos aprendidos.
 *
 * Migração para Room + banco vetorial: Fase 5 (ver TODO android-04/android-12).
 */
class GenyDb(context: Context) : SQLiteOpenHelper(context, DB_NAME, null, DB_VERSION) {

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            "CREATE TABLE messages(" +
                "id INTEGER PRIMARY KEY AUTOINCREMENT, role TEXT NOT NULL, " +
                "content TEXT NOT NULL, at_ms INTEGER NOT NULL)",
        )
        db.execSQL(
            "CREATE TABLE tool_calls(" +
                "id TEXT PRIMARY KEY, tool_id TEXT NOT NULL, params TEXT NOT NULL, " +
                "status TEXT NOT NULL, at_ms INTEGER NOT NULL)",
        )
        db.execSQL(
            "CREATE TABLE models(" +
                "id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL, name TEXT NOT NULL, " +
                "path TEXT NOT NULL, sha256 TEXT NOT NULL, size_bytes INTEGER NOT NULL, " +
                "downloaded_at_ms INTEGER NOT NULL, UNIQUE(kind, name))",
        )
        db.execSQL(
            "CREATE TABLE facts(" +
                "key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at_ms INTEGER NOT NULL)",
        )
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // v0: sem upgrades ainda; migrações incrementais a partir da v2.
    }

    fun insertMessage(role: String, content: String, atMs: Long) {
        val values = ContentValues().apply {
            put("role", role)
            put("content", content)
            put("at_ms", atMs)
        }
        writableDatabase.insert("messages", null, values)
    }

    fun recentMessages(limit: Int): List<Pair<String, String>> {
        val out = mutableListOf<Pair<String, String>>()
        readableDatabase.rawQuery(
            "SELECT role, content FROM messages ORDER BY id DESC LIMIT ?",
            arrayOf(limit.toString()),
        ).use { cursor ->
            while (cursor.moveToNext()) {
                out.add(cursor.getString(0) to cursor.getString(1))
            }
        }
        return out.reversed()
    }

    fun recordToolCall(callId: String, toolId: String, params: String, status: String, atMs: Long) {
        val values = ContentValues().apply {
            put("id", callId)
            put("tool_id", toolId)
            put("params", params)
            put("status", status)
            put("at_ms", atMs)
        }
        writableDatabase.insertWithOnConflict("tool_calls", null, values, SQLiteDatabase.CONFLICT_REPLACE)
    }

    fun upsertModel(kind: String, name: String, path: String, sha256: String, sizeBytes: Long, atMs: Long) {
        val values = ContentValues().apply {
            put("kind", kind)
            put("name", name)
            put("path", path)
            put("sha256", sha256)
            put("size_bytes", sizeBytes)
            put("downloaded_at_ms", atMs)
        }
        writableDatabase.insertWithOnConflict(
            "models", null, values, SQLiteDatabase.CONFLICT_REPLACE,
        )
    }

    fun listModels(kind: String? = null): List<ModelRecord> {
        val out = mutableListOf<ModelRecord>()
        val selection = if (kind == null) null else "kind = ?"
        val args = if (kind == null) null else arrayOf(kind)
        readableDatabase.query(
            "models", null, selection, args, null, null, "name",
        ).use { cursor ->
            while (cursor.moveToNext()) {
                out.add(
                    ModelRecord(
                        id = cursor.getLong(0),
                        kind = cursor.getString(1),
                        name = cursor.getString(2),
                        path = cursor.getString(3),
                        sha256 = cursor.getString(4),
                        sizeBytes = cursor.getLong(5),
                        downloadedAtMs = cursor.getLong(6),
                    ),
                )
            }
        }
        return out
    }

    fun rememberFact(key: String, value: String, atMs: Long) {
        val values = ContentValues().apply {
            put("key", key)
            put("value", value)
            put("updated_at_ms", atMs)
        }
        writableDatabase.insertWithOnConflict("facts", null, values, SQLiteDatabase.CONFLICT_REPLACE)
    }

    fun recallFact(key: String): String? {
        readableDatabase.rawQuery(
            "SELECT value FROM facts WHERE key = ?", arrayOf(key),
        ).use { cursor ->
            if (cursor.moveToFirst()) return cursor.getString(0)
        }
        return null
    }

    private companion object {
        const val DB_NAME = "geny.db"
        const val DB_VERSION = 1
    }
}
