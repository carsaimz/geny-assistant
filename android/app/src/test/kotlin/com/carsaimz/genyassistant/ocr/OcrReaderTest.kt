package com.carsaimz.genyassistant.ocr

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Testes JVM do OCR (TODO android-06, #41) com Robolectric: códigos de
 * resultado estáveis e envelopes de erro para URIs inválidas/ilegíveis
 * (o motor ML Kit em si só roda no dispositivo — JNI + modelo).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class OcrReaderTest {

    private val context: Context = ApplicationProvider.getApplicationContext()

    @Test
    fun codigos_de_resultado_sao_estaveis_para_o_contrato_da_ponte() {
        assertEquals("ok", OcrReader.OK)
        assertEquals("uri_invalida", OcrReader.INVALID_URI)
        assertEquals("falha_ao_carregar", OcrReader.LOAD_FAILED)
        assertEquals("tempo_esgotado", OcrReader.TIMEOUT)
        assertEquals("falha_do_motor", OcrReader.ENGINE_FAILED)
        assertEquals(30L, OcrReader.TIMEOUT_SECONDS)
    }

    @Test
    fun uri_vazia_ou_sem_esquema_devolve_envelope_de_erro() {
        val empty = OcrReader.read(context, "")
        assertFalse(empty.optBoolean("ok"))
        assertEquals(OcrReader.INVALID_URI, empty.optString("code"))

        val noScheme = OcrReader.read(context, "   ")
        assertFalse(noScheme.optBoolean("ok"))
        assertEquals(OcrReader.INVALID_URI, noScheme.optString("code"))

        val relative = OcrReader.read(context, "sem-esquema.png")
        assertFalse(relative.optBoolean("ok"))
        assertEquals(OcrReader.INVALID_URI, relative.optString("code"))
    }

    @Test
    fun uri_ilegivel_devolve_falha_de_carregamento() {
        // content:// inexistente: o ContentResolver não abre stream → envelope
        val result: JSONObject =
            OcrReader.read(context, "content://org.exemplo.inexistente/img.png")
        assertFalse(result.optBoolean("ok"))
        val code = result.optString("code")
        assertEquals(OcrReader.LOAD_FAILED, code)
        assertTrue(result.optString("error").isNotEmpty())
    }
}
