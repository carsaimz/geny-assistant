package com.carsaimz.genyassistant.models

import com.carsaimz.genyassistant.ai.ModelManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Testes JVM do catálogo unificado e da guarda de download
 * (Fase 3, TODO android-03 / issue #35 — tela nativa de modelos).
 */
class ModelsCatalogTest {

    @Test
    fun catalogoCompletoTem13Entradas() {
        // 4 whisper + 1 silero (stt/vad) + 3 piper + 1 espeak (tts) + 4 gguf (llm)
        assertEquals(13, ModelsCatalog.all().size)
    }

    @Test
    fun agrupamentoPorKindEstaCompleto() {
        val porKind = ModelsCatalog.all().groupBy { it.kind }
        assertEquals(4, porKind["stt"]?.size)
        assertEquals(1, porKind["vad"]?.size)
        assertEquals(4, porKind["tts"]?.size)
        assertEquals(4, porKind["llm"]?.size)
    }

    @Test
    fun idsEArquivosSaoUnicos() {
        val all = ModelsCatalog.all()
        val ids = all.map { it.id }
        val files = all.map { it.fileName }
        assertEquals(ids.size, ids.toSet().size)
        assertEquals(files.size, files.toSet().size)
    }

    @Test
    fun todaEntradaTemSha256EBytesValidos() {
        for (entry in ModelsCatalog.all()) {
            assertTrue("sha curto em ${entry.id}", entry.sha256.length == 64)
            assertTrue("sha nao-hex em ${entry.id}", entry.sha256.all { it in "0123456789abcdef" })
            assertTrue("bytes invalidos em ${entry.id}", entry.bytes > 0)
            assertTrue("label vazio em ${entry.id}", entry.label.isNotBlank())
        }
    }

    @Test
    fun ordemDeExibicaoSttVadTtsLlm() {
        val kinds = ModelsCatalog.all().map { it.kind }.distinct()
        assertEquals(listOf("stt", "vad", "tts", "llm"), kinds)
        assertEquals("whisper-tiny", ModelsCatalog.all().first().id)
        assertEquals("espeak-data", ModelsCatalog.all()[8].id)
    }

    @Test
    fun formatBytesCasosDeterministicos() {
        assertEquals("912 B", ModelsCatalog.formatBytes(912))
        assertEquals("1 KB", ModelsCatalog.formatBytes(1024))
        assertEquals("45 KB", ModelsCatalog.formatBytes(45 * 1024L))
        assertEquals("1 MB", ModelsCatalog.formatBytes(1024L * 1024))
        assertEquals("100 MB", ModelsCatalog.formatBytes(100L * 1024 * 1024))
        assertEquals("1,5 GB", ModelsCatalog.formatBytes(1536L * 1024 * 1024))
        assertEquals("—", ModelsCatalog.formatBytes(-5))
    }

    @Test
    fun shortShaTruncaOuMarcaInvalido() {
        val sha = "be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21"
        assertEquals("be07e048e1e5…", ModelsCatalog.shortSha(sha))
        assertEquals("—", ModelsCatalog.shortSha("abc"))
        assertEquals("—", ModelsCatalog.shortSha(""))
    }
}

class DownloadGuardTest {

    @Test
    fun segundaReservaDoMesmoArquivoFalha() {
        val name = "guard-test-model.bin"
        ModelManager.releaseDownload(name) // estado limpo
        assertTrue(ModelManager.tryAcquireDownload(name))
        assertFalse(ModelManager.tryAcquireDownload(name))
        assertTrue(ModelManager.isDownloading(name))
        ModelManager.releaseDownload(name)
        assertFalse(ModelManager.isDownloading(name))
        // Reserva reutilizada após liberar.
        assertTrue(ModelManager.tryAcquireDownload(name))
        ModelManager.releaseDownload(name)
    }

    @Test
    fun guardaIgnoraMaiusculas() {
        val name = "Guard-Case.bin"
        ModelManager.releaseDownload(name)
        assertTrue(ModelManager.tryAcquireDownload(name))
        assertFalse(ModelManager.tryAcquireDownload(name.uppercase()))
        assertFalse(ModelManager.tryAcquireDownload(name.lowercase()))
        ModelManager.releaseDownload(name)
    }

    @Test
    fun arquivosDiferentesNaoConcorrem() {
        val a = "modelo-a.bin"
        val b = "modelo-b.bin"
        ModelManager.releaseDownload(a)
        ModelManager.releaseDownload(b)
        assertTrue(ModelManager.tryAcquireDownload(a))
        assertTrue(ModelManager.tryAcquireDownload(b))
        assertNotEquals(a, b)
        ModelManager.releaseDownload(a)
        ModelManager.releaseDownload(b)
    }
}
