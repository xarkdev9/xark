import Flutter
import Security

/// Flutter method channel plugin for Secure Enclave key wrapping.
///
/// Phase 4: Full hardware key storage implementation.
/// Generates a P-256 key pair inside the Secure Enclave.
/// Uses ECIES (Elliptic Curve Integrated Encryption Scheme) to
/// wrap/unwrap the Ed25519 identity key material.
///
/// The private key NEVER leaves the Secure Enclave — all crypto
/// operations happen inside the hardware security module.
///
/// Fallback: On devices without Secure Enclave (simulator, old devices),
/// falls back to Keychain-stored software key.

public class SecureEnclavePlugin: NSObject, FlutterPlugin {

    private static let keyTag = "com.e2ee_chat.se_wrapping_key"
    private static let keychainGroup = "group.com.e2ee.chat"

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.e2ee_chat.secure_enclave",
            binaryMessenger: registrar.messenger()
        )
        let instance = SecureEnclavePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            result(isSecureEnclaveAvailable())

        case "wrap":
            guard let args = call.arguments as? [String: Any],
                  let data = args["data"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing 'data'", details: nil))
                return
            }
            wrapData(data.data, result: result)

        case "unwrap":
            guard let args = call.arguments as? [String: Any],
                  let data = args["data"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing 'data'", details: nil))
                return
            }
            unwrapData(data.data, result: result)

        case "deleteKey":
            deleteWrappingKey(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Secure Enclave Detection

    private func isSecureEnclaveAvailable() -> Bool {
        if #available(iOS 13.0, *) {
            var error: Unmanaged<CFError>?
            let attributes: [String: Any] = [
                kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                kSecAttrKeySizeInBits as String: 256,
                kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
                kSecPrivateKeyAttrs as String: [
                    kSecAttrIsPermanent as String: false,
                ],
            ]
            guard let testKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
                return false
            }
            // Key created successfully — Secure Enclave is available
            // Delete the test key (it was non-permanent)
            _ = testKey // ARC will handle cleanup
            return true
        }
        return false
    }

    // MARK: - Key Management

    /// Get or create the Secure Enclave P-256 key pair.
    /// The private key lives inside the Secure Enclave and never leaves.
    private func getOrCreateWrappingKey() -> SecKey? {
        // Try to load existing key
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: Self.keyTag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecSuccess, let key = item {
            return (key as! SecKey)
        }

        // Create new key in Secure Enclave
        var error: Unmanaged<CFError>?
        let useSecureEnclave = isSecureEnclaveAvailable()

        var attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: Self.keyTag.data(using: .utf8)!,
            ] as [String: Any],
        ]

        if useSecureEnclave {
            attributes[kSecAttrTokenID as String] = kSecAttrTokenIDSecureEnclave
        }

        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            return nil
        }

        return privateKey
    }

    // MARK: - Wrap (Encrypt with SE public key)

    /// Wrap data using the Secure Enclave's public key (ECIES).
    /// The plaintext is encrypted with the SE public key — only the
    /// SE private key (which never leaves hardware) can decrypt it.
    private func wrapData(_ plaintext: Data, result: @escaping FlutterResult) {
        guard let privateKey = getOrCreateWrappingKey(),
              let publicKey = SecKeyCopyPublicKey(privateKey) else {
            result(FlutterError(
                code: "KEY_ERROR",
                message: "Failed to access Secure Enclave key",
                details: nil
            ))
            return
        }

        var error: Unmanaged<CFError>?
        guard let encrypted = SecKeyCreateEncryptedData(
            publicKey,
            .eciesEncryptionCofactorVariableIVX963SHA256AESGCM,
            plaintext as CFData,
            &error
        ) else {
            result(FlutterError(
                code: "WRAP_FAILED",
                message: "ECIES encryption failed: \(error?.takeRetainedValue().localizedDescription ?? "unknown")",
                details: nil
            ))
            return
        }

        result(FlutterStandardTypedData(bytes: encrypted as Data))
    }

    // MARK: - Unwrap (Decrypt with SE private key)

    /// Unwrap data using the Secure Enclave's private key (ECIES).
    /// The private key operation runs inside the Secure Enclave hardware.
    private func unwrapData(_ ciphertext: Data, result: @escaping FlutterResult) {
        guard let privateKey = getOrCreateWrappingKey() else {
            result(FlutterError(
                code: "KEY_ERROR",
                message: "Failed to access Secure Enclave key",
                details: nil
            ))
            return
        }

        var error: Unmanaged<CFError>?
        guard let decrypted = SecKeyCreateDecryptedData(
            privateKey,
            .eciesEncryptionCofactorVariableIVX963SHA256AESGCM,
            ciphertext as CFData,
            &error
        ) else {
            result(FlutterError(
                code: "UNWRAP_FAILED",
                message: "ECIES decryption failed: \(error?.takeRetainedValue().localizedDescription ?? "unknown")",
                details: nil
            ))
            return
        }

        result(FlutterStandardTypedData(bytes: decrypted as Data))
    }

    // MARK: - Delete

    /// Delete the wrapping key from Secure Enclave / Keychain.
    /// Used during factory reset or account deletion.
    private func deleteWrappingKey(result: @escaping FlutterResult) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: Self.keyTag.data(using: .utf8)!,
        ]
        SecItemDelete(query as CFDictionary)
        result(nil)
    }
}
