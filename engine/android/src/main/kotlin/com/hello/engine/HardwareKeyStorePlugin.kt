package com.hello.engine

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Phase 4: Hardware Key Store Plugin — Android Keystore integration.
 *
 * Generates a non-extractable AES-256 wrapping key inside the Android
 * Keystore (backed by TEE or StrongBox on supported hardware).
 * The wrapping key never leaves the hardware security module.
 */
class HardwareKeyStorePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel

    companion object {
        private const val KEY_ALIAS = "com.e2ee_chat.identity_wrapping_key"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val GCM_TAG_LENGTH = 128
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.e2ee_chat.hardware_keystore")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(isHardwareKeystoreAvailable())
            "wrap" -> {
                val data = call.argument<ByteArray>("data")
                    ?: return result.error("INVALID_ARGS", "Missing 'data'", null)
                wrapData(data, result)
            }
            "unwrap" -> {
                val data = call.argument<ByteArray>("data")
                    ?: return result.error("INVALID_ARGS", "Missing 'data'", null)
                unwrapData(data, result)
            }
            "deleteKey" -> {
                deleteWrappingKey()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun isHardwareKeystoreAvailable(): Boolean {
        return try {
            val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE)
            keyStore.load(null)
            true
        } catch (e: Exception) { false }
    }

    private fun getOrCreateWrappingKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE)
        keyStore.load(null)
        val existing = keyStore.getKey(KEY_ALIAS, null) as? SecretKey
        if (existing != null) return existing

        val builder = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        ).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
         .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
         .setKeySize(256)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try { builder.setIsStrongBoxBacked(true) } catch (_: Exception) {}
        }

        val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        gen.init(builder.build())
        return gen.generateKey()
    }

    private fun wrapData(plaintext: ByteArray, result: MethodChannel.Result) {
        try {
            val key = getOrCreateWrappingKey()
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, key)
            val iv = cipher.iv
            val ct = cipher.doFinal(plaintext)
            val output = ByteArray(iv.size + ct.size)
            System.arraycopy(iv, 0, output, 0, iv.size)
            System.arraycopy(ct, 0, output, iv.size, ct.size)
            result.success(output)
        } catch (e: Exception) {
            result.error("WRAP_FAILED", "Hardware wrap failed: ${e.message}", null)
        }
    }

    private fun unwrapData(wrapped: ByteArray, result: MethodChannel.Result) {
        try {
            if (wrapped.size < 29) return result.error("INVALID_DATA", "Too short", null)
            val key = getOrCreateWrappingKey()
            val iv = wrapped.sliceArray(0 until 12)
            val ct = wrapped.sliceArray(12 until wrapped.size)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(GCM_TAG_LENGTH, iv))
            result.success(cipher.doFinal(ct))
        } catch (e: Exception) {
            result.error("UNWRAP_FAILED", "Hardware unwrap failed: ${e.message}", null)
        }
    }

    private fun deleteWrappingKey() {
        try {
            val ks = KeyStore.getInstance(ANDROID_KEYSTORE)
            ks.load(null)
            ks.deleteEntry(KEY_ALIAS)
        } catch (_: Exception) {}
    }
}
