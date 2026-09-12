package com.carsaimz.genyassistant

import com.carsaimz.genyassistant.tools.ConfirmationLevel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Níveis de confirmação humana (docs §12.3) — espelha os testes do núcleo Rust. */
class ConfirmationLevelTest {

    @Test
    fun ordemDosNiveisECrescente() {
        assertTrue(ConfirmationLevel.NONE < ConfirmationLevel.SIMPLE)
        assertTrue(ConfirmationLevel.SIMPLE < ConfirmationLevel.EXPLICIT)
        assertTrue(ConfirmationLevel.EXPLICIT < ConfirmationLevel.AUTHENTICATED)
    }

    @Test
    fun serializacaoDoCatalogoUsaMinusculas() {
        assertEquals("none", ConfirmationLevel.NONE.name.lowercase())
        assertEquals("simple", ConfirmationLevel.SIMPLE.name.lowercase())
        assertEquals("explicit", ConfirmationLevel.EXPLICIT.name.lowercase())
        assertEquals("authenticated", ConfirmationLevel.AUTHENTICATED.name.lowercase())
    }
}
