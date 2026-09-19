package com.carsaimz.genyassistant

import com.carsaimz.genyassistant.security.ProviderKeys
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Chaves por provedor (Fase 6, TODO android-09, issue #51): convenção dos
 * nomes de segredo no Keystore — ids válidos viram `provider-key-<id>`,
 * nomes arbitrários vindos da web nunca passam.
 *
 * Per-provider API keys (Phase 6, TODO android-09, issue #51): secret name
 * convention in the Keystore — valid ids become `provider-key-<id>`,
 * arbitrary names coming from the web never pass.
 */
class ProviderKeysTest {

    @Test
    fun ids_conhecidos_sao_validos() {
        for (id in listOf("groq", "openrouter", "ollama", "lm-studio", "llama-cpp", "custom")) {
            assertTrue("id deveria ser válido: $id", ProviderKeys.validProvider(id))
        }
    }

    @Test
    fun nomes_invalidos_sao_rejeitados() {
        // vazios, maiúsculas, espaços, path traversal e muito longos não passam
        assertFalse(ProviderKeys.validProvider(""))
        assertFalse(ProviderKeys.validProvider("Groq"))
        assertFalse(ProviderKeys.validProvider("open ai"))
        assertFalse(ProviderKeys.validProvider("../evil"))
        assertFalse(ProviderKeys.validProvider("-comeca-hifen"))
        assertFalse(ProviderKeys.validProvider("a".repeat(33)))
    }

    @Test
    fun nome_canonico_do_segredo() {
        assertEquals("provider-key-groq", ProviderKeys.secretName("groq"))
        assertEquals("provider-key-lm-studio", ProviderKeys.secretName("lm-studio"))
        assertNull(ProviderKeys.secretName("../evil"))
    }

    @Test
    fun roundtrip_nome_para_id() {
        assertEquals("groq", ProviderKeys.providerFromSecretName("provider-key-groq"))
        assertNull(ProviderKeys.providerFromSecretName("api-key")) // legado não vira provedor
        assertNull(ProviderKeys.providerFromSecretName("provider-key-")) // vazio
        assertNull(ProviderKeys.providerFromSecretName("provider-key-Groq")) // inválido
    }
}
