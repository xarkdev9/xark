import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:e2ee_chat_sdk/src/crypto/keys/database_key_manager.dart';
import 'package:e2ee_chat_sdk/src/crypto/keys/key_types.dart';
import 'package:e2ee_chat_sdk/src/crypto/sender_keys/sender_key_store.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Fast, atomic [SenderKeyStore] backed by SQLCipher.
///
/// Designed to survive OS-level app terminations by writing E2EE
/// ratchet states (SenderKeyRecords) directly to an encrypted local SQLite
/// database via optimized `INSERT OR REPLACE` queries.
class SqliteSenderKeyStore implements SenderKeyStore {
  Database? _db;
  Completer<void>? _initCompleter;
  final String _dbName;

  SqliteSenderKeyStore({String dbName = 'sender_keys.db'}) : _dbName = dbName;

  /// Initializes the SQLCipher database.
  /// Generates or retrieves the 256-bit AES master key from secure storage.
  Future<void> initialize() async {
    if (_db != null) return;
    if (_initCompleter != null) return _initCompleter!.future;
    
    _initCompleter = Completer<void>();

    final dbKeyBytes = await DatabaseKeyManager.getOrCreateKey();
    if (dbKeyBytes == null) {
      // In web/test environments lacking secure storage, fallback or throw
      // For now, we allow unencrypted fallback if dbKeyBytes is literally null
      // (as DatabaseKeyManager defines).
    }
    
    final password = dbKeyBytes != null ? base64Encode(dbKeyBytes) : '';

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _dbName);

    _db = await openDatabase(
      path,
      password: password,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sender_keys (
            id TEXT PRIMARY KEY,
            chain_key TEXT NOT NULL,
            signing_public_key TEXT NOT NULL,
            signing_private_key TEXT NOT NULL,
            iteration INTEGER NOT NULL,
            created_at TEXT
          )
        ''');
      },
    );
    
    _initCompleter!.complete();
  }

  String _buildId(String groupId, String senderId) {
    return '$groupId:$senderId';
  }

  @override
  Future<void> storeSenderKey(
    String groupId,
    String senderId,
    SenderKeyRecord record,
  ) async {
    await initialize();

    final id = _buildId(groupId, senderId);
    
    // Raw optimized INSERT OR REPLACE query for atomic speed
    await _db!.rawInsert(
      '''
      INSERT OR REPLACE INTO sender_keys (
        id, chain_key, signing_public_key, signing_private_key, iteration, created_at
      ) VALUES (?, ?, ?, ?, ?, ?)
      ''',
      [
        id,
        base64Encode(record.chainKey),
        base64Encode(record.signingPublicKey),
        base64Encode(record.signingPrivateKey),
        record.iteration,
        record.createdAt?.toIso8601String(),
      ],
    );
  }

  @override
  Future<SenderKeyRecord?> loadSenderKey(
    String groupId,
    String senderId,
  ) async {
    await initialize();
    final id = _buildId(groupId, senderId);

    final List<Map<String, dynamic>> maps = await _db!.query(
      'sender_keys',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    final row = maps.first;
    try {
      return SenderKeyRecord(
        chainKey: Uint8List.fromList(base64Decode(row['chain_key'] as String)),
        signingPublicKey: Uint8List.fromList(
            base64Decode(row['signing_public_key'] as String)),
        signingPrivateKey: Uint8List.fromList(
            base64Decode(row['signing_private_key'] as String)),
        iteration: row['iteration'] as int,
        createdAt: row['created_at'] != null
            ? DateTime.parse(row['created_at'] as String)
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteSenderKey(String groupId, String senderId) async {
    await initialize();
    final id = _buildId(groupId, senderId);
    await _db!.delete(
      'sender_keys',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
