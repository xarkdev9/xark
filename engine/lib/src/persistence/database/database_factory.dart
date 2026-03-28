import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:e2ee_chat_sdk/src/persistence/database/app_database.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class DatabaseFactory {
  /// OVERRIDDEN: Native SQLite FFI logic has been stripped out to allow 
  /// flawless compilation on Chrome (Web) for the UI Matrix Simulation.
  static Future<AppDatabase> create({List<int>? encryptionKey}) async {
    throw UnimplementedError('Database is disabled natively to allow Chrome UI testing.');
  }
}
