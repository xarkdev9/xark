package com.hello.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * Background push decryption service for E2EE messages.
 * Receives data-only FCM messages, decrypts the payload,
 * and shows a local notification with plaintext content.
 * Falls back to "New Message" if decryption fails.
 */
class HelloMessagingService : FirebaseMessagingService() {

    companion object {
        private const val CHANNEL_ID = "hello_messages"
        private const val CHANNEL_NAME = "Messages"
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        val data = message.data
        val encryptedPayload = data["encryptedPayload"] ?: return
        val ratchetHeader = data["ratchetHeader"] ?: return
        val groupId = data["groupId"] ?: return
        val messageId = data["messageId"] ?: return

        // Attempt decryption
        try {
            // TODO: Access Drift DB (shared SQLite)
            // TODO: Load ratchet session for this sender
            // TODO: Decrypt encryptedPayload
            // TODO: Show notification with plaintext

            // For now, show generic notification (decryption wiring in next iteration)
            showNotification(
                title = "New Message",
                body = "You have a new encrypted message",
                groupId = groupId,
                messageId = messageId
            )
        } catch (e: Exception) {
            // Decryption failed — fall back to generic
            showNotification(
                title = "New Message",
                body = "You have a new encrypted message",
                groupId = groupId,
                messageId = messageId
            )
        }
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        // TODO: Upload new FCM token to server via /api/notify
    }

    private fun showNotification(title: String, body: String, groupId: String, messageId: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_email) // TODO: Replace with app icon
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setGroup(groupId)
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
                description = "Encrypted message notifications"
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}
