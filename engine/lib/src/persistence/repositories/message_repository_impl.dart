import 'dart:convert';

import 'package:hello_engine/src/domain/models/message.dart';
import 'package:hello_engine/src/domain/repositories/message_repository.dart';
import 'package:hello_engine/src/persistence/database/app_database.dart';
import 'package:drift/drift.dart';

/// Drift-backed implementation of [MessageRepository].
///
/// Maps between domain [Message] objects and drift `MessageRow` /
/// `MessageCiphertextRow` records. Plaintext is never stored in the
/// messages table -- only in the `DecryptedMessages` cache.
class MessageRepositoryImpl implements MessageRepository {
  /// Creates a [MessageRepositoryImpl] backed by the given database.
  MessageRepositoryImpl(this._db);

  final AppDatabase _db;

  // ---------------------------------------------------------------------------
  // Mapping helpers
  // ---------------------------------------------------------------------------

  MessageRow _toRow(Message m) {
    return MessageRow(
      id: m.id,
      groupId: m.groupId,
      senderId: m.senderId,
      senderDeviceId: m.senderDeviceId,
      messageType: _messageTypeToString(m.type),
      role: m.role,
      serverSeq: m.serverSeq,
      status: m.status.name,
      replyToMessageId: m.replyToMessageId,
      reactionsJson:
          m.reactions.isEmpty ? null : jsonEncode(m.reactions),
      isStarred: m.isStarred,
      isViewOnce: m.isViewOnce,
      disappearsAt: m.disappearsAt,
      isDeleted: m.isDeleted,
      createdAt: m.timestamp,
    );
  }

  Message _fromRow(MessageRow row) {
    return Message(
      id: row.id,
      groupId: row.groupId,
      senderId: row.senderId,
      senderDeviceId: row.senderDeviceId ?? '',
      type: _messageTypeFromString(row.messageType),
      status: _messageStatusFromString(row.status),
      timestamp: row.createdAt,
      role: row.role,
      serverSeq: row.serverSeq,
      replyToMessageId: row.replyToMessageId,
      reactions: _parseReactions(row.reactionsJson),
      isStarred: row.isStarred,
      isViewOnce: row.isViewOnce,
      disappearsAt: row.disappearsAt,
      isDeleted: row.isDeleted,
    );
  }

  static String _messageTypeToString(MessageType type) {
    return switch (type) {
      MessageType.e2ee => 'e2ee',
      MessageType.hello => 'hello',
      MessageType.system => 'system',
      MessageType.legacy => 'legacy',
      MessageType.senderKeyDist => 'sender_key_dist',
      MessageType.text => 'message',
      MessageType.media => 'media',
    };
  }

  static MessageType _messageTypeFromString(String s) {
    return switch (s) {
      'e2ee' => MessageType.e2ee,
      'hello' => MessageType.hello,
      'system' => MessageType.system,
      'legacy' => MessageType.legacy,
      'sender_key_dist' => MessageType.senderKeyDist,
      'message' => MessageType.text,
      'media' => MessageType.media,
      _ => MessageType.e2ee,
    };
  }

  static MessageStatus _messageStatusFromString(String s) {
    return switch (s) {
      'sending' => MessageStatus.sending,
      'sent' => MessageStatus.sent,
      'delivered' => MessageStatus.delivered,
      'read' => MessageStatus.read,
      'failed' => MessageStatus.failed,
      _ => MessageStatus.sending,
    };
  }

