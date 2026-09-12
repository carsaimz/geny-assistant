package com.carsaimz.genyassistant.tools

import android.content.Intent
import android.net.Uri
import org.json.JSONArray
import org.json.JSONObject

/** Ferramentas de aplicativos (docs §9.1): listar, abrir. */
class AppTools : Tool(
    id = "apps.open",
    name = "Abrir aplicativo",
    description = "Abre um aplicativo pelo nome ou nome de pacote.",
    params = listOf(ParamSpec("app", "string", required = true, description = "nome do app ou pacote")),
    confirmation = ConfirmationLevel.NONE,
    context = ToolContext.APP,
) {
    override fun execute(params: JSONObject, host: ToolHost): JSONObject {
        val query = params.getString("app").trim().lowercase()
        val pm = host.appContext().packageManager
        val matches = pm.getInstalledPackages(0)
            .filter { pkg ->
                pkg.applicationInfo?.loadLabel(pm)?.toString()?.lowercase()?.contains(query) == true ||
                    pkg.packageName.lowercase().contains(query)
            }
        if (matches.isEmpty()) {
            throw IllegalArgumentException("aplicativo nao encontrado: $query")
        }
        val target = matches.first()
        val intent = pm.getLaunchIntentForPackage(target.packageName)
            ?: throw IllegalStateException("sem activity de lancamento: ${target.packageName}")
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        host.appContext().startActivity(intent)
        return JSONObject()
            .put("opened", target.packageName)
            .put("label", target.applicationInfo?.loadLabel(pm)?.toString() ?: target.packageName)
    }

    companion object {
        /** Ferramenta separada para listagem (id próprio no catálogo). */
        fun listTool(): Tool = object : Tool(
            id = "apps.list",
            name = "Listar aplicativos",
            description = "Lista aplicativos instalados com filtro opcional.",
            params = listOf(ParamSpec("query", "string", required = false, description = "filtro pelo nome")),
            confirmation = ConfirmationLevel.NONE,
            context = ToolContext.APP,
        ) {
            override fun execute(params: JSONObject, host: ToolHost): JSONObject {
                val query = if (params.has("query") && !params.isNull("query")) {
                    params.getString("query").lowercase()
                } else {
                    ""
                }
                val pm = host.appContext().packageManager
                val apps = pm.getInstalledPackages(0)
                    .filter { pkg ->
                        query.isEmpty() ||
                            pkg.applicationInfo?.loadLabel(pm)?.toString()?.lowercase()?.contains(query) == true
                    }
                    .take(50)
                    .map { pkg ->
                        JSONObject()
                            .put("package", pkg.packageName)
                            .put(
                                "label",
                                pkg.applicationInfo?.loadLabel(pm)?.toString() ?: pkg.packageName,
                            )
                            .put("version", pkg.versionName ?: "")
                    }
                return JSONObject().put("apps", JSONArray(apps)).put("count", apps.size)
            }
        }
    }
}

/** Pesquisa web via navegador padrão (docs §9.7). */
class WebSearchTool : Tool(
    id = "web.search",
    name = "Pesquisar na web",
    description = "Abre o navegador padrao com os termos da pesquisa.",
    params = listOf(ParamSpec("query", "string", required = true, description = "termos da pesquisa")),
    confirmation = ConfirmationLevel.NONE,
    context = ToolContext.APP,
) {
    override fun execute(params: JSONObject, host: ToolHost): JSONObject {
        val query = params.getString("query")
        val uri = Uri.parse("https://duckduckgo.com/?q=" + Uri.encode(query))
        val intent = Intent(Intent.ACTION_VIEW, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        host.appContext().startActivity(intent)
        return JSONObject().put("opened", "browser").put("query", query)
    }
}
