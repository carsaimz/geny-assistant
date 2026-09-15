package com.carsaimz.genyassistant.ai

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Testes JVM do catálogo LLM e do parser de mensagens (Fase 3, TODO core-05).
 */
class LlmCatalogTest {

    @Test
    fun catalogoTemIdsUnicos() {
        val ids = LlmCatalog.MODELS.map { it.id }
        assertEquals(ids.size, ids.toSet().size)
    }

    @Test
    fun todosOsModelosTemHashSha256Valido() {
        for (m in LlmCatalog.MODELS) {
            assertTrue("hash do ${m.id} deve ter 64 hex", m.sha256.matches(Regex("[0-9a-f]{64}")))
        }
    }

    @Test
    fun todosOsModelosTemTamanhoPositivoEUrlHttps() {
        for (m in LlmCatalog.MODELS) {
            assertTrue("bytes do ${m.id}", m.bytes > 1_000_000L)
            assertTrue("url do ${m.id} deve ser https", m.url.startsWith("https://"))
            assertTrue("fileName do ${m.id} termina em .gguf", m.fileName.endsWith(".gguf"))
        }
    }

    @Test
    fun buscaPorIdEFileName() {
        assertEquals("qwen2.5-0.5b-instruct", LlmCatalog.byId("qwen2.5-0.5b-instruct")?.id)
        assertEquals(null, LlmCatalog.byId("modelo-inexistente"))
        val info = LlmCatalog.byFileName("LLAMA-3.2-1B-INSTRUCT-Q4_K_M.GGUF")
        assertEquals("llama-3.2-1b-instruct", info?.id) // busca case-insensitive
    }

    @Test
    fun contextoDeTodosOsModelosEPositivo() {
        for (m in LlmCatalog.MODELS) {
            assertTrue("contextTokens do ${m.id}", m.contextTokens >= 1024)
        }
    }
}

class LocalLlmManagerTest {

    @Test
    fun extractPairsAceitaHistoricoValido() {
        val json = """[{"role":"user","content":"ola"},{"role":"assistant","content":"oi!"}]"""
        val (roles, contents) = LocalLlmManager.extractPairs(json)
        assertEquals(listOf("user", "assistant"), roles)
        assertEquals(listOf("ola", "oi!"), contents)
    }

    @Test
    fun extractPairsDescartaRolesInvalidosEVazios() {
        val json = """
            [
              {"role":"system","content":"injetado"},
              {"role":"user","content":""},
              {"role":"user","content":"ok"},
              {"content":"sem role"},
              {"role":"assistant","content":"fim"}
            ]
        """.trimIndent()
        val (roles, contents) = LocalLlmManager.extractPairs(json)
        assertEquals(listOf("user", "assistant"), roles)
        assertEquals(listOf("ok", "fim"), contents)
    }

    @Test
    fun extractPairsComEntradaInvalidaDevolveVazio() {
        assertEquals(0, LocalLlmManager.extractPairs("").first.size)
        assertEquals(0, LocalLlmManager.extractPairs("nao-json").first.size)
        assertEquals(0, LocalLlmManager.extractPairs("{}").first.size)
    }

    @Test
    fun requiredRamCresceComModeloEIncluiOverhead() {
        val small = LocalLlmManager.requiredRamBytes(400_000_000L)
        val large = LocalLlmManager.requiredRamBytes(1_700_000_000L)
        assertTrue(small > 400_000_000L)
        assertTrue(large > small)
        val overhead = LocalLlmManager.requiredRamBytes(0L)
        assertTrue(overhead >= 128L * 1024 * 1024)
    }

    @Test
    fun estimateThreadsEntreUmESeis() {
        assertTrue(LocalLlmManager.estimateThreads(1) in 1..6)
        assertTrue(LocalLlmManager.estimateThreads(2) in 1..6)
        assertTrue(LocalLlmManager.estimateThreads(16) in 1..6)
        assertEquals(3, LocalLlmManager.estimateThreads(6))
        assertFalse(LocalLlmManager.estimateThreads(8) > 6)
    }

    @Test
    fun resolveSystemPromptExplicitoDoAppVence() {
        // TODO Fase 3: prompt por idioma/cultura construído no app
        // (buildSystemPrompt) viaja pela ponte e vence o fallback.
        val explicit = "Voce e o Geny Assistant...\n4. Responda SEMPRE no idioma do usuario " +
            "(idioma padrao: pt-BR). Use portugues do Brasil, tom acolhedor e direto."
        assertEquals(explicit, LocalLlmManager.resolveSystemPrompt(explicit, "pt-BR"))
    }

    @Test
    fun resolveSystemPromptEmBrancoCaiParaLocaleDoDispositivo() {
        val fallback = LocalLlmManager.resolveSystemPrompt(null, "pt-BR")
        assertTrue(fallback.contains("Geny Assistant"))
        assertTrue(fallback.contains("pt-BR"))
        // whitespace/explicit vazio também cai no fallback
        assertEquals(fallback, LocalLlmManager.resolveSystemPrompt("   ", "pt-BR"))
        assertEquals(fallback, LocalLlmManager.resolveSystemPrompt("", "pt-BR"))
    }
}
