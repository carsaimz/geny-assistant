package com.carsaimz.genyassistant.tools

import android.content.Intent
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * Ferramentas de arquivos (docs §9.4) — v0 opera no diretório privado do app
 * (notas e arquivos do assistente). SAF com pastas autorizadas entra na Fase 4.
 */
class NoteCreateTool : Tool(
    id = "notes.create",
    name = "Criar nota",
    description = "Cria uma nota de texto local (reversivel).",
    params = listOf(
        ParamSpec("title", "string", required = true, description = "titulo da nota"),
        ParamSpec("body", "string", required = true, description = "conteudo da nota"),
    ),
    confirmation = ConfirmationLevel.SIMPLE,
    context = ToolContext.APP,
) {
    override fun execute(params: JSONObject, host: ToolHost): JSONObject {
        val title = sanitize(params.getString("title"))
        val body = params.getString("body")
        val dir = File(host.appContext().filesDir, "notes").apply { mkdirs() }
        val file = File(dir, "$title.md")
        file.writeText("# ${params.getString("title")}\n\n$body\n")
        host.audit("notes.create", "nota criada: ${file.name}")
        return JSONObject()
            .put("created", true)
            .put("file", file.name)
            .put("bytes", file.length())
    }

    private fun sanitize(name: String): String {
        val clean = name.trim().replace(Regex("[^A-Za-z0-9\\p{L}\\p{N} _-]"), "").ifEmpty { "nota" }
        return clean.take(60)
    }
}

class NoteListTool : Tool(
    id = "notes.list",
    name = "Listar notas",
    description = "Lista as notas locais do assistente.",
    confirmation = ConfirmationLevel.NONE,
    context = ToolContext.APP,
) {
    override fun execute(params: JSONObject, host: ToolHost): JSONObject {
        val dir = File(host.appContext().filesDir, "notes")
        val notes = dir.listFiles { f -> f.isFile && f.extension == "md" }
            ?.map { JSONObject().put("file", it.name).put("bytes", it.length()) }
            ?: emptyList()
        return JSONObject().put("notes", JSONArray(notes)).put("count", notes.size)
    }
}

class NoteReadTool : Tool(
    id = "notes.read",
    name = "Ler nota",
    description = "Le o conteudo de uma nota local.",
    params = listOf(ParamSpec("file", "string", required = true, description = "nome do arquivo da nota")),
    confirmation = ConfirmationLevel.NONE,
    context = ToolContext.APP,
) {
    override fun execute(params: JSONObject, host: ToolHost): JSONObject {
        val name = params.getString("file")
        require(name.matches(Regex("[A-Za-z0-9\\p{L}\\p{N} _-]+\\.md"))) {
            "nome de arquivo invalido"
        }
        val file = File(File(host.appContext().filesDir, "notes"), name)
        if (!file.exists()) throw IllegalArgumentException("nota nao encontrada: $name")
        return JSONObject().put("file", name).put("content", file.readText())
    }
}

class ShareTextTool : Tool(
    id = "share.text",
    name = "Compartilhar texto",
    description = "Abre o seletor de compartilhamento com um texto.",
    params = listOf(
        ParamSpec("text", "string", required = true, description = "texto a compartilhar"),
        ParamSpec("subject", "string", required = false, description = "assunto opcional"),
    ),
    confirmation = ConfirmationLevel.SIMPLE,
    context = ToolContext.APP,
) {
    override fun execute(params: JSONObject, host: ToolHost): JSONObject {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, params.getString("text"))
            if (params.has("subject") && !params.isNull("subject")) {
                putExtra(Intent.EXTRA_SUBJECT, params.getString("subject"))
            }
        }
        val chooser = Intent.createChooser(intent, null).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        host.appContext().startActivity(chooser)
        return JSONObject().put("shared", true)
    }
}
