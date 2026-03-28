import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hello_engine/src/persistence/database/app_database.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Factory for creating an [AppDatabase] instance.
///
/// Native: Uses drift_sqflite + SQLCipher for encrypted storage.
/// Web: Uses drift's WebDatabase (browser-managed IndexedDB).

class DatabaseFactory {
  /// Creates and returns an encrypted [AppDatabase].
  /// Pass [encryptionKey] for SQLCipher on native platforms.
  /// Pass null for web or unencrypted (testing).
  static Future<AppDatabase> create({List<int>? encryptionKey}) async {
    if (kIsWeb) {
      // Web: browser manages encryption via IndexedDB
      return AppDatabase(WebDatabase('chat_engine'));
    }

    // Native: SQLCipher encrypted database
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'hello_engine.db'));

    return AppDatabase(NativeDatabase.createInBackground(
      file,
      setup: (db) {
        if (encryptionKey != null && encryptionKey.isNotEmpty) {
          // Convert key bytes to hex string for PRAGMA key
          final hexKey = encryptionKey
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join();
          db.execute("PRAGMA key = \"x'$hexKey'\";");
          db.execute('PRAGMA cipher_compatibility = 4;');
        }
      },
    ));
  }
}
