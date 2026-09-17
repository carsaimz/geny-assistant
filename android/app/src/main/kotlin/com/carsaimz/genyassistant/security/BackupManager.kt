package com.carsaimz.genyassistant.security

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import javax.crypto.Cipher
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

/**
 * Backup cifrado de configuração (TODO app-04, Fase 5) — sem nuvem.
 *
 * **PT** Arquivo portátil `GENYBAK1`: PBKDF2-HMAC-SHA256 (210.000 iterações,
 * salt aleatório de 16 bytes) deriva a chave AES-256 da senha escolhida pelo
 * usuário; AES-256-GCM (IV aleatório de 12 bytes, tag 128) cifra o payload.
 * O formato é independente do Android Keystore — a senha é o único segredo,
 * então o backup é restaurável em qualquer aparelho sem nuvem. A SENHA NÃO
 * É RECUPERÁVEL: sem ela, o arquivo é inútil (GCM autentica e rejeita).
 * **EN** Portable `GENYBAK1` file: PBKDF2-HMAC-SHA256 (210,000 iterations,
 * 16-byte random salt) derives the AES-256 key from the user-chosen
 * passphrase; AES-256-GCM (12-byte random IV, 128-bit tag) encrypts the
 * payload. The format is independent of the Android Keystore — the
 * passphrase is the only secret, so the backup restores on any device with
 * no cloud. THE PASSPHRASE IS NOT RECOVERABLE: without it the file is
 * useless (GCM authenticates and rejects).
 */
object BackupCrypto {

    /** Magic ASCII do formato — valida o arquivo antes de decifrar. */
    val MAGIC = "GENYBAK1".toByteArray(Charsets.US_ASCII)

    private const val SALT_SIZE = 16
    private const val IV_SIZE = 12
    private const val KEY_BITS = 256
    private const val GCM_TAG_BITS = 128
    private const val PBKDF2_ITERATIONS = 210_000
    private const val TRANSFORM = "AES/GCM/NoPadding"
    private const val KDF = "PBKDF2WithHmacSHA256"

    /**
     * Cifra o payload: `MAGIC | salt(16) | iv(12) | ciphertext+tag`.
     * Lança [IllegalStateException] se o RNG do ambiente falhar.
     */
    fun encrypt(plain: ByteArray, passphrase: CharArray): ByteArray {
        require(passphrase.isNotEmpty()) { "senha vazia" }
        val salt = ByteArray(SALT_SIZE).also { secureRandom().nextBytes(it) }
        val iv = ByteArray(IV_SIZE).also { secureRandom().nextBytes(it) }
        val key = deriveKey(passphrase, salt)
        val cipher = Cipher.getInstance(TRANSFORM)
        cipher.init(Cipher.ENCRYPT_MODE, key, GCMParameterSpec(GCM_TAG_BITS, iv))
        val encrypted = cipher.doFinal(plain)
        return MAGIC + salt + iv + encrypted
    }

    /**
     * Decifra um arquivo [encrypt]; valida magic e autenticação GCM.
     * Lança [IllegalArgumentException] em arquivo corrompido/senha errada.
     */
    fun decrypt(blob: ByteArray, passphrase: CharArray): ByteArray {
        require(passphrase.isNotEmpty()) { "senha vazia" }
        val magicSize = MAGIC.size
        require(blob.size > magicSize + SALT_SIZE + IV_SIZE) { "arquivo muito curto" }
        require(blob.copyOfRange(0, magicSize).contentEquals(MAGIC)) { "arquivo não é um backup Geny" }
        val salt = blob.copyOfRange(magicSize, magicSize + SALT_SIZE)
        val iv = blob.copyOfRange(magicSize + SALT_SIZE, magicSize + SALT_SIZE + IV_SIZE)
        val encrypted = blob.copyOfRange(magicSize + SALT_SIZE + IV_SIZE, blob.size)
        val key = deriveKey(passphrase, salt)
        val cipher = Cipher.getInstance(TRANSFORM)
        cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(GCM_TAG_BITS, iv))
        return cipher.doFinal(encrypted) // AEADBadTagException se senha errada
    }

    private fun deriveKey(passphrase: CharArray, salt: ByteArray): SecretKeySpec {
        val factory = SecretKeyFactory.getInstance(KDF)
        val spec = PBEKeySpec(passphrase, salt, PBKDF2_ITERATIONS, KEY_BITS)
        val key = factory.generateSecret(spec).encoded
        spec.clearPassword()
        return SecretKeySpec(key, "AES")
    }

    private fun secureRandom(): java.security.SecureRandom = java.security.SecureRandom()
}

/**
 * Conteúdo do backup (TODO app-04): configurações web + fatos + retenção.
 *
 * **PT** Envelope v1 — `settings` vem da camada web (localStorage, incluindo
 * a chave de API, pois o arquivo inteiro é cifrado pela senha do usuário);
 * `facts` e `retention` vêm do [com.carsaimz.genyassistant.data.MemoryManager].
 * **EN** Envelope v1 — `settings` comes from the web layer (localStorage,
 * including the API key, since the whole file is passphrase-encrypted);
 * `facts` and `retention` come from [com.carsaimz.genyassistant.data.MemoryManager].
 */
object BackupContent {

    const val VERSION = 1
    const val APP = "geny-assistant"

    /**
     * Monta o envelope v1 a partir do JSON de configurações da web e do
     * envelope de memória produzido por MemoryManager.exportEnvelopeJson.
     */
    fun build(settingsJson: String, memoryEnvelopeJson: String, exportedAtMs: Long): String {
        val settings = JSONObject(settingsJson)
        val memory = JSONObject(memoryEnvelopeJson)
        val envelope = JSONObject()
        envelope.put("version", VERSION)
        envelope.put("app", APP)
        envelope.put("exported_at_ms", exportedAtMs)
        envelope.put("settings", settings)
        envelope.put("facts", memory.optJSONArray("facts") ?: JSONArray())
        memory.optJSONObject("retention")?.let { envelope.put("retention", it) }
        return envelope.toString()
    }

    /** Divide um backup decifrado: (settingsJson, memoryEnvelopeJson). */
    fun split(json: String): Pair<String, String> {
        val envelope = JSONObject(json)
        require(envelope.optInt("version") == VERSION) { "versão de backup desconhecida" }
        val memory = JSONObject()
        memory.put("version", VERSION)
        memory.put("exported_at_ms", envelope.optLong("exported_at_ms"))
        envelope.optJSONObject("retention")?.let { memory.put("retention", it) }
        memory.put("facts", envelope.optJSONArray("facts") ?: JSONArray())
        val settings = envelope.optJSONObject("settings") ?: JSONObject()
        return settings.toString() to memory.toString()
    }
}

/**
 * Aplicação do backup no aparelho (TODO app-04): usa MemoryManager para os
 * fatos e devolve o JSON de configurações para a camada web aplicar no
 * localStorage (fonte de verdade das configurações).
 */
class BackupApplier(private val context: Context) {

    /**
     * Aplica fatos + retenção natively; retorna o settingsJson para a web.
     * @param replaceMemory true substitui a memória inteira (comportamento padrão).
     */
    fun apply(json: String, replaceMemory: Boolean = true): String {
        val (settingsJson, memoryJson) = BackupContent.split(json)
        if (replaceMemory) {
            val memory = com.carsaimz.genyassistant.data.MemoryManager.get(context)
            memory.importEnvelopeJson(memoryJson)
            // A retenção importada só será aplicada nas próximas escritas —
            // não apagamos fatos recém-importados logo na restauração.
        }
        return settingsJson
    }
}
