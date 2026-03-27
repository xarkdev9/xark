import Flutter
import Security

/// Flutter method channel plugin for Secure Enclave key wrapping.
/// Generates an AES wrapping key inside the Secure Enclave (or TEE fallback).
/// The wrapping key never leaves the secure hardware.
public class SecureEnclavePlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.hello.secure_enclave",
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
                result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
                return
            }
            wrap(data: data.data, result: result)
        case "unwrap":
            guard let args = call.arguments as? [String: Any],
                  let data = args["data"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
                return
            }
            unwrap(data: data.data, result: result)
        case "deleteKey":
            deleteWrappingKey(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func isSecureEnclaveAvailable() -> Bool {
        // Check for Secure Enclave (A7+ chips, iPhone 5s+)
        var error: Unmanaged<CFError>?
        guard let _ = SecKeyCreateRandomKey([
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits: 256,
            kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs: [kSecAttrIsPermanent: false]
        ] as CFDictionary, &error) else {
            return false
        }
        return true
    }

    // TODO: Implement wrap/unwrap using Secure Enclave P-256 key
    // For now, return stub errors
    private func wrap(data: Data, result: FlutterResult) {
        result(FlutterError(
            code: "NOT_IMPLEMENTED",
            message: "Secure Enclave wrapping not yet wired",
            details: nil
        ))
    }

    private func unwrap(data: Data, result: FlutterResult) {
        result(FlutterError(
            code: "NOT_IMPLEMENTED",
            message: "Secure Enclave unwrapping not yet wired",
            details: nil
        ))
    }

    private func deleteWrappingKey(result: FlutterResult) {
        result(nil)
    }
}
