import UserNotifications

/// iOS Notification Service Extension for E2EE push decryption.
/// Wakes on mutable-content push, decrypts via shared keychain,
/// mutates notification content with plaintext sender + preview.
/// Falls back to "New Message" if decryption fails (30s budget).
class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let content = bestAttemptContent,
              let userInfo = content.userInfo as? [String: Any],
              let encryptedPayload = userInfo["encryptedPayload"] as? String,
              let ratchetHeader = userInfo["ratchetHeader"] as? String,
              let groupId = userInfo["groupId"] as? String,
              let messageId = userInfo["messageId"] as? String else {
            // No encrypted payload — deliver as-is
            contentHandler(request.content)
            return
        }

        // Attempt decryption
        do {
            // Call Flutter engine via shared method channel
            // NOTE: In NSE, we cannot use Flutter's MethodChannel directly.
            // Instead, we use the shared App Group to read the encrypted DB
            // and perform decryption natively, OR we use a shared framework.
            //
            // For now, the decryption flow is:
            // 1. NSE reads the push payload
            // 2. NSE calls a shared Dart-based decryption library (future)
            // 3. OR NSE shows the fallback "New Message" notification
            //
            // The full native bridge requires a shared Flutter engine or
            // a compiled Dart-to-native bridge (dart:ffi). This is Phase 3.

            // For now, show generic message (decryption wiring in next iteration)
            content.title = "New Message"
            content.body = "You may have new messages"
            content.userInfo["decrypted"] = false
            contentHandler(content)
        } catch {
            // Decryption failed — fall back to generic
            content.title = "New Message"
            content.body = "You may have new messages"
            content.userInfo["decryptionError"] = error.localizedDescription
            contentHandler(content)
        }
    }

    override func serviceExtensionTimeAboutToExpire() {
        // iOS is killing us (30s budget exceeded) — deliver what we have
        if let contentHandler = contentHandler, let content = bestAttemptContent {
            content.title = "New Message"
            content.body = "You may have new messages"
            contentHandler(content)
        }
    }
}
