package com.carsaimz.genyassistant.saf

import android.content.ContentResolver
import android.net.Uri
import android.provider.DocumentsContract
import org.json.JSONArray
import org.json.JSONObject

/**
 * Storage Access Framework — pastas autorizadas (TODO android-05, #40).
 *
 * O usuário autoriza pastas com ACTION_OPEN_DOCUMENT_TREE (permissão
 * persistida); todas as operações ficam DENTRO do escopo autorizado e são
 * auditadas pelo plugin. Nenhuma permissão ampla de armazenamento.
 */
object SafPaths {
    /** Limite de leitura por arquivo: 2 MiB (defesa contra arquivos enormes). */
    const val MAX_READ_BYTES: Int = 2 * 1024 * 1024

    /**
     * Divide um caminho relativo seguro ("sub/nota.txt") em segmentos.
     * Retorna null para caminhos inválidos: absolutos, com ".." ou "." —
     * nunca escapamos da pasta autorizada.
     */
    fun split(relativePath: String): List<String>? {
        val trimmed = relativePath.trim().trimStart('/').trimEnd('/')
        if (trimmed.isEmpty()) return emptyList()
        val parts = trimmed.split('/')
        if (parts.any { it.isEmpty() || it == "." || it == ".." }) return null
        return parts
    }

    /** MIME para criação: diretórios, texto comum e fallback binário. */
    fun mimeFor(fileName: String, isDir: Boolean): String {
        if (isDir) return DocumentsContract.Document.MIME_TYPE_DIR
        return when (fileName.substringAfterLast('.', "").lowercase()) {
            "txt", "md", "log", "csv" -> "text/plain"
            "json" -> "application/json"
            "xml", "html" -> "text/plain"
            "png" -> "image/png"
            "jpg", "jpeg" -> "image/jpeg"
            "pdf" -> "application/pdf"
            else -> "application/octet-stream"
        }
    }
}

/**
 * Lista de pastas autorizadas, persistida nos fatos do GenyDb (JSON array de
 * tree URIs). Sobrevive a reinícios junto com as permissões persistidas.
 */
class SafStore(private val db: com.carsaimz.genyassistant.data.GenyDb) {
    private fun read(): MutableList<String> {
        val raw = db.recallFact(KEY) ?: return mutableListOf()
        return try {
            val arr = JSONArray(raw)
            MutableList(arr.length()) { i -> arr.getString(i) }
        } catch (_: Exception) {
            mutableListOf()
        }
    }

    @Synchronized
    fun list(): List<String> = read()

    @Synchronized
    fun add(treeUri: String): Boolean {
        val items = read()
        if (treeUri in items) return true
        items.add(treeUri)
        persist(items)
        return true
    }

    @Synchronized
    fun remove(treeUri: String): Boolean {
        val items = read()
        val changed = items.remove(treeUri)
        if (changed) persist(items)
        return changed
    }

    private fun persist(items: List<String>) {
        db.rememberFact(KEY, JSONArray(items).toString(), System.currentTimeMillis())
    }

    companion object {
        const val KEY = "saf.folders"
    }
}

/**
 * Operações SAF sobre o ContentResolver. Cada função devolve resultado JSON
 * no envelope { ok, error?/data } usado pelo plugin; todas resolvem caminhos
 * RELATIVOS à pasta autorizada (nunca fora dela).
 */
object SafOps {
    /** Documento raiz da pasta autorizada. */
    fun rootDocumentUri(treeUri: Uri): Uri =
        DocumentsContract.buildDocumentUriUsingTree(
            treeUri,
            DocumentsContract.getTreeDocumentId(treeUri),
        )

    /**
     * Resolve um caminho relativo (ex. "notas/2026/plano.txt") para o Uri de
     * documento, caminhando pela árvore de filhos. Retorna null se algum
     * segmento não existir.
     */
    fun resolve(resolver: ContentResolver, treeUri: Uri, relativePath: String): Uri? {
        val parts = SafPaths.split(relativePath) ?: return null
        var docId: String = DocumentsContract.getTreeDocumentId(treeUri)
        for (part in parts) {
            val childDocId = findChild(resolver, treeUri, docId, part) ?: return null
            docId = childDocId
        }
        return DocumentsContract.buildDocumentUriUsingTree(treeUri, docId)
    }

