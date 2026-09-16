package com.carsaimz.genyassistant.voice

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Testes JVM do catálogo openWakeWord (TODO android-03b): hashes pinados da
 * release oficial v0.5.1, unicidade e consistência com a tela nativa.
 */
class WakeWordCatalogTest {

    @Test
    fun catalogoTem2FeaturesE4Frases() {
        assertEquals(2, WakeWordCatalog.ALL.size - WakeWordCatalog.WAKE_WORDS.size)
        assertEquals(4, WakeWordCatalog.WAKE_WORDS.size)
        assertEquals(6, WakeWordCatalog.ALL.size)
    }

    @Test
    fun idsEArquivosSaoUnicos() {
        val ids = WakeWordCatalog.ALL.map { it.id }
        val files = WakeWordCatalog.ALL.map { it.fileName }
        assertEquals(ids.size, ids.toSet().size)
        assertEquals(files.size, files.toSet().size)
    }

    @Test
    fun todosOsHashesSaoSha256Validos() {
        for (m in WakeWordCatalog.ALL) {
            assertTrue("sha curto em ${m.id}", m.sha256.length == 64)
            assertTrue("sha não-hex em ${m.id}", m.sha256.all { it in "0123456789abcdef" })
            assertTrue("bytes inválidos em ${m.id}", m.bytes > 0)
            assertTrue("url https em ${m.id}", m.url.startsWith("https://"))
            assertEquals("kind fixo em ${m.id}", "wakeword", m.kind)
        }
    }

    @Test
    fun hashesPinosDaReleaseV051() {
        // Hashes calculados dos assets oficiais da release v0.5.1 (2026-09);
        // travados aqui para detectar substituição silenciosa de modelo.
        assertEquals(
            "ba2b0e0f8b7b875369a2c89cb13360ff53bac436f2895cced9f479fa65eb176f",
            WakeWordCatalog.MELSPECTROGRAM.sha256,
        )
        assertEquals(
            "70d164290c1d095d1d4ee149bc5e00543250a7316b59f31d056cff7bd3075c1f",
            WakeWordCatalog.EMBEDDING.sha256,
        )
        assertEquals(
            "94a13cfe60075b132f6a472e7e462e8123ee70861bc3fb58434a73712ee0d2cb",
            WakeWordCatalog.wakeWordById("oww-hey-jarvis")?.sha256,
        )
    }

    @Test
    fun urlsApontamParaOGitHubRelease() {
        for (m in WakeWordCatalog.ALL) {
            assertTrue(m.url.startsWith("https://github.com/dscripka/openWakeWord/releases/download/v0.5.1/"))
        }
    }

    @Test
    fun byIdDesconhecidoRetornaNull() {
        assertEquals(null, WakeWordCatalog.byId("não-existe"))
        assertEquals(null, WakeWordCatalog.wakeWordById("oww-melspectrogram"))
        assertNotEquals(null, WakeWordCatalog.wakeWordById("oww-alexa"))
    }
}

/**
 * Gatilho puro: aquecimento de 5 frames (openWakeWord zera as primeiras
 * predições), limiar 0,5 e refratário de 2,5 s entre disparos.
 */
class WakeWordTriggerTest {

    private class FakeClock {
        var now = 1_000_000L
        fun tick(ms: Long) {
            now += ms
        }
    }

    @Test
    fun aquecimentoZeraAsPrimeirasCincoPredicoes() {
        val trigger = WakeWordTrigger(clock = { 0L })
        repeat(5) { i ->
            assertFalse("frame $i não devia disparar", trigger.onScore(0.99f))
        }
        assertTrue(trigger.onScore(0.99f)) // frame 6 já vale
    }

    @Test
    fun scoreAbaixoDoLimiarNaoDispara() {
        val trigger = WakeWordTrigger(clock = { 0L })
        repeat(6) { trigger.onScore(0f) }
        assertFalse(trigger.onScore(0.49f))
        assertTrue(trigger.onScore(0.5f))
    }

    @Test
    fun refratarioImpedeDisparosRapidos() {
        val clock = FakeClock()
        val trigger = WakeWordTrigger(clock = { clock.now })
        repeat(6) { trigger.onScore(0f) }
        assertTrue(trigger.onScore(0.9f))
        clock.tick(1_000) // 1 s depois
        assertFalse("dentro do refratário", trigger.onScore(0.9f))
        clock.tick(2_000) // 3 s depois do 1º
        assertTrue(trigger.onScore(0.9f))
    }

    @Test
    fun resetLimpaAquecimentoERefratario() {
        val clock = FakeClock()
        val trigger = WakeWordTrigger(clock = { clock.now })
        repeat(5) { trigger.onScore(0.99f) }
        assertTrue(trigger.onScore(0.99f))
        trigger.reset()
        repeat(5) { assertFalse(trigger.onScore(0.99f)) }
        assertTrue(trigger.onScore(0.99f))
    }

    @Test
    fun constantesEspelhamOOpenWakeWord() {
        assertEquals(0.5f, WakeWordTrigger.DEFAULT_THRESHOLD, 1e-6f)
        assertEquals(5, WakeWordTrigger.WARMUP_FRAMES)
    }
}
