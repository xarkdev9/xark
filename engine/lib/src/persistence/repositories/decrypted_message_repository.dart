/// Abstract repository for the client-side plaintext cache.
///
/// Stores decrypted message content so that the ratchet does not need to
/// re-decrypt on every read. Entries are evictable by age.
abstract class DecryptedMessageRepository {
  /// Caches decrypted plaintext (and optional media JSON) for a message.
  Future<void> cachePlaintext(
    String messageId,
    String plaintext, {
    String? mediaJson,
  });

  /// Returns the cached plaintext for a message, or null if not cached.
  Future<String?> getCachedPlaintext(String messageId);

  /// Returns the cached media JSON for a message, or null if not cached.
  Future<String?> getCachedMediaJson(String messageId);

  /// Removes cache entries older than [maxAge].
  Future<void> expireOlderThan(Duration maxAge);
}
