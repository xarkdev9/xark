package com.hello.engine

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.KeyGenerator

class HardwareKeyStorePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private val keyAlias = "com.hello.identity_wrapping_key"

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.hello.hardware_keystore")
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
                    ?: return result.error("INVALID_ARGS", "Missing data", null)
                // TODO: Implement AES-GCM wrap using Android Keystore key
                result.error("NOT_IMPLEMENTED", "Hardware wrapping not yet wired", null)
            }
            "unwrap" -> {
                val data = call.argument<ByteArray>("data")
                    ?: return result.error("INVALID_ARGS", "Missing data", null)
                // TODO: Implement AES-GCM unwrap using Android Keystore key
                result.error("NOT_IMPLEMENTED", "Hardware unwrapping not yet wired", null)
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
            val keyStore = KeyStore.getInstance("AndroidKeyStore")
            keyStore.load(null)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun deleteWrappingKey() {
        try {
            val keyStore = KeyStore.getInstance("AndroidKeyStore")
            keyStore.load(null)
            keyStore.deleteEntry(keyAlias)
        } catch (_: Exception) {}
    }
}
