import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:e2ee_chat_sdk/src/persistence/database/app_database.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

Future<AppDatabase> createDatabase({List<int>? encryptionKey}) async {
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
