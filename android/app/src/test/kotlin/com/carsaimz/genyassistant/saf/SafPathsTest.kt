package com.carsaimz.genyassistant.saf

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Testes JVM dos utilitários puros do SAF (TODO android-05, #40): caminhos
 * relativos seguros e mapeamento de MIME. As operações de DocumentsContract
 * ficam atrás do ContentResolver (device-only), com envelope de erro.
 */
class SafPathsTest {

    // ------------------------------------------------------------- split --

    @Test
    fun caminho_simples_e_dividido() {
        assertEquals(listOf("nota.txt"), SafPaths.split("nota.txt"))
        assertEquals(listOf("sub", "2026", "plano.txt"), SafPaths.split("sub/2026/plano.txt"))
    }

    @Test
    fun caminho_com_barras_extras_e_normalizado() {
        assertEquals(listOf("sub", "a.txt"), SafPaths.split("/sub/a.txt/"))
        assertEquals(listOf("sub", "a.txt"), SafPaths.split("  sub/a.txt  "))
    }

    @Test
    fun caminho_vazio_e_lista_vazia() {
        assertEquals(emptyList<String>(), SafPaths.split(""))
        assertEquals(emptyList<String>(), SafPaths.split("   "))
        assertEquals(emptyList<String>(), SafPaths.split("/"))
    }

    @Test
    fun travessia_para_cima_e_rejeitada() {
        assertNull(SafPaths.split(".."))
        assertNull(SafPaths.split("sub/../../etc/passwd"))
        assertNull(SafPaths.split("sub/../a.txt"))
        assertNull(SafPaths.split("a/./b"))
    }

    @Test
    fun segmentos_vazios_sao_rejeitados() {
        assertNull(SafPaths.split("a//b"))
    }

    // ------------------------------------------------------------ mimeFor --

    @Test
    fun diretorio_tem_mime_de_diretorio() {
        assertEquals(
            android.provider.DocumentsContract.Document.MIME_TYPE_DIR,
            SafPaths.mimeFor("qualquer", isDir = true),
        )
    }

    @Test
    fun extensoes_conhecidas_mapeiam_para_texto() {
        assertEquals("text/plain", SafPaths.mimeFor("nota.txt", isDir = false))
        assertEquals("text/plain", SafPaths.mimeFor("plano.md", isDir = false))
        assertEquals("application/json", SafPaths.mimeFor("dados.json", isDir = false))
    }

    @Test
    fun binarios_e_sem_extensao_caiem_no_fallback() {
        assertEquals("application/octet-stream", SafPaths.mimeFor("app", isDir = false))
        assertEquals("application/octet-stream", SafPaths.mimeFor("backup.xyz", isDir = false))
        assertEquals("image/png", SafPaths.mimeFor("foto.PNG", isDir = false))
    }

    // ------------------------------------------------------------- limites --

    @Test
    fun limite_de_leitura_e_2mib() {
        assertEquals(2 * 1024 * 1024, SafPaths.MAX_READ_BYTES)
        assertTrue(SafPaths.MAX_READ_BYTES > 0)
        assertFalse(SafPaths.MAX_READ_BYTES < 1024)
    }
}
