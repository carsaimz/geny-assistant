package com.carsaimz.genyassistant.ocr

import android.content.Context
import android.net.Uri
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import org.json.JSONObject
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

/**
 * OCR 100% on-device (TODO android-06, #41) via ML Kit v2 (bundle Latin —
 * pt/en/es/fr/de/it). Nenhum dado sai do dispositivo: a imagem é aberta do
 * `content://` local e processada pelo motor embutido no APK.
 *
 * Roda em thread de fundo (toolExecutor da ponte) usando Tasks.await com
 * limite de tempo. Os códigos de resultado são estáveis para o envelope
 * JSON do tool `ocr.read`.
 */
object OcrReader {
    /** Limite de tempo do reconhecimento por imagem. */
    val TIMEOUT_SECONDS: Long = 30

    const val OK = "ok"
    const val INVALID_URI = "uri_invalida"
    const val LOAD_FAILED = "falha_ao_carregar"
    const val TIMEOUT = "tempo_esgotado"
    const val ENGINE_FAILED = "falha_do_motor"

    /** Extrai texto de uma imagem local; devolve envelope { ok, ... }. */
    fun read(context: Context, imageUri: String): JSONObject {
        val trimmed = imageUri.trim()
        if (trimmed.isEmpty()) {
            return errorEnvelope(INVALID_URI, "imageUri ausente")
        }
        val uri = Uri.parse(trimmed)
        if (uri.scheme.isNullOrBlank()) {
            return errorEnvelope(INVALID_URI, "uri sem esquema: $trimmed")
        }
        val image =
            try {
                InputImage.fromFilePath(context, uri)
            } catch (e: Exception) {
                return errorEnvelope(LOAD_FAILED, "abertura da imagem falhou: ${e.message}")
            }

        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        return try {
            val text = Tasks.await(recognizer.process(image), TIMEOUT_SECONDS, TimeUnit.SECONDS)
            val blocks = text.textBlocks
            JSONObject()
                .put("ok", true)
                .put("code", OK)
                .put("text", text.text)
                .put("blocks", blocks.size)
                .put("lines", blocks.sumOf { block -> block.lines.size })
        } catch (e: TimeoutException) {
            errorEnvelope(TIMEOUT, "reconhecimento excedeu ${TIMEOUT_SECONDS}s")
        } catch (e: Exception) {
            errorEnvelope(ENGINE_FAILED, "motor de OCR falhou: ${e.message}")
        } finally {
            recognizer.close()
        }
    }

    private fun errorEnvelope(code: String, message: String): JSONObject =
        JSONObject()
            .put("ok", false)
            .put("code", code)
            .put("error", message)
}
