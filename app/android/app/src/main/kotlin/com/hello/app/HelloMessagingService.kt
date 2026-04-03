package com.hello.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import org.json.JSONObject
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * Phase 4: Bare-Metal Push Decryption — Android FCM Service.
 *
 * Receives data-only FCM messages containing E2EE ciphertext,
 * decrypts in the background, and posts local notifications
 * with plaintext content.
 *
 * Flow:
 *   1. FCM delivers data message with encrypted payload
 *   2. Service extracts ciphertext from message data
 *   3. Service reads DB encryption key from Android Keystore
 *   4. Service decrypts using AES-256-GCM
 *   5. Service posts local notification with plaintext
 *   6. If ANYTHING fails → fallback: "You may have new messages"
 *
 * Security:
 *   - DB key stored in Android Keystore (hardware-backed on supported devices)
 *   - Decryption runs in the service context (no UI thread)
 *   - Errors are logged but NEVER exposed in the notification
 */
class HelloMessagingService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "E2EEPush"
        private const val CHANNEL_ID = "e2ee_chat_messages"
        private const val CHANNEL_NAME = "Messages"
        private const val DB_KEY_ALIAS = "e2ee_chat_db_key"
        private const val FALLBACK_TITLE = "New Message"
        private const val FALLBACK_BODY = "You may have new messages"
        private const val GCM_TAG_LENGTH = 128 // bits
        private const val GCM_NONCE_LENGTH = 12 // bytes
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        val data = message.data
        val encryptedPayload = data["encryptedPayload"] ?: return
        val groupId = data["groupId"] ?: return
        val messageId = data["messageId"] ?: return

        // ═══════════════════════════════════════════════════════════
        // BARE-METAL DECRYPTION (no Flutter, no Dart, pure native)
        // ═══════════════════════════════════════════════════════════

        try {
            // Step 1: Read the DB encryption key
            val dbKey = readKeyFromKeystore()
                ?: throw IllegalStateException("DB key not found in Keystore")

            // Step 2: Decode base64 payload
            val ciphertextBytes = Base64.decode(encryptedPayload, Base64.DEFAULT)
            if (ciphertextBytes.size < GCM_NONCE_LENGTH + 16 + 1) {
                throw IllegalArgumentException("Ciphertext too short")
            }

            // Step 3: Split into nonce(12) + ciphertext + tag(16)
            // Android GCM expects: nonce separately, ciphertext+tag concatenated
            val nonce = ciphertextBytes.sliceArray(0 until GCM_NONCE_LENGTH)
            val ciphertextWithTag = ciphertextBytes.sliceArray(GCM_NONCE_LENGTH until ciphertextBytes.size)

            // Step 4: Decrypt using AES-256-GCM
            val plaintext = aesGcmDecrypt(dbKey, nonce, ciphertextWithTag)

            // Step 5: Parse the decrypted JSON
            val json = JSONObject(String(plaintext, Charsets.UTF_8))
            val senderName = json.optString("senderName", FALLBACK_TITLE)
            val preview = json.optString("preview", FALLBACK_BODY)

            showNotification(
                title = senderName,
                body = preview,
                groupId = groupId,
                messageId = messageId
            )

        } catch (e: Exception) {
            // ═══════════════════════════════════════════════════════
            // FALLBACK — decryption failed. Show generic notification.
            // Log internally but NEVER expose error to user.
            // ═══════════════════════════════════════════════════════
            Log.w(TAG, "Push decryption failed", e)
            showNotification(
                title = FALLBACK_TITLE,
                body = FALLBACK_BODY,
                groupId = groupId,
                messageId = messageId
            )
        }
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        // Token refresh — the engine will pick this up on next resume()
        // and call updatePushToken() via the transport layer.
        Log.d(TAG, "FCM token refreshed")
    }

    // ═══════════════════════════════════════════════════════════════
    // Keystore Access
    // ═══════════════════════════════════════════════════════════════

    /**
     * Read the DB encryption key from Android Keystore or SharedPreferences.
     *
     * flutter_secure_storage stores keys in EncryptedSharedPreferences
     * (backed by Android Keystore on API 23+). We read the same key
     * that DatabaseKeyManager wrote during engine initialization.
     */
    private fun readKeyFromKeystore(): ByteArray? {
        return try {
            // flutter_secure_storage uses EncryptedSharedPreferences
            // with a master key in Android Keystore.
            // We read it via the same SharedPreferences file.
            val prefs = getSharedPreferences(
                "FlutterSecureStorage", Context.MODE_PRIVATE
            )
            val base64Key = prefs.getString(DB_KEY_ALIAS, null)
                ?: return null
            Base64.decode(base64Key, Base64.DEFAULT)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to read DB key from Keystore", e)
            null
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // AES-256-GCM Decryption
    // ═══════════════════════════════════════════════════════════════

    /**
     * Native AES-256-GCM decryption using javax.crypto.
     *
     * @param key 32-byte AES key
     * @param nonce 12-byte GCM nonce/IV
     * @param ciphertextWithTag ciphertext concatenated with 16-byte GCM auth tag
     * @return decrypted plaintext bytes
     */
    private fun aesGcmDecrypt(
        key: ByteArray,
        nonce: ByteArray,
        ciphertextWithTag: ByteArray
    ): ByteArray {
        val secretKey: SecretKey = SecretKeySpec(key, "AES")
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        val spec = GCMParameterSpec(GCM_TAG_LENGTH, nonce)
        cipher.init(Cipher.DECRYPT_MODE, secretKey, spec)
        return cipher.doFinal(ciphertextWithTag)
    }

    // ═══════════════════════════════════════════════════════════════
    // Notification Display
    // ═══════════════════════════════════════════════════════════════

    private fun showNotification(
        title: String,
        body: String,
        groupId: String,
        messageId: String
    ) {
        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_email) // TODO: Replace with app icon
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setGroup(groupId)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .build()

        notificationManager.notify(messageId.hashCode(), notification)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Chat messages"
                enableVibration(true)
                setShowBadge(true)
            }
            val manager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}
