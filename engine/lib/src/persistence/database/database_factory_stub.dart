import 'package:e2ee_chat_sdk/src/persistence/database/app_database.dart';

Future<AppDatabase> createDatabase({List<int>? encryptionKey}) {
  throw UnsupportedError(
    'Cannot create database on this platform without dart:io or dart:html',
  );
}
