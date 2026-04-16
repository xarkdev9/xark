import 'package:e2ee_chat_sdk/src/persistence/database/app_database.dart';
import 'package:e2ee_chat_sdk/src/persistence/repositories/decrypted_message_repository.dart';
import 'package:drift/drift.dart';

/// Drift-backed implementation of [DecryptedMessageRepository].
///
/// The plaintext cache stores decrypted message content so the ratchet
/// does not need to re-decrypt on every read. Entries can be evicted
/// by age to manage storage.
class DecryptedMessageRepositoryImpl
    implements DecryptedMessageRepository {
  /// Creates a [DecryptedMessageRepositoryImpl] backed by the given database.
  DecryptedMessageRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<void> cachePlaintext(
    String messageId,
    String plaintext, {
    String? mediaJson,
  }) async {
    await _db.into(_db.decryptedMessages).insertOnConflictUpdate(
          DecryptedMessageRow(
            messageId: messageId,
            plaintext: plaintext,
            mediaJson: mediaJson,
            cachedAt: DateTime.now(),
          ),
        );
  }

  @override
  Future<String?> getCachedPlaintext(String messageId) async {
    final query = _db.select(_db.decryptedMessages)
      ..where((t) => t.messageId.equals(messageId));
    final row = await query.getSingleOrNull();
    return row?.plaintext;
  }

  @override
  Future<String?> getCachedMediaJson(String messageId) async {
    final query = _db.select(_db.decryptedMessages)
      ..where((t) => t.messageId.equals(messageId));
    final row = await query.getSingleOrNull();
    return row?.mediaJson;
  }

  @override
  Future<void> expireOlderThan(Duration maxAge) async {
    final cutoff = DateTime.now().subtract(maxAge);
    await (_db.delete(_db.decryptedMessages)
          ..where((t) => t.cachedAt.isSmallerThanValue(cutoff)))
        .go();
  }
}
