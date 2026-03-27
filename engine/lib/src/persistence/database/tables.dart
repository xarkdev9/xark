import 'package:drift/drift.dart';

/// Metadata for each message. Plaintext is never stored here — only in
/// [DecryptedMessages] as a client-side cache.
@DataClassName('MessageRow')
class Messages extends Table {
  /// Client-generated UUID v7.
  TextColumn get id => text()();

  /// Conversation (space) this message belongs to.
  TextColumn get groupId => text()();

  /// User ID of the sender.
  TextColumn get senderId => text()();

  /// Device ID of the sender's device, nullable for system messages.
  TextColumn get senderDeviceId => text().nullable()();

  /// Wire-level message type: e2ee, hello, system, legacy, sender_key_dist,
  /// message, media.
  TextColumn get messageType =>
      text().withDefault(const Constant('e2ee'))();

  /// Role of the message: user or system.
  TextColumn get role => text().withDefault(const Constant('user'))();

  /// Server-assigned monotonically increasing sequence number.
  IntColumn get serverSeq => integer().nullable()();

  /// Status: sending, sent, delivered, read, failed.
  TextColumn get status =>
      text().withDefault(const Constant('sending'))();

  /// Reply-to message ID, if this is a reply.
  TextColumn get replyToMessageId => text().nullable()();

  /// JSON-encoded reactions map: { emoji: [userId, ...] }.
  TextColumn get reactionsJson => text().nullable()();

  /// Whether the message is starred.
  BoolColumn get isStarred =>
      boolean().withDefault(const Constant(false))();

  /// Whether the message is view-once.
  BoolColumn get isViewOnce =>
      boolean().withDefault(const Constant(false))();

  /// Epoch ms when the message disappears, if set.
  IntColumn get disappearsAt => integer().nullable()();

  /// Whether the message has been deleted.
  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false))();

  /// Server-side content for system messages (plaintext).
  TextColumn get serverContent => text().nullable()();

  /// When the message was created.
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-device ciphertext payload for a message.
@DataClassName('MessageCiphertextRow')
class MessageCiphertexts extends Table {
  /// Row ID (UUID).
  TextColumn get id => text()();

