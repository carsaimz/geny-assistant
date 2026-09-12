package com.carsaimz.genyassistant

import com.carsaimz.genyassistant.ai.BackendSelector
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** Seleção dinâmica de backend — espelha os testes do núcleo Rust. */
class BackendSelectorTest {

    private val local = BackendSelector.Candidate("local", BackendSelector.Mode.LOCAL)
    private val remote = BackendSelector.Candidate("remote", BackendSelector.Mode.REMOTE)

    @Test
    fun offlineForcaLocal() {
        val ctx = BackendSelector.DeviceContext(online = false, batteryPct = 90, batterySaver = false, thermalHigh = false)
        assertEquals("local", BackendSelector.select(listOf(remote, local), ctx, complexTask = true)?.id)
    }

    @Test
    fun economiaDeBateriaPrefereLocal() {
        val ctx = BackendSelector.DeviceContext(online = true, batteryPct = 20, batterySaver = true, thermalHigh = false)
        assertEquals("local", BackendSelector.select(listOf(remote, local), ctx)?.id)
    }

    @Test
    fun tarefaComplexaOnlinePrefereRemoto() {
        val ctx = BackendSelector.DeviceContext(online = true, batteryPct = 90, batterySaver = false, thermalHigh = false)
        assertEquals("remote", BackendSelector.select(listOf(local, remote), ctx, complexTask = true)?.id)
    }

    @Test
    fun semCandidatosRetornaNull() {
        val ctx = BackendSelector.DeviceContext(online = true, batteryPct = 90, batterySaver = false, thermalHigh = false)
        assertNull(BackendSelector.select(emptyList(), ctx))
    }
}
