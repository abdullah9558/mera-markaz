package pk.pakpocket.pakpocket

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import java.security.SecureRandom
import java.security.MessageDigest
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterFragmentActivity() {
    private companion object {
        const val CHANNEL = "pk.pakpocket.pakpocket/security_key"
        const val WIDGET_CHANNEL = "pk.pakpocket.pakpocket/widgets"
        const val KEYSTORE = "AndroidKeyStore"
        const val TAG_BITS = 128
        const val TAG_BYTES = 16
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "wrapKey" -> result.success(wrapKey(call))
                        "unwrapKey" -> result.success(unwrapKey(call))
                        "containsKey" -> result.success(keyStore().containsAlias(alias(call)))
                        "deleteKey" -> {
                            keyStore().deleteEntry(alias(call))
                            result.success(null)
                        }
                        "runSelfTest" -> result.success(runSelfTest())
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    // Never include key bytes, plaintext, or provider exception details.
                    result.error("KEYSTORE_OPERATION_FAILED", "Secure key operation failed.", null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    val preferences = getSharedPreferences("mera_markaz_widgets", MODE_PRIVATE)
                    if (call.method == "load") {
                        result.success(mapOf(
                            "privacy" to preferences.getString("privacy", "hidden"),
                            "theme" to preferences.getString("theme", "system"),
                            "insight" to preferences.getString("insight", "safe_to_spend"),
                            "market" to preferences.getString("market", "usd_pkr"),
                            "quickActions" to preferences.getString("quickActions", "expense,udhaar,savings"),
                        ))
                        return@setMethodCallHandler
                    }
                    val values = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                    val editor = preferences.edit()
                    values.forEach { (rawKey, rawValue) ->
                        val key = rawKey as? String ?: return@forEach
                        when (rawValue) {
                            is Number -> editor.putFloat(key, rawValue.toFloat())
                            is String -> editor.putString(key, rawValue)
                            is Map<*, *> -> rawValue.forEach { (marketKey, marketValue) ->
                                if (marketKey is String && marketValue is String) {
                                    editor.putString("market_$marketKey", marketValue)
                                }
                            }
                        }
                    }
                    editor.apply()
                    MeraMarkazWidgets.updateAll(this)
                    result.success(null)
                } catch (_: Exception) {
                    result.error("WIDGET_UPDATE_FAILED", "Widget settings could not be updated.", null)
                }
            }
    }

    private fun wrapKey(call: MethodCall): Map<String, ByteArray> {
        val alias = alias(call)
        val plaintext = bytes(call, "plaintext")
        val aad = bytes(call, "aad")
        require(plaintext.size == 32) { "Invalid key size" }

        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateWrappingKey(alias))
        cipher.updateAAD(aad)
        val sealed = cipher.doFinal(plaintext)
        require(sealed.size >= TAG_BYTES)
        return mapOf(
            "nonce" to cipher.iv,
            "ciphertext" to sealed.copyOfRange(0, sealed.size - TAG_BYTES),
            "tag" to sealed.copyOfRange(sealed.size - TAG_BYTES, sealed.size),
        )
    }

    private fun unwrapKey(call: MethodCall): ByteArray {
        val alias = alias(call)
        val nonce = bytes(call, "nonce")
        val ciphertext = bytes(call, "ciphertext")
        val tag = bytes(call, "tag")
        val aad = bytes(call, "aad")
        require(nonce.size == 12 && tag.size == TAG_BYTES)
        val key = keyStore().getKey(alias, null) as? SecretKey
            ?: throw IllegalStateException("Wrapping key unavailable")
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(TAG_BITS, nonce))
        cipher.updateAAD(aad)
        return cipher.doFinal(ciphertext + tag).also {
            require(it.size == 32) { "Invalid unwrapped key size" }
        }
    }

    private fun getOrCreateWrappingKey(alias: String): SecretKey {
        val existing = keyStore().getKey(alias, null) as? SecretKey
        if (existing != null) return existing
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE)
        val parameters = KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setRandomizedEncryptionRequired(true)
            .build()
        generator.init(parameters)
        return generator.generateKey()
    }

    private fun runSelfTest(): Boolean {
        val random = SecureRandom()
        val suffix = ByteArray(18).also(random::nextBytes)
            .joinToString("") { "%02x".format(it) }
        val temporaryAlias = "mm_${suffix.take(32)}"
        val plaintext = ByteArray(32).also(random::nextBytes)
        val aad = "mera-markaz-keystore-self-test-v1".toByteArray()
        return try {
            val encryption = Cipher.getInstance("AES/GCM/NoPadding")
            encryption.init(Cipher.ENCRYPT_MODE, getOrCreateWrappingKey(temporaryAlias))
            encryption.updateAAD(aad)
            val sealed = encryption.doFinal(plaintext)

            val decryption = Cipher.getInstance("AES/GCM/NoPadding")
            val key = keyStore().getKey(temporaryAlias, null) as SecretKey
            decryption.init(
                Cipher.DECRYPT_MODE,
                key,
                GCMParameterSpec(TAG_BITS, encryption.iv),
            )
            decryption.updateAAD(aad)
            val clear = decryption.doFinal(sealed)
            MessageDigest.isEqual(plaintext, clear)
        } finally {
            plaintext.fill(0)
            keyStore().deleteEntry(temporaryAlias)
        }
    }

    private fun keyStore(): KeyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }

    private fun alias(call: MethodCall): String {
        val value = call.argument<String>("alias") ?: throw IllegalArgumentException("Missing alias")
        require(value.matches(Regex("mm_[A-Za-z0-9_-]{20,40}"))) { "Invalid alias" }
        return value
    }

    private fun bytes(call: MethodCall, name: String): ByteArray =
        call.argument<ByteArray>(name) ?: throw IllegalArgumentException("Missing $name")
}