  /// References [Messages.id].
  TextColumn get messageId => text().references(Messages, #id)();

  /// Recipient user ID.
  TextColumn get recipientId => text()();

  /// Recipient device ID.
  IntColumn get recipientDeviceId => integer()();

  /// Encrypted ciphertext payload.
  TextColumn get ciphertext => text()();

  /// JSON-encoded ratchet header, if applicable.
  TextColumn get ratchetHeader => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Conversation metadata.
@DataClassName('ConversationRow')
class Conversations extends Table {
  /// Conversation ID.
  TextColumn get id => text()();

  /// Type: oneToOne or group.
  TextColumn get type => text()();

  /// JSON array of participant user IDs.
  TextColumn get participantIdsJson => text()();

  /// Last message ID for display ordering.
  TextColumn get lastMessageId => text().nullable()();

  /// Last message preview text (decrypted client-side, stored for list UI).
  TextColumn get lastMessageText => text().nullable()();

  /// Timestamp of the last message.
  DateTimeColumn get lastMessageTimestamp => dateTime().nullable()();

  /// Number of unread messages.
  IntColumn get unreadCount =>
      integer().withDefault(const Constant(0))();

  /// Whether this conversation is pinned.
  BoolColumn get isPinned =>
      boolean().withDefault(const Constant(false))();

  /// Whether this conversation is archived.
  BoolColumn get isArchived =>
      boolean().withDefault(const Constant(false))();

  /// Whether this conversation is muted.
  BoolColumn get isMuted =>
      boolean().withDefault(const Constant(false))();

  /// When the mute expires, if set.
  DateTimeColumn get muteUntil => dateTime().nullable()();

  /// Disappearing message timer in milliseconds.
  IntColumn get disappearingMessageTimerMs => integer().nullable()();

  /// Whether the conversation is encrypted.
  BoolColumn get isEncrypted =>
      boolean().withDefault(const Constant(true))();

  /// When the conversation was created.
  DateTimeColumn get createdAt => dateTime()();

  /// When the conversation was last updated.
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Delivery and read receipts per message, per user, per device.
@DataClassName('ReceiptRow')
class Receipts extends Table {
  /// The message this receipt is for.
  TextColumn get messageId => text()();

  /// The user who delivered/read.
  TextColumn get userId => text()();

  /// The device that reported the receipt.
  TextColumn get deviceId => text()();

  /// When the message was delivered.
  DateTimeColumn get deliveredAt => dateTime().nullable()();

  /// When the message was read.
  DateTimeColumn get readAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {messageId, userId, deviceId};
}

/// Outbox queue for messages pending network delivery.
@DataClassName('OutboxItemRow')
class OutboxItems extends Table {
  /// Outbox item ID (same as the message UUID).
  TextColumn get id => text()();

  /// Which conversation this belongs to.
  TextColumn get groupId => text()();

  /// The encrypted envelope blob ready to send.
  BlobColumn get encryptedEnvelope => blob()();

  /// JSON array of target "userId:deviceId" strings.
  TextColumn get recipientDeviceIds => text()();

  /// Number of send attempts so far.
  IntColumn get retryCount =>
      integer().withDefault(const Constant(0))();

  /// When this item was queued.
  DateTimeColumn get createdAt => dateTime()();

  /// When the next retry is allowed.
  DateTimeColumn get nextRetryAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Serialised Double Ratchet or Sender Key session state (encrypted).
@DataClassName('RatchetSessionRow')
class RatchetSessions extends Table {
  /// Session key: "userId:deviceId" for 1:1, groupId for group.
  TextColumn get sessionId => text()();

  /// Encrypted serialised state blob.
  BlobColumn get encryptedState => blob()();

  /// When this session was last persisted.
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {sessionId};
}

/// Media attachment records.
@DataClassName('MediaItemRow')
class MediaItems extends Table {
  /// Media ID (UUID).
  TextColumn get mediaId => text()();

  /// Conversation the media belongs to.
  TextColumn get groupId => text()();

  /// Message the media is attached to.
  TextColumn get messageId => text()();

  /// MIME type (e.g., image/jpeg).
  TextColumn get mimeType => text()();

  /// Local file path after download.
  TextColumn get localPath => text().nullable()();

  /// Remote download URL.
  TextColumn get downloadUrl => text()();

  /// JSON-encoded AES key + IV for decryption.
  TextColumn get encryptedKeyJson => text()();

  /// File size in bytes.
  IntColumn get sizeBytes => integer()();

  /// Whether the file has been downloaded and verified.
  BoolColumn get isDownloaded =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {mediaId};
}

/// Two-phase ratchet commit: pre-send unacknowledged state.
@DataClassName('UnackedRatchetRow')
class UnackedRatchets extends Table {
  /// Unique ID for this unacked snapshot.
  TextColumn get id => text()();

  /// Session key: "userId:deviceId".
  TextColumn get sessionKey => text()();

  /// Session type: "doubleRatchet" or "senderKey".
  TextColumn get sessionType => text()();

  /// JSON-serialised ratchet state snapshot.
  TextColumn get serializedState => text()();

  /// When this snapshot was created.
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Client-side plaintext cache — decrypted content keyed by message ID.
@DataClassName('DecryptedMessageRow')
class DecryptedMessages extends Table {
  /// References [Messages.id].
  TextColumn get messageId => text()();

  /// Decrypted plaintext.
  TextColumn get plaintext => text()();

  /// JSON-encoded media metadata, if the message has media.
  TextColumn get mediaJson => text().nullable()();

  /// When this cache entry was stored.
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {messageId};
}

/// Deduplication table for processed sender key distribution messages.
@DataClassName('ProcessedDistributionRow')
class ProcessedDistributions extends Table {
  /// The distribution message ID.
  TextColumn get messageId => text()();

  /// When it was processed.
  DateTimeColumn get processedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {messageId};
}

/// Local cache of Sender Key acknowledgments for O(1) distribution (CRYPTO-04).
/// Tracks which group+sender pairs have been ACKed, so future encrypts
/// skip redundant SK distribution to already-served devices.
@DataClassName('SkAckCacheRow')
class SkAckCache extends Table {
  /// The group this ACK belongs to.
  TextColumn get groupId => text()();

  /// The sender whose key was acknowledged.
  TextColumn get senderId => text()();

  /// Sender Key epoch (rotated on tombstone / member removal).
  IntColumn get epoch => integer().withDefault(const Constant(1))();

  /// When this ACK was recorded.
  DateTimeColumn get ackedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {groupId, senderId};
}

/// Sync watermarks per conversation for gap detection and incremental sync.
///
/// Tracks the highest `serverSeq` received locally so the sync layer can
/// request only newer messages on reconnect.
@DataClassName('SyncWatermarkRow')
class SyncWatermarks extends Table {
  /// Conversation (group) ID.
  TextColumn get groupId => text()();

  /// Highest server sequence number received for this group.
  IntColumn get lastReceivedSeq =>
      integer().withDefault(const Constant(0))();

  /// When we last successfully synced this group.
  DateTimeColumn get lastSyncAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {groupId};
}

/// Pending media upload tasks for offline-first media sending (MOBILE-05).
///
/// Files are encrypted and queued locally; the upload worker drains this
/// table when connectivity is available.
@DataClassName('UploadTaskRow')
class UploadTasks extends Table {
  /// Media ID (UUID).
  TextColumn get mediaId => text()();

  /// Conversation the media belongs to.
  TextColumn get groupId => text()();

  /// Local file path of the encrypted blob.
  TextColumn get localPath => text()();

  /// MIME type (e.g., image/jpeg).
  TextColumn get mimeType => text()();

  /// Total file size in bytes.
  IntColumn get totalBytes => integer()();

  /// Bytes uploaded so far (for progress tracking).
  IntColumn get uploadedBytes =>
      integer().withDefault(const Constant(0))();

  /// Remote download URL, populated after successful upload.
  TextColumn get downloadUrl => text().nullable()();

  /// Upload status: pending, uploading, completed, failed.
  TextColumn get status =>
      text().withDefault(const Constant('pending'))();

  /// JSON-encoded AES key + IV used to encrypt the file.
  TextColumn get encryptionKeyJson => text().nullable()();

  /// When this task was created.
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {mediaId};
}
