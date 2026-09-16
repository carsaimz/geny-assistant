package com.carsaimz.genyassistant.ai

import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Degradação graciosa do CoreBridge (TODO core-04): nos testes JVM não existe
 * `libgeny_core.so`, então o core fica indisponível e TODOS os métodos devem
 * devolver null — o app nunca quebra por causa do core. No Android (CI, com
 * os .so das 3 ABIs) o caminho positivo é exercitado on-device.
 */
class CoreBridgeTest {

    @Test
    fun `sem a lib, o core fica indisponível e devolve null`() {
        assertFalse("JVM de teste não deve carregar libgeny_core.so", CoreBridge.available)
        assertNull(CoreBridge.coreVersion())
        assertNull(CoreBridge.resolveLanguage("pt"))
        assertNull(CoreBridge.buildSystemPrompt("pt-BR", "[{\"id\":\"time.now\"}]", true))
    }

    @Test
    fun `fallback do resolveSystemPrompt permanece o mesmo sem o core`() {
        // O comportamento de fallback puro (v0.3.0-alpha.4) não muda.
        val prompt = LocalLlmManager.resolveSystemPrompt("", "pt-BR")
        assert(prompt.contains("Geny Assistant") && prompt.contains("pt-BR"))
    }
}
