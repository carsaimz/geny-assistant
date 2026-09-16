package com.carsaimz.genyassistant.data

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Testes JVM do Room (TODO android-04) via Robolectric: SQLite real, sem
 * emulador. Cobre o contrato da fachada usada por GenyPlugin/ModelManager.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class GenyDbTest {

    private lateinit var db: GenyDb

    @Before
    fun setUp() {
        // O singleton sobrevive entre métodos no Robolectric: recria por teste.
        GenyDatabase.resetForTests()
        val context = ApplicationProvider.getApplicationContext<Context>()
        db = GenyDb(context)
    }

    /**
     * Room proíbe acesso na main thread (Robolectric roda testes nela).
     * Em produção a fachada é chamada de threads de fundo — aqui espelhamos
     * isso com um executor de thread única.
     */
    private fun <T> offMain(block: () -> T): T {
        val latch = CountDownLatch(1)
        var result: T? = null
        var error: Throwable? = null
        val executor = Executors.newSingleThreadExecutor()
        executor.execute {
            try {
                result = block()
            } catch (t: Throwable) {
                error = t
            } finally {
                latch.countDown()
            }
        }
        assertTrue("teste travou", latch.await(30, TimeUnit.SECONDS))
        executor.shutdown()
        error?.let { throw it }
        @Suppress("UNCHECKED_CAST")
        return result as T
    }

    @Test
    fun `mensagens entram e saem em ordem cronologica`() = offMain {
        db.insertMessage("user", "olá", 1_000)
        db.insertMessage("assistant", "oi!", 2_000)
        db.insertMessage("user", "tudo bem?", 3_000)

        val recent = db.recentMessages(2)
        assertEquals(listOf("assistant" to "oi!", "user" to "tudo bem?"), recent)
    }

    @Test
    fun `chamada de ferramenta é idempotente por callId`() = offMain {
        db.recordToolCall("c1", "device.battery", "{}", "ok", 1_000)
        db.recordToolCall("c1", "device.battery", "{}", "failed", 2_000)

        // Não há leitor público de tool_calls; valida que o upsert não falha
        // e que o banco continua utilizável.
        db.recordToolCall("c2", "app.open", "{}", "ok", 3_000)
        assertTrue(db.recallFact("inexistente") == null)
        Unit
    }

    @Test
    fun `modelo é substituído por kind+name e listado por categoria`() = offMain {
        db.upsertModel("stt", "ggml-tiny.bin", "/m/tiny", "abc", 100, 1_000)
        db.upsertModel("stt", "ggml-tiny.bin", "/m/tiny-v2", "abd", 110, 2_000)
        db.upsertModel("tts", "faber.onnx", "/m/faber", "abe", 120, 3_000)

        val stt = db.listModels("stt")
        assertEquals(1, stt.size)
        assertEquals("/m/tiny-v2", stt[0].path)
        assertEquals(110L, stt[0].sizeBytes)

        val all = db.listModels()
        assertEquals(2, all.size)
        // ordenação por nome
        assertEquals("faber.onnx", all[0].name)
    }

    @Test
    fun `fato lembrado sobrescreve valor anterior`() = offMain {
        db.rememberFact("nome_do_usuario", "Ana", 1_000)
        assertEquals("Ana", db.recallFact("nome_do_usuario"))
        db.rememberFact("nome_do_usuario", "Bruno", 2_000)
        assertEquals("Bruno", db.recallFact("nome_do_usuario"))
        assertNull(db.recallFact("outro"))
        Unit
    }

    @Test
    fun `deleteModelByPath remove apenas o registro correspondente`() = offMain {
        db.upsertModel("stt", "a.bin", "/m/a.bin", "h1", 1, 1_000)
        db.upsertModel("stt", "b.bin", "/m/b.bin", "h2", 2, 2_000)

        db.deleteModelByPath("/m/a.bin")

        val rows = db.listModels()
        assertEquals(1, rows.size)
        assertEquals("b.bin", rows[0].name)
    }
}
