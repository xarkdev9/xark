/// Optional biometric/PIN app lock.
/// This is a UI-layer concern — the engine exposes the utility,
/// the UI decides when to call it.
///
/// IMPORTANT: This does NOT affect database encryption.
/// The database is ALWAYS encrypted with the Keychain key.
/// Biometric lock is an optional UI gate on top.

class AppLockManager {
  /// Check if biometric authentication is available.
  static Future<bool> isBiometricAvailable() async {
    try {
      // Placeholder — requires local_auth package
      // final auth = LocalAuthentication();
      // return await auth.canCheckBiometrics;
      return false; // Will be wired when local_auth is added
    } catch (_) {
      return false;
    }
  }

  /// Prompt for biometric authentication.
  /// Returns true if authenticated, false if denied/unavailable.
  static Future<bool> authenticate({String reason = 'Unlock hello'}) async {
    try {
      // Placeholder — requires local_auth package
      // final auth = LocalAuthentication();
      // return await auth.authenticate(localizedReason: reason);
      return true; // Default: unlocked (biometric is optional)
    } catch (_) {
      return true; // Failure = allow access (biometric is optional)
    }
  }
}
