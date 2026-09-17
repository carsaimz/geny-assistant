package com.carsaimz.genyassistant

import com.carsaimz.genyassistant.data.FactEntity
import com.carsaimz.genyassistant.data.RetentionLogic
import com.carsaimz.genyassistant.data.RetentionSpec
import com.carsaimz.genyassistant.security.BackupContent
import com.carsaimz.genyassistant.security.BackupCrypto
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Testes JVM da Fase 5: cripto do backup cifrado (app-04, issue #48),
 * envelope do backup e política de retenção (core-09, issue #47) —
 * tudo puro, sem Robolectric.
 */
class BackupCryptoTest {

    private val pass = "correta-morfina-42".toCharArray()

    @Test
    fun roundtripCryptografico() {
        val plain = """{"version":1,"facts":[{"key":"wifi","value":"Rede5G"}]}""".toByteArray()
        val blob = BackupCrypto.encrypt(plain, pass)
        assertTrue("blob deve começar com o magic GENYBAK1", blob.size > BackupCrypto.MAGIC.size)
        assertArrayEquals(
            BackupCrypto.MAGIC,
            blob.copyOfRange(0, BackupCrypto.MAGIC.size),
        )
        val decrypted = BackupCrypto.decrypt(blob, pass)
        assertArrayEquals(plain, decrypted)
    }

    @Test(expected = java.security.GeneralSecurityException::class)
    fun senhaErradaFalhaNaAutenticacaoGCM() {
        val plain = "segredo".toByteArray()
        val blob = BackupCrypto.encrypt(plain, pass)
        BackupCrypto.decrypt(blob, "errada".toCharArray())
    }

    @Test(expected = IllegalArgumentException::class)
    fun arquivoForaDoFormatoRejeitado() {
        val fake = ByteArray(64) { it.toByte() }
        BackupCrypto.decrypt(fake, pass)
    }

    @Test(expected = IllegalArgumentException::class)
    fun senhaVaziaRejeitada() {
        BackupCrypto.encrypt("x".toByteArray(), CharArray(0))
    }

    @Test
    fun ivsDiferentesEntreExecucoes() {
        val plain = "mesmo payload".toByteArray()
        val a = BackupCrypto.encrypt(plain, pass)
        val b = BackupCrypto.encrypt(plain, pass)
        // Salt+IV aleatórios: ciphertexts diferem, mas ambos decifram.
        assertFalse(a.contentEquals(b))
        assertArrayEquals(plain, BackupCrypto.decrypt(a, pass))
        assertArrayEquals(plain, BackupCrypto.decrypt(b, pass))
    }
}

class BackupContentTest {

    @Test
    fun buildESplitRoundtrip() {
        val settings = """{"mode":"local","language":"pt-BR","apiKey":"sk-test"}"""
        val memory =
            """{"version":1,"exported_at_ms":5,"retention":{"max_facts":100},"facts":[]}"""
        val envelope = BackupContent.build(settings, memory, 1_234L)

        val json = org.json.JSONObject(envelope)
        assertEquals(BackupContent.VERSION, json.getInt("version"))
        assertEquals("geny-assistant", json.getString("app"))
        assertEquals(1_234L, json.getLong("exported_at_ms"))
        assertEquals("sk-test", json.getJSONObject("settings").getString("apiKey"))
        assertEquals(100, json.getJSONObject("retention").getInt("max_facts"))

        val (backSettings, backMemory) = BackupContent.split(envelope)
        val backSettingsJson = org.json.JSONObject(backSettings)
        assertEquals("sk-test", backSettingsJson.getString("apiKey"))
        val backMemoryJson = org.json.JSONObject(backMemory)
        assertEquals(100, backMemoryJson.getJSONObject("retention").getInt("max_facts"))
        assertEquals(0, backMemoryJson.getJSONArray("facts").length())
    }

    @Test(expected = IllegalArgumentException::class)
    fun versaoDesconhecidaRejeitada() {
        BackupContent.split("""{"version":99}""")
    }

    @Test
    fun settingsEFatosOpcionaisTolerados() {
        val (settings, memory) = BackupContent.split("""{"version":1,"facts":[{"key":"k","value":"v","tags":[],"updated_at_ms":9}]}""")
        assertEquals("{}", settings)
        val memJson = org.json.JSONObject(memory)
        assertEquals("k", memJson.getJSONArray("facts").getJSONObject(0).getString("key"))
    }
}

class RetentionLogicTest {

    private val day = 86_400_000L

    @Test
    fun semPoliticaNadaEsquecido() {
        val facts = listOf(FactEntity("a", "1", 1L))
        assertTrue(RetentionLogic.apply(facts, RetentionSpec(0, 0, 0), 999_999L).isEmpty())
        assertFalse(RetentionSpec(0, 0, 0).isActive())
        assertTrue(RetentionSpec(10, 10, 10).isActive())
    }

    @Test
    fun idadeMaximaRemoveAntigos() {
        val facts = listOf(
            FactEntity("velho", "v", 10 * day),
            FactEntity("novo", "v", 95 * day),
        )
        val spec = RetentionSpec(0, 60, 0)
        val forgotten = RetentionLogic.apply(facts, spec, 95 * day)
        assertEquals(listOf("velho"), forgotten)
    }

    @Test
    fun tamanhoMaximoRemoveValoresGrandes() {
        val facts = listOf(
            FactEntity("ok", "curto", 1L),
            FactEntity("grande", "x".repeat(100), 1L),
        )
        val forgotten = RetentionLogic.apply(facts, RetentionSpec(0, 0, 50), 2L)
        assertEquals(listOf("grande"), forgotten)
    }

    @Test
    fun limiteDeQuantidadeApagaMaisAntigosPrimeiro() {
        val facts = listOf(
            FactEntity("a", "0", 3_000L),
            FactEntity("b", "1", 1_000L),
            FactEntity("c", "2", 2_000L),
        )
        val forgotten = RetentionLogic.apply(facts, RetentionSpec(2, 0, 0), 10_000L)
        assertEquals(listOf("b"), forgotten)
    }

    @Test
    fun regrasCombinadasSemDuplicatas() {
        val now = 10 * day
        val facts = listOf(
            FactEntity("antigo_grande", "x".repeat(80), 5L),
            FactEntity("recente", "ok", now - 1_000L),
        )
        val forgotten = RetentionLogic.apply(facts, RetentionSpec(0, 1, 50), now)
        assertEquals(listOf("antigo_grande"), forgotten)
    }
}
