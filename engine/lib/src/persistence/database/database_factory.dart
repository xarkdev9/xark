import 'package:e2ee_chat_sdk/src/persistence/database/app_database.dart';

import 'database_factory_stub.dart'
    if (dart.library.io) 'database_factory_native.dart'
    if (dart.library.js_interop) 'database_factory_stub.dart'
    as platform;

class DatabaseFactory {
  static Future<AppDatabase> create({List<int>? encryptionKey}) {
    return platform.createDatabase(encryptionKey: encryptionKey);
  }
}
