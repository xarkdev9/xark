import 'package:chat_engine/src/persistence/database/tables.dart';
import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Central drift database for the chat engine.
///
/// All data is encrypted at rest via SQLCipher. This class is internal —
/// external code accesses data through repository interfaces only.
@DriftDatabase(
  tables: [
    Messages,
    MessageCiphertexts,
    Conversations,
    Receipts,
    OutboxItems,
    RatchetSessions,
    MediaItems,
    UnackedRatchets,
    DecryptedMessages,
    ProcessedDistributions,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Creates an [AppDatabase] with the given query executor.
  AppDatabase(super.e);

  /// Creates an [AppDatabase] for testing with an in-memory executor.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;
}
