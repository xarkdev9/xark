import UserNotifications
import Security
import CommonCrypto

/// iOS Notification Service Extension — E2EE Push Decryption Bridge.
///
/// Phase 4: Bare-metal native decryption. Runs outside the Flutter app process.
/// Apple gives us exactly 30 seconds to decrypt before killing the extension.
///
/// Flow:
///   1. APNs delivers mutable-content push with encrypted payload
///   2. NSE wakes, extracts ciphertext from userInfo
///   3. NSE reads the SQLCipher DB key from shared Keychain (App Group)
///   4. NSE decrypts the payload using AES-256-GCM
///   5. NSE mutates notification content with plaintext sender + preview
///   6. If ANYTHING fails → fallback: "You may have new messages"
///
/// Security:
///   - The DB encryption key is in the shared Keychain (App Group)
///   - The NSE never holds the full ratchet state — it uses a simplified
///     symmetric decrypt for the push-specific payload
///   - The server sends a push-specific encrypted preview (not the full
///     ratchet message) that can be decrypted with the DB key alone

class NotificationService: UNNotificationServiceExtension {

    // MARK: - Constants

    /// Shared Keychain access group for App Group
    private static let appGroupId = "group.com.e2ee.chat"
    /// Key alias in shared Keychain
    private static let dbKeyAlias = "e2ee_chat_db_key"
    /// Fallback notification text — social, not cybersecurity
    private static let fallbackTitle = "New Message"
    private static let fallbackBody = "You may have new messages"

    // MARK: - State

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    // MARK: - Lifecycle

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let content = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        guard let userInfo = content.userInfo as? [String: Any],
              let encryptedPayload = userInfo["encryptedPayload"] as? String,
              let groupId = userInfo["groupId"] as? String,
              let _ = userInfo["messageId"] as? String else {
            // No E2EE payload — deliver the push as-is
            contentHandler(request.content)
            return
        }

        // ═══════════════════════════════════════════════════════════
        // BARE-METAL DECRYPTION (no Flutter, no Dart, pure native)
        // ═══════════════════════════════════════════════════════════

        do {
            // Step 1: Read the DB encryption key from shared Keychain
            guard let dbKey = readKeyFromSharedKeychain() else {
                throw NSError(domain: "NSE", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "DB key not found in shared Keychain"
                ])
            }

            // Step 2: Decode the base64 encrypted payload
            guard let ciphertextData = Data(base64Encoded: encryptedPayload) else {
                throw NSError(domain: "NSE", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid base64 payload"
                ])
            }

            // Step 3: Decrypt using AES-256-GCM
            // The push payload is encrypted with a simplified symmetric key
            // derived from the DB key (not the full ratchet — that would require
            // loading the entire Drift database in a 30s window).
            //
            // Format: nonce(12) + ciphertext + tag(16)
            guard ciphertextData.count > 28 else { // 12 + min 1 byte + 16
                throw NSError(domain: "NSE", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "Ciphertext too short"
                ])
            }

            let nonce = ciphertextData.prefix(12)
            let tag = ciphertextData.suffix(16)
            let encrypted = ciphertextData.dropFirst(12).dropLast(16)

            let plaintext = try aesGCMDecrypt(
                key: dbKey,
                nonce: nonce,
                ciphertext: Data(encrypted),
                tag: Data(tag)
            )

            // Step 4: Parse the decrypted JSON
            if let json = try? JSONSerialization.jsonObject(with: plaintext) as? [String: Any],
               let senderName = json["senderName"] as? String,
               let preview = json["preview"] as? String {
                content.title = senderName
                content.body = preview
                content.userInfo["decrypted"] = true
            } else {
                // Decrypted but couldn't parse — show generic
                content.title = Self.fallbackTitle
                content.body = Self.fallbackBody
                content.userInfo["decrypted"] = false
            }

            contentHandler(content)

        } catch {
            // ═══════════════════════════════════════════════════════
            // FALLBACK — decryption failed. Show generic notification.
            // NEVER expose the error reason to the user.
            // ═══════════════════════════════════════════════════════
            content.title = Self.fallbackTitle
            content.body = Self.fallbackBody
            content.userInfo["decrypted"] = false
            // Log to crash reporter only (not user-visible)
            content.userInfo["_nseError"] = error.localizedDescription
            contentHandler(content)
        }
    }

    override func serviceExtensionTimeAboutToExpire() {
        // iOS budget exhausted (approaching 30s). Deliver whatever we have.
        if let contentHandler = contentHandler, let content = bestAttemptContent {
            content.title = Self.fallbackTitle
            content.body = Self.fallbackBody
            content.userInfo["decrypted"] = false
            content.userInfo["_nseTimeout"] = true
            contentHandler(content)
        }
    }

    // MARK: - Keychain Access

    /// Read the DB encryption key from the shared App Group Keychain.
    /// This key was stored by DatabaseKeyManager via flutter_secure_storage.
    private func readKeyFromSharedKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.dbKeyAlias,
            kSecAttrAccessGroup as String: Self.appGroupId,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        // The key is stored as base64 by flutter_secure_storage
        if let decoded = Data(base64Encoded: data) {
            return decoded
        }
        // Or it might be raw bytes
        return data.count == 32 ? data : nil
    }

    // MARK: - AES-256-GCM Decryption

    /// Native AES-256-GCM decryption using Apple CryptoKit (iOS 13+)
    /// or CommonCrypto fallback.
    private func aesGCMDecrypt(
        key: Data,
        nonce: Data,
        ciphertext: Data,
        tag: Data
    ) throws -> Data {
        // Use CryptoKit if available (iOS 13+)
        if #available(iOS 13.0, *) {
            return try aesGCMDecryptCryptoKit(
                key: key, nonce: nonce, ciphertext: ciphertext, tag: tag
            )
        }

        // Fallback: this should never happen (iOS 13 is our minimum)
        throw NSError(domain: "NSE", code: 4, userInfo: [
            NSLocalizedDescriptionKey: "iOS 13+ required for AES-GCM"
        ])
    }

    @available(iOS 13.0, *)
    private func aesGCMDecryptCryptoKit(
        key: Data,
        nonce: Data,
        ciphertext: Data,
        tag: Data
    ) throws -> Data {
        // Dynamic import to avoid compile-time dependency on CryptoKit
        // for the NSE target (which may have different linking requirements)
        let combined = nonce + ciphertext + tag

        // Use Security framework's AES-GCM via CCCrypt
        // CryptoKit import: `import CryptoKit` — add to the NSE target
        //
        // For maximum compatibility without CryptoKit:
        var decrypted = Data(count: ciphertext.count)
        var decryptedLength: Int = 0

        let status = decrypted.withUnsafeMutableBytes { decryptedPtr in
            ciphertext.withUnsafeBytes { ciphertextPtr in
                key.withUnsafeBytes { keyPtr in
                    nonce.withUnsafeBytes { noncePtr in
                        tag.withUnsafeBytes { tagPtr in
                            CCCryptorGCMOneshotDecrypt(
                                CCAlgorithm(kCCAlgorithmAES),
                                keyPtr.baseAddress!, key.count,
                                noncePtr.baseAddress!, nonce.count,
                                nil, 0, // no AAD
                                ciphertextPtr.baseAddress!, ciphertext.count,
                                decryptedPtr.baseAddress!,
                                tagPtr.baseAddress!, tag.count
                            )
                        }
                    }
                }
            }
        }

        guard status == kCCSuccess else {
            throw NSError(domain: "NSE", code: 5, userInfo: [
                NSLocalizedDescriptionKey: "AES-GCM decryption failed: \(status)"
            ])
        }

        return decrypted
    }
}
