package com.carsaimz.genyassistant.security

/**
 * Chaves por provedor (Fase 6, TODO android-09, issue #51): convenção dos
 * segredos guardados no Keystore — um por provedor OpenAI-compatível.
 *
 * **PT** Lógica pura e JVM-testável: valida o id do provedor e deriva o nome
 * canônico do segredo (`provider-key-<provider>`). O ciframento em si é do
 * [KeystoreManager] (AES-256-GCM); a ponte (`GenyPlugin`) só aceita ids
 * válidos — nunca um nome arbitrário vindo da web.
 * **EN** Pure, JVM-testable logic: validates the provider id and derives the
 * canonical secret name (`provider-key-<provider>`). The encryption itself
 * belongs to [KeystoreManager] (AES-256-GCM); the bridge (`GenyPlugin`) only
 * accepts valid ids — never an arbitrary name coming from the web.
 */
object ProviderKeys {

    /** Prefixo dos segredos por provedor no cofre. */
    const val NAME_PREFIX = "provider-key-"

    /** Id válido: minúsculas, dígitos e hífen; 1–32 chars (ex.: `groq`, `lm-studio`). */
    private val ID_PATTERN = Regex("[a-z0-9][a-z0-9-]{0,31}")

    /** Id do provedor é válido para virar nome de segredo? */
    fun validProvider(provider: String): Boolean = ID_PATTERN.matches(provider)

    /** Nome canônico do segredo; null quando o id é inválido. */
    fun secretName(provider: String): String? =
        if (validProvider(provider)) NAME_PREFIX + provider else null

    /** Extrai o id do provedor de um nome de segredo (ou null se não for dele). */
    fun providerFromSecretName(name: String): String? =
        if (name.startsWith(NAME_PREFIX) && name.length > NAME_PREFIX.length) {
            val id = name.removePrefix(NAME_PREFIX)
            if (validProvider(id)) id else null
        } else {
            null
        }
}