  static Map<String, List<String>> _parseReactions(String? json) {
    if (json == null || json.isEmpty) return {};
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return decoded.map(
      (key, value) => MapEntry(
        key,
        (value as List<dynamic>).cast<String>(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MessageRepository interface
  // ---------------------------------------------------------------------------

  @override
  Future<void> saveMessage(Message message) async {
    await _db.into(_db.messages).insertOnConflictUpdate(_toRow(message));
  }

  @override
  Future<void> saveMessages(List<Message> messages) async {
    await _db.batch((batch) {
      for (final m in messages) {
        batch.insert(
          _db.messages,
          _toRow(m),
          onConflict: DoUpdate((_) => _toRow(m)),
        );
      }
    });
  }

  @override
  Future<Message?> getMessageById(String id) async {
    final query = _db.select(_db.messages)
      ..where((t) => t.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<List<Message>> getMessages(
    String groupId, {
    int limit = 50,
    String? beforeId,
  }) async {
    final query = _db.select(_db.messages)
      ..where((t) => t.groupId.equals(groupId))
      ..orderBy([
        (t) => OrderingTerm.desc(t.createdAt),
      ])
      ..limit(limit);

    if (beforeId != null) {
      final beforeRow = await (_db.select(_db.messages)
            ..where((t) => t.id.equals(beforeId)))
          .getSingleOrNull();
      if (beforeRow != null) {
        query.where(
          (t) => t.createdAt.isSmallerThanValue(beforeRow.createdAt),
        );
      }
    }

    final rows = await query.get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> updateMessageStatus(String id, MessageStatus status) async {
    await (_db.update(_db.messages)..where((t) => t.id.equals(id)))
        .write(MessagesCompanion(status: Value(status.name)));
  }

  @override
  Future<void> markDeleted(String id, {required bool forEveryone}) async {
    await (_db.update(_db.messages)..where((t) => t.id.equals(id)))
        .write(const MessagesCompanion(isDeleted: Value(true)));
  }

  @override
  Future<void> setReaction(
    String messageId,
    String userId,
    String emoji,
  ) async {
    final msg = await getMessageById(messageId);
    if (msg == null) return;
    final reactions = Map<String, List<String>>.from(
      msg.reactions.map(
        (k, v) => MapEntry(k, List<String>.from(v)),
      ),
    );
    final list = reactions.putIfAbsent(emoji, () => []);
    if (!list.contains(userId)) {
      list.add(userId);
    }
    await (_db.update(_db.messages)
          ..where((t) => t.id.equals(messageId)))
        .write(
      MessagesCompanion(reactionsJson: Value(jsonEncode(reactions))),
    );
  }

  @override
  Future<void> removeReaction(
    String messageId,
    String userId,
    String emoji,
  ) async {
    final msg = await getMessageById(messageId);
    if (msg == null) return;
    final reactions = Map<String, List<String>>.from(
      msg.reactions.map(
        (k, v) => MapEntry(k, List<String>.from(v)),
      ),
    );
    reactions[emoji]?.remove(userId);
    if (reactions[emoji]?.isEmpty ?? false) {
      reactions.remove(emoji);
    }
    await (_db.update(_db.messages)
          ..where((t) => t.id.equals(messageId)))
        .write(
      MessagesCompanion(reactionsJson: Value(jsonEncode(reactions))),
    );
  }

  @override
  Future<void> setStar(String messageId, {required bool starred}) async {
    await (_db.update(_db.messages)
          ..where((t) => t.id.equals(messageId)))
        .write(MessagesCompanion(isStarred: Value(starred)));
  }

  @override
  Future<List<Message>> search(
    String query, {
    String? groupId,
  }) async {
    // Search operates against the plaintext cache.
    // Load candidate decrypted messages and filter client-side.
    final lowerQuery = query.toLowerCase();
    final decryptedQuery = _db.select(_db.decryptedMessages)
      ..where(
        (t) => t.plaintext.lower().like('%$lowerQuery%'),
      );
    final decryptedRows = await decryptedQuery.get();
    if (decryptedRows.isEmpty) return [];

    final messageIds = decryptedRows.map((r) => r.messageId).toList();

    final msgQuery = _db.select(_db.messages)
      ..where((t) => t.id.isIn(messageIds));
    if (groupId != null) {
      msgQuery.where((t) => t.groupId.equals(groupId));
    }
    msgQuery.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    final rows = await msgQuery.get();
    return rows.map(_fromRow).toList();
  }

  @override
  Stream<List<Message>> watchMessages(String groupId) {
    final query = _db.select(_db.messages)
      ..where((t) => t.groupId.equals(groupId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch().map(
          (rows) => rows.map(_fromRow).toList(),
        );
  }

  // ---------------------------------------------------------------------------
  // Ciphertext operations (used by sync/messaging layers)
  // ---------------------------------------------------------------------------

  /// Saves a ciphertext row for a message.
  Future<void> saveCiphertext(MessageCiphertextRow row) async {
    await _db.into(_db.messageCiphertexts).insertOnConflictUpdate(row);
  }

  /// Returns all ciphertext rows for a given message.
  Future<List<MessageCiphertextRow>> getCiphertexts(
    String messageId,
  ) async {
    final query = _db.select(_db.messageCiphertexts)
      ..where((t) => t.messageId.equals(messageId));
    return query.get();
  }
}