    /** Procura o filho por nome de exibição e devolve o documentId. */
    private fun findChild(
        resolver: ContentResolver,
        treeUri: Uri,
        parentDocId: String,
        displayName: String,
    ): String? {
        val childrenUri =
            DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, parentDocId)
        val projection =
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            )
        resolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            while (cursor.moveToNext()) {
                val name = cursor.getString(1)
                if (name == displayName) return cursor.getString(0)
            }
        }
        return null
    }

    /** Lista os filhos de um caminho relativo como array JSON. */
    fun list(resolver: ContentResolver, treeUri: Uri, relativePath: String): JSONObject {
        val parent =
            resolve(resolver, treeUri, relativePath)
                ?: return errorJson("caminho nao encontrado: $relativePath")
        val parentDocId = DocumentsContract.getDocumentId(parent)
        val childrenUri =
            DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, parentDocId)
        val projection =
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
                DocumentsContract.Document.COLUMN_SIZE,
                DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            )
        val items = JSONArray()
        resolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            while (cursor.moveToNext()) {
                val mime = cursor.getString(2) ?: ""
                val isDir = mime == DocumentsContract.Document.MIME_TYPE_DIR
                items.put(
                    JSONObject()
                        .put("name", cursor.getString(1))
                        .put("dir", isDir)
                        .put("size", if (isDir) 0 else cursor.getLong(3))
                        .put("modifiedMs", cursor.getLong(4))
                        .put(
                            "path",
                            if (relativePath.isBlank()) cursor.getString(1)
                            else "$relativePath/${cursor.getString(1)}",
                        ),
                )
            }
        } ?: return errorJson("provedor nao respondeu a listagem")
        return JSONObject().put("ok", true).put("items", items)
    }

    /** Lê um arquivo de texto (limite SafPaths.MAX_READ_BYTES). */
    fun readText(resolver: ContentResolver, treeUri: Uri, relativePath: String): JSONObject {
        val target =
            resolve(resolver, treeUri, relativePath)
                ?: return errorJson("arquivo nao encontrado: $relativePath")
        return try {
            resolver.openInputStream(target)?.use { input ->
                val bytes = input.readBytes()
                if (bytes.size > SafPaths.MAX_READ_BYTES) {
                    return errorJson("arquivo maior que o limite de ${SafPaths.MAX_READ_BYTES} bytes")
                }
                JSONObject().put("ok", true).put("content", String(bytes))
            } ?: errorJson("provedor nao abriu o arquivo")
        } catch (e: Exception) {
            errorJson("leitura falhou: ${e.message}")
        }
    }

    /**
     * Escreve texto num arquivo (cria se não existir, via createDocument).
     * `append = true` concatena ao conteúdo existente (SAF não tem modo
     * append nativo — lê, concatena e reescreve).
     */
    fun writeText(
        resolver: ContentResolver,
        treeUri: Uri,
        relativePath: String,
        content: String,
        append: Boolean,
    ): JSONObject {
        val parts = SafPaths.split(relativePath)
            ?: return errorJson("caminho invalido: $relativePath")
        if (parts.isEmpty()) return errorJson("caminho invalido: nome de arquivo ausente")
        val fileName = parts.last()
        val dirPath = parts.dropLast(1).joinToString("/")

        val dirUri =
            resolve(resolver, treeUri, dirPath)
                ?: return errorJson("pasta pai nao encontrada: $dirPath")

        val existing = resolve(resolver, treeUri, relativePath)
        val target: Uri
        val created: Boolean
        if (existing != null) {
            target = existing
            created = false
        } else {
            target =
                try {
                    DocumentsContract.createDocument(
                        resolver,
                        dirUri,
                        SafPaths.mimeFor(fileName, isDir = false),
                        fileName,
                    ) ?: return errorJson("criacao do arquivo falhou")
                } catch (e: Exception) {
                    return errorJson("criacao falhou: ${e.message}")
                }
            created = true
        }

        return try {
            val wrote =
                if (append && !created) {
                    val current =
                        resolver.openInputStream(target)?.use {
                            it.readBytes().decodeToString()
                        } ?: ""
                    if (current.length + content.length > SafPaths.MAX_READ_BYTES * 4) {
                        return errorJson("conteudo resultante excede o limite")
                    }
                    writeAndClose(resolver, target, current + content)
                } else {
                    writeAndClose(resolver, target, content)
                }
            if (wrote) {
                JSONObject().put("ok", true).put("created", created)
            } else {
                errorJson("escrita falhou")
            }
        } catch (e: Exception) {
            errorJson("escrita falhou: ${e.message}")
        }
    }

    private fun writeAndClose(resolver: ContentResolver, uri: Uri, content: String): Boolean {
        return resolver.openOutputStream(uri, "wt")?.use { out ->
            out.write(content.toByteArray())
            true
        } ?: false
    }

    /** Cria um diretório dentro da pasta autorizada. */
    fun mkdir(resolver: ContentResolver, treeUri: Uri, relativePath: String): JSONObject {
        val parts =
            SafPaths.split(relativePath)
                ?: return errorJson("caminho invalido: $relativePath")
        val name = parts.lastOrNull()
            ?: return errorJson("nome de pasta ausente")
        val dirPath = parts.dropLast(1).joinToString("/")
        val parent =
            resolve(resolver, treeUri, dirPath)
                ?: return errorJson("pasta pai nao encontrada: $dirPath")
        return try {
            val created =
                DocumentsContract.createDocument(
                    resolver,
                    parent,
                    DocumentsContract.Document.MIME_TYPE_DIR,
                    name,
                )
            if (created != null) {
                JSONObject().put("ok", true)
            } else {
                errorJson("criacao da pasta falhou")
            }
        } catch (e: Exception) {
            errorJson("criacao da pasta falhou: ${e.message}")
        }
    }

    /** Apaga um arquivo/pasta vazio pelo caminho relativo. */
    fun delete(resolver: ContentResolver, treeUri: Uri, relativePath: String): JSONObject {
        val target =
            resolve(resolver, treeUri, relativePath)
                ?: return errorJson("arquivo nao encontrado: $relativePath")
        return try {
            val deleted = DocumentsContract.deleteDocument(resolver, target)
            if (deleted) {
                JSONObject().put("ok", true)
            } else {
                errorJson("provedor recusou a exclusao")
            }
        } catch (e: Exception) {
            errorJson("exclusao falhou: ${e.message}")
        }
    }

    private fun errorJson(message: String): JSONObject =
        JSONObject().put("ok", false).put("error", message)
}
