import 'dart:convert';

import 'package:chat_engine/src/domain/models/conversation.dart';
import 'package:chat_engine/src/domain/repositories/conversation_repository.dart';
import 'package:chat_engine/src/persistence/database/app_database.dart';
import 'package:drift/drift.dart';

/// Drift-backed implementation of [ConversationRepository].
///
/// Stores participant IDs as a JSON array string. Conversations are
/// ordered by pinned status first, then by last-update time.
class ConversationRepositoryImpl implements ConversationRepository {
  /// Creates a [ConversationRepositoryImpl] backed by the given database.
  ConversationRepositoryImpl(this._db);

  final AppDatabase _db;

  // ---------------------------------------------------------------------------
  // Mapping helpers
  // ---------------------------------------------------------------------------

  ConversationRow _toRow(Conversation c) {
    return ConversationRow(
      id: c.id,
      type: c.type.name,
      participantIdsJson: jsonEncode(c.participantIds),
      lastMessageId: c.lastMessageId,
      lastMessageText: c.lastMessageText,
      lastMessageTimestamp: c.lastMessageTimestamp,
      unreadCount: c.unreadCount,
      isPinned: c.isPinned,
      isArchived: c.isArchived,
      isMuted: c.isMuted,
      muteUntil: c.muteUntil,
      disappearingMessageTimerMs: c.disappearingMessageTimerMs,
      isEncrypted: c.isEncrypted,
      createdAt: c.createdAt,
      updatedAt: c.updatedAt,
    );
  }

  Conversation _fromRow(ConversationRow row) {
    return Conversation(
      id: row.id,
      type: _conversationTypeFromString(row.type),
      participantIds: _parseParticipantIds(row.participantIdsJson),
      lastMessageId: row.lastMessageId,
      lastMessageText: row.lastMessageText,
      lastMessageTimestamp: row.lastMessageTimestamp,
      unreadCount: row.unreadCount,
      isPinned: row.isPinned,
      isArchived: row.isArchived,
      isMuted: row.isMuted,
      muteUntil: row.muteUntil,
      disappearingMessageTimerMs: row.disappearingMessageTimerMs,
      isEncrypted: row.isEncrypted,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  static ConversationType _conversationTypeFromString(String s) {
    return switch (s) {
      'group' => ConversationType.group,
      _ => ConversationType.oneToOne,
    };
  }

  static List<String> _parseParticipantIds(String json) {
    final decoded = jsonDecode(json) as List<dynamic>;
    return decoded.cast<String>();
  }

  // ---------------------------------------------------------------------------
  // ConversationRepository interface
  // ---------------------------------------------------------------------------

  @override
  Future<void> saveConversation(Conversation conversation) async {
    await _db
        .into(_db.conversations)
        .insertOnConflictUpdate(_toRow(conversation));
  }

  @override
  Future<Conversation?> getConversation(String id) async {
    final query = _db.select(_db.conversations)
      ..where((t) => t.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<List<Conversation>> getAllConversations() async {
    final query = _db.select(_db.conversations)
      ..orderBy([
        (t) => OrderingTerm.desc(t.isPinned),
        (t) => OrderingTerm.desc(t.updatedAt),
      ]);
    final rows = await query.get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> updateUnreadCount(
    String conversationId,
    int count,
  ) async {
    await (_db.update(_db.conversations)
          ..where((t) => t.id.equals(conversationId)))
        .write(ConversationsCompanion(unreadCount: Value(count)));
  }

  @override
  Future<void> setPin(
    String conversationId, {
    required bool pinned,
  }) async {
    await (_db.update(_db.conversations)
          ..where((t) => t.id.equals(conversationId)))
        .write(ConversationsCompanion(isPinned: Value(pinned)));
  }

  @override
  Future<void> setArchive(
    String conversationId, {
    required bool archived,
  }) async {
    await (_db.update(_db.conversations)
          ..where((t) => t.id.equals(conversationId)))
        .write(ConversationsCompanion(isArchived: Value(archived)));
  }

  @override
  Future<void> setMute(
    String conversationId, {
    required bool muted,
    DateTime? until,
  }) async {
    await (_db.update(_db.conversations)
          ..where((t) => t.id.equals(conversationId)))
        .write(
      ConversationsCompanion(
        isMuted: Value(muted),
        muteUntil: Value(until),
      ),
    );
  }

  @override
  Stream<List<Conversation>> watchConversations() {
    final query = _db.select(_db.conversations)
      ..orderBy([
        (t) => OrderingTerm.desc(t.isPinned),
        (t) => OrderingTerm.desc(t.updatedAt),
      ]);
    return query.watch().map(
          (rows) => rows.map(_fromRow).toList(),
        );
  }
}
