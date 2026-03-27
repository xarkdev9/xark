// ignore_for_file: deprecated_member_use

import 'package:chat_engine/src/persistence/database/app_database.dart';
import 'package:drift/web.dart';

/// Factory for creating an [AppDatabase] instance.
///
/// Uses drift's WebDatabase for browser environments.
/// Native SQLCipher encryption is a Phase 2 target.
class DatabaseFactory {
  /// Creates and returns an [AppDatabase].
  static Future<AppDatabase> create() async {
    return AppDatabase(WebDatabase('chat_engine'));
  }
}
