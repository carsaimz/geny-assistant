package com.carsaimz.genyassistant.tools

import org.json.JSONObject

/**
 * OCR local (TODO android-06, #41): extração de texto de imagens e
 * screenshots 100% on-device via ML Kit v2 (bundle Latin). A imagem é
 * aberta por `content://` — o escopo vem do próprio Uri autorizado
 * (seletor do sistema ou SAF), sem permissões amplas de armazenamento.
 * Nível SIMPLE: leitura local e reversível.
 */
class OcrReadTool : Tool(
    id = "ocr.read",
    name = "Ler texto de imagem (OCR)",
    description = "Extrai texto de uma imagem ou screenshot 100% no dispositivo (ML Kit).",
    params = listOf(
        ParamSpec(
            "imageUri",
            "string",
            required = true,
            description = "uri de conteúdo da imagem (content://) do seletor ou pasta autorizada",
        ),
    ),
    confirmation = ConfirmationLevel.SIMPLE,
    context = ToolContext.APP,
) {
    override fun execute(params: JSONObject, host: ToolHost): JSONObject {
        val imageUri = params.getString("imageUri")
        return com.carsaimz.genyassistant.ocr.OcrReader.read(host.appContext(), imageUri)
    }
}
