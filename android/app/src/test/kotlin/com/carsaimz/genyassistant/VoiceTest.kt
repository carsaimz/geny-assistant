package com.carsaimz.genyassistant.voice

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Testes JVM do VAD de energia e do montador de segmentos — espelham os
 * testes de core/src/vad.rs (TODO core-01).
 */
class VadAndAssemblerTest {

    private val config = VadConfig()

    private fun frame(amplitude: Float): ShortArray =
        ShortArray(config.frameSamples) { (amplitude * 32_000).toInt().toShort() }

    @Test
    fun `frame padrao tem 480 amostras`() {
        assertEquals(480, config.frameSamples)
    }

    @Test
    fun `silencio nao produz segmento`() {
        val vad = EnergyVadEngine(config)
        val asm = PcmAssembler(config)
        val quiet = frame(0.0005f)
        repeat(200) {
            val d = vad.process(quiet)
            asm.push(quiet, d.speech)
        }
        assertNull(asm.finish())
        assertFalse(vad.isSpeaking)
    }

    @Test
    fun `fala acorda no quarto frame e produz pcm com pre-roll`() {
        val vad = EnergyVadEngine(config)
        val asm = PcmAssembler(config)
        val quiet = frame(0.0005f)
        val loud = frame(0.35f)
        repeat(10) {
            asm.push(quiet, vad.process(quiet).speech)
        }
        var started = false
        repeat(40) {
            val d = vad.process(loud)
            started = started || d.started
            asm.push(loud, d.speech)
        }
        assertTrue(started)
        val pcm = asm.finish()!!
        // 5 frames de pré-roll + 37 de fala = 42 frames úteis.
        assertEquals(42 * config.frameSamples, pcm.size)
    }

    @Test
    fun `pausa curta nao encerra fala`() {
        val vad = EnergyVadEngine(config)
        val loud = frame(0.35f)
        val quiet = frame(0.0005f)
        repeat(20) { vad.process(loud) }
        assertTrue(vad.isSpeaking)
        vad.process(quiet)
        vad.process(quiet)
        assertTrue(vad.isSpeaking)
    }

    @Test
    fun `click curto nao conta como fala`() {
        val vad = EnergyVadEngine(config)
        val loud = frame(0.35f)
        vad.process(loud)
        vad.process(loud)
        assertFalse(vad.isSpeaking)
    }

    @Test
    fun `rms normalizado nas bordas`() {
        assertEquals(0f, EnergyVadEngine.rmsNormalized(ShortArray(0)))
        assertEquals(0f, EnergyVadEngine.rmsNormalized(ShortArray(480)))
        assertTrue(EnergyVadEngine.rmsNormalized(ShortArray(480) { 32000 }) > 0.9f)
    }

    @Test
    fun `assembler ignora pre-roll quando ha fala imediata`() {
        val asm = PcmAssembler(config)
        val loud = frame(1f)
        asm.push(loud, speech = true)
        assertTrue(asm.speechDetected)
        assertEquals(config.frameSamples, asm.collectedSamples)
    }

    @Test
    fun `catalogo tem hashes e modelos com nomes seguros`() {
        for (m in VoiceCatalog.ALL) {
            assertTrue("hash inválido em ${m.id}", m.sha256.matches(Regex("[0-9a-f]{64}")))
            assertTrue("arquivo inseguro em ${m.id}", m.fileName.matches(Regex("[A-Za-z0-9._-]+")))
            assertTrue("tamanho inválido em ${m.id}", m.bytes > 1_000_000)
        }
        assertEquals(4, VoiceCatalog.STT_MODELS.size)
        assertEquals(VoiceCatalog.STT_WHISPER_TINY, VoiceCatalog.sttById("whisper-tiny"))
        assertNull(VoiceCatalog.sttById("inexistente"))
    }

    @Test
    fun `idioma whisper vira iso-639-1`() {
        assertEquals("pt", VoiceManager.whisperLanguage("pt-BR"))
        assertEquals("pt", VoiceManager.whisperLanguage("pt-PT"))
        assertEquals("en", VoiceManager.whisperLanguage("en-US"))
        assertEquals("zh", VoiceManager.whisperLanguage("zh-CN"))
        assertEquals("auto", VoiceManager.whisperLanguage(""))
        assertEquals("auto", VoiceManager.whisperLanguage("xyz"))
    }
}
