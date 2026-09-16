package com.carsaimz.genyassistant.ai

import android.util.Log

/**
 * Ponte segura para o núcleo Rust via UniFFI (TODO core-04).
 *
 * **PT** Carrega `libgeny_core.so` UMA vez e expõe funções do núcleo real —
 * sem espelhar lógica em Kotlin. QUALQUER falha (lib ausente em builds de
 * desenvolvimento sem cargo, ABI incorreta, erro do JNA) degrada para `null`
 * e o chamador usa o fallback — o app NUNCA quebra por causa do core. No
 * Android os .so são construídos no CI (workflows build-native/build-apk);
 * nos testes JVM o core não existe e o fallback é testado.
 * **EN** Loads `libgeny_core.so` ONCE and exposes real core functions — no
 * mirrored logic in Kotlin. ANY failure (missing lib in dev builds without
 * cargo, wrong ABI, JNA error) degrades to `null` and the caller uses its
 * fallback — the app never breaks because of the core. Android .so files are
 * built in CI (build-native/build-apk workflows); JVM tests run without the
 * core and exercise the fallback path.
 */
object CoreBridge {

    private const val TAG = "geny-core"

    /** true quando a biblioteca carregou (e os checksums passaram). */
    val available: Boolean by lazy { loadSafe() }

    private fun loadSafe(): Boolean = try {
        uniffi.geny_core.uniffiEnsureInitialized()
        true
    } catch (t: Throwable) {
        // UnsatisfiedLinkError em dev (sem .so); Throwable porque o JNA pode
        // falhar de formas variadas — o core é opcional por design.
        logUnavailable(t)
        false
    }

    /** Log à prova de falhas: android.util.Log não existe em testes JVM. */
    private fun logUnavailable(t: Throwable) {
        try {
            Log.w(TAG, "libgeny_core.so indisponível — usando fallbacks: ${t.message}")
        } catch (_: Throwable) {
        }
    }

    /** Versão do core, ou null quando indisponível. */
    fun coreVersion(): String? = try {
        if (available) uniffi.geny_core.coreVersion() else null
    } catch (_: Throwable) {
        null
    }

    /** Código canônico do idioma (ex.: "pt" → "pt-BR"), ou null. */
    fun resolveLanguage(code: String): String? = try {
        if (available) uniffi.geny_core.resolveLanguage(code) else null
    } catch (_: Throwable) {
        null
    }

    /**
     * Prompt de sistema POR IDIOMA/CULTURA direto do Rust (i18n.rs), ou null
     * quando o core não está disponível neste build.
     */
    fun buildSystemPrompt(languageCode: String, toolCatalogJson: String, privacyStatement: Boolean): String? =
        try {
            if (available) {
                uniffi.geny_core.buildSystemPrompt(languageCode, toolCatalogJson, privacyStatement)
            } else {
                null
            }
        } catch (_: Throwable) {
            null
        }
}
