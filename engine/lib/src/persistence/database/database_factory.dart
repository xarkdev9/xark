import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:e2ee_chat_sdk/src/persistence/database/app_database.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class DatabaseFactory {
  static Future<AppDatabase> create({List<int>? encryptionKey}) async {
    if (kIsWeb) {
      // Web: browser manages storage via IndexedDB
      return AppDatabase(WebDatabase('e2ee_chat'));
    }

    // Native: encrypted SQLite database
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'e2ee_chat.db'));

    return AppDatabase(NativeDatabase.createInBackground(
      file,
      setup: (db) {
        if (encryptionKey != null && encryptionKey.isNotEmpty) {
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
