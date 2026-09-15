package com.carsaimz.genyassistant.voice

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Testes JVM do catálogo Piper (TODO core-03): hashes pinados, URLs https,
 * assets de config e escolha de voz por idioma.
 */
class PiperCatalogTest {

    @Test
    fun vozesTemHashSha256Valido() {
        for (v in PiperVoiceCatalog.VOICES) {
            assertTrue("hash da voz ${v.id}", v.sha256.matches(Regex("[0-9a-f]{64}")))
        }
        assertTrue("hash do espeak-data", PiperVoiceCatalog.ESPEAK_DATA.sha256.matches(Regex("[0-9a-f]{64}")))
    }

    @Test
    fun vozesTemUrlHttpsEBytesPositivos() {
        for (v in PiperVoiceCatalog.VOICES) {
            assertTrue("url da voz ${v.id} deve ser https", v.url.startsWith("https://"))
            assertTrue("bytes da voz ${v.id}", v.bytes > 1_000_000L)
            assertTrue("fileName da voz ${v.id} deve ser .onnx", v.fileName.endsWith(".onnx"))
        }
        val data = PiperVoiceCatalog.ESPEAK_DATA
        assertTrue(data.url.startsWith("https://"))
        assertTrue(data.bytes > 1_000_000L)
        assertTrue(data.fileName.endsWith(".zip"))
    }

    @Test
    fun assetsDeConfigExistemParaTodasAsVozes() {
        // O asset é lido do APK em runtime; aqui validamos o contrato de nomes.
        for (v in PiperVoiceCatalog.VOICES) {
            assertTrue("asset da voz ${v.id} deve começar com piper/", v.jsonAsset.startsWith("piper/"))
            assertTrue(v.jsonAsset.endsWith(".json"))
        }
    }

    @Test
    fun buscaPorIdEFileName() {
        assertEquals(
            "piper-pt-br-faber-medium",
            PiperVoiceCatalog.voiceById("piper-pt-br-faber-medium")?.id,
        )
        assertNull(PiperVoiceCatalog.voiceById("voz-inexistente"))
        // busca case-insensitive pelo nome de arquivo
        assertEquals(
            "piper-en-us-amy-medium",
            PiperVoiceCatalog.voiceByFileName("EN_US-AMY-MEDIUM.onnx")?.id,
        )
    }

    @Test
    fun escolhaDeVozPorIdioma() {
        assertEquals(
            "piper-pt-br-faber-medium",
            PiperVoiceCatalog.voiceForLanguage("pt-BR")?.id,
        )
        assertEquals(
            "piper-pt-pt-tugao-medium",
            PiperVoiceCatalog.voiceForLanguage("pt-PT")?.id,
        )
        // pt sem região → variante europeia (Moçambique/Angola)
        assertEquals(
            "piper-pt-pt-tugao-medium",
            PiperVoiceCatalog.voiceForLanguage("pt")?.id,
        )
        assertEquals("piper-en-us-amy-medium", PiperVoiceCatalog.voiceForLanguage("en")?.id)
        assertEquals("piper-en-us-amy-medium", PiperVoiceCatalog.voiceForLanguage("en-US")?.id)
        // underscore no lugar de hífen também funciona
        assertEquals("piper-pt-br-faber-medium", PiperVoiceCatalog.voiceForLanguage("pt_BR")?.id)
        // pt-MZ casa com a variante europeia pelo idioma base
        assertNotNull(PiperVoiceCatalog.voiceForLanguage("pt-MZ"))
        // idioma sem voz: null (o app cai para o TTS do sistema)
        assertNull(PiperVoiceCatalog.voiceForLanguage("ja-JP"))
    }

    @Test
    fun espeakVoiceCorrespondeAoIdioma() {
        assertEquals("pt-br", PiperVoiceCatalog.VOICE_FABER_PT_BR.espeakVoice)
        assertEquals("pt", PiperVoiceCatalog.VOICE_TUGAO_PT_PT.espeakVoice)
        assertEquals("en-us", PiperVoiceCatalog.VOICE_AMY_EN.espeakVoice)
    }
}
