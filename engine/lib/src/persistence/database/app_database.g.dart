// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MessagesTable extends Messages
    with TableInfo<$MessagesTable, MessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'group_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _senderIdMeta =
      const VerificationMeta('senderId');
  @override
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
      'sender_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _senderDeviceIdMeta =
      const VerificationMeta('senderDeviceId');
  @override
  late final GeneratedColumn<String> senderDeviceId = GeneratedColumn<String>(
      'sender_device_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _messageTypeMeta =
      const VerificationMeta('messageType');
  @override
  late final GeneratedColumn<String> messageType = GeneratedColumn<String>(
      'message_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('e2ee'));
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
      'role', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('user'));
  static const VerificationMeta _serverSeqMeta =
      const VerificationMeta('serverSeq');
  @override
  late final GeneratedColumn<int> serverSeq = GeneratedColumn<int>(
      'server_seq', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('sending'));
  static const VerificationMeta _replyToMessageIdMeta =
      const VerificationMeta('replyToMessageId');
  @override
  late final GeneratedColumn<String> replyToMessageId = GeneratedColumn<String>(
      'reply_to_message_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _reactionsJsonMeta =
      const VerificationMeta('reactionsJson');
  @override
  late final GeneratedColumn<String> reactionsJson = GeneratedColumn<String>(
      'reactions_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isStarredMeta =
      const VerificationMeta('isStarred');
  @override
  late final GeneratedColumn<bool> isStarred = GeneratedColumn<bool>(
      'is_starred', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_starred" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isViewOnceMeta =
      const VerificationMeta('isViewOnce');
  @override
  late final GeneratedColumn<bool> isViewOnce = GeneratedColumn<bool>(
      'is_view_once', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_view_once" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _disappearsAtMeta =
      const VerificationMeta('disappearsAt');
  @override
  late final GeneratedColumn<int> disappearsAt = GeneratedColumn<int>(
      'disappears_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _serverContentMeta =
      const VerificationMeta('serverContent');
  @override
  late final GeneratedColumn<String> serverContent = GeneratedColumn<String>(
      'server_content', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        groupId,
        senderId,
        senderDeviceId,
        messageType,
        role,
        serverSeq,
        status,
        replyToMessageId,
        reactionsJson,
        isStarred,
        isViewOnce,
        disappearsAt,
        isDeleted,
        serverContent,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(Insertable<MessageRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('sender_id')) {
      context.handle(_senderIdMeta,
          senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta));
    } else if (isInserting) {
      context.missing(_senderIdMeta);
    }
    if (data.containsKey('sender_device_id')) {
      context.handle(
          _senderDeviceIdMeta,
          senderDeviceId.isAcceptableOrUnknown(
              data['sender_device_id']!, _senderDeviceIdMeta));
    }
    if (data.containsKey('message_type')) {
      context.handle(
          _messageTypeMeta,
          messageType.isAcceptableOrUnknown(
              data['message_type']!, _messageTypeMeta));
    }
    if (data.containsKey('role')) {
      context.handle(
          _roleMeta, role.isAcceptableOrUnknown(data['role']!, _roleMeta));
    }
    if (data.containsKey('server_seq')) {
      context.handle(_serverSeqMeta,
          serverSeq.isAcceptableOrUnknown(data['server_seq']!, _serverSeqMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('reply_to_message_id')) {
      context.handle(
          _replyToMessageIdMeta,
          replyToMessageId.isAcceptableOrUnknown(
              data['reply_to_message_id']!, _replyToMessageIdMeta));
    }
    if (data.containsKey('reactions_json')) {
      context.handle(
          _reactionsJsonMeta,
          reactionsJson.isAcceptableOrUnknown(
              data['reactions_json']!, _reactionsJsonMeta));
    }
    if (data.containsKey('is_starred')) {
      context.handle(_isStarredMeta,
          isStarred.isAcceptableOrUnknown(data['is_starred']!, _isStarredMeta));
    }
    if (data.containsKey('is_view_once')) {
      context.handle(
          _isViewOnceMeta,
          isViewOnce.isAcceptableOrUnknown(
              data['is_view_once']!, _isViewOnceMeta));
    }
    if (data.containsKey('disappears_at')) {
      context.handle(
          _disappearsAtMeta,
          disappearsAt.isAcceptableOrUnknown(
              data['disappears_at']!, _disappearsAtMeta));
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    if (data.containsKey('server_content')) {
      context.handle(
          _serverContentMeta,
          serverContent.isAcceptableOrUnknown(
              data['server_content']!, _serverContentMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_id'])!,
      senderId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_id'])!,
      senderDeviceId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}sender_device_id']),
      messageType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message_type'])!,
      role: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}role'])!,
      serverSeq: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}server_seq']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      replyToMessageId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}reply_to_message_id']),
      reactionsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reactions_json']),
      isStarred: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_starred'])!,
      isViewOnce: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_view_once'])!,
      disappearsAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}disappears_at']),
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
      serverContent: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_content']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class MessageRow extends DataClass implements Insertable<MessageRow> {
  /// Client-generated UUID v7.
  final String id;

  /// Conversation (space) this message belongs to.
  final String groupId;

  /// User ID of the sender.
  final String senderId;

  /// Device ID of the sender's device, nullable for system messages.
  final String? senderDeviceId;

  /// Wire-level message type: e2ee, xark, system, legacy, sender_key_dist,
  /// message, media.
  final String messageType;

  /// Role of the message: user or system.
  final String role;

  /// Server-assigned monotonically increasing sequence number.
  final int? serverSeq;

  /// Status: sending, sent, delivered, read, failed.
  final String status;

  /// Reply-to message ID, if this is a reply.
  final String? replyToMessageId;

  /// JSON-encoded reactions map: { emoji: [userId, ...] }.
  final String? reactionsJson;

  /// Whether the message is starred.
  final bool isStarred;

  /// Whether the message is view-once.
  final bool isViewOnce;

  /// Epoch ms when the message disappears, if set.
  final int? disappearsAt;

  /// Whether the message has been deleted.
  final bool isDeleted;

  /// Server-side content for system messages (plaintext).
  final String? serverContent;

  /// When the message was created.
  final DateTime createdAt;
  const MessageRow(
      {required this.id,
      required this.groupId,
      required this.senderId,
      this.senderDeviceId,
      required this.messageType,
      required this.role,
      this.serverSeq,
      required this.status,
      this.replyToMessageId,
      this.reactionsJson,
      required this.isStarred,
      required this.isViewOnce,
      this.disappearsAt,
      required this.isDeleted,
      this.serverContent,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['sender_id'] = Variable<String>(senderId);
    if (!nullToAbsent || senderDeviceId != null) {
      map['sender_device_id'] = Variable<String>(senderDeviceId);
    }
    map['message_type'] = Variable<String>(messageType);
    map['role'] = Variable<String>(role);
    if (!nullToAbsent || serverSeq != null) {
      map['server_seq'] = Variable<int>(serverSeq);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || replyToMessageId != null) {
      map['reply_to_message_id'] = Variable<String>(replyToMessageId);
    }
    if (!nullToAbsent || reactionsJson != null) {
      map['reactions_json'] = Variable<String>(reactionsJson);
    }
    map['is_starred'] = Variable<bool>(isStarred);
    map['is_view_once'] = Variable<bool>(isViewOnce);
    if (!nullToAbsent || disappearsAt != null) {
      map['disappears_at'] = Variable<int>(disappearsAt);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || serverContent != null) {
      map['server_content'] = Variable<String>(serverContent);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      groupId: Value(groupId),
      senderId: Value(senderId),
      senderDeviceId: senderDeviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(senderDeviceId),
      messageType: Value(messageType),
      role: Value(role),
      serverSeq: serverSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(serverSeq),
      status: Value(status),
      replyToMessageId: replyToMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToMessageId),
      reactionsJson: reactionsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(reactionsJson),
      isStarred: Value(isStarred),
      isViewOnce: Value(isViewOnce),
      disappearsAt: disappearsAt == null && nullToAbsent
          ? const Value.absent()
          : Value(disappearsAt),
      isDeleted: Value(isDeleted),
      serverContent: serverContent == null && nullToAbsent
          ? const Value.absent()
          : Value(serverContent),
      createdAt: Value(createdAt),
    );
  }

  factory MessageRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageRow(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      senderId: serializer.fromJson<String>(json['senderId']),
      senderDeviceId: serializer.fromJson<String?>(json['senderDeviceId']),
      messageType: serializer.fromJson<String>(json['messageType']),
      role: serializer.fromJson<String>(json['role']),
      serverSeq: serializer.fromJson<int?>(json['serverSeq']),
      status: serializer.fromJson<String>(json['status']),
      replyToMessageId: serializer.fromJson<String?>(json['replyToMessageId']),
      reactionsJson: serializer.fromJson<String?>(json['reactionsJson']),
      isStarred: serializer.fromJson<bool>(json['isStarred']),
      isViewOnce: serializer.fromJson<bool>(json['isViewOnce']),
      disappearsAt: serializer.fromJson<int?>(json['disappearsAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      serverContent: serializer.fromJson<String?>(json['serverContent']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'senderId': serializer.toJson<String>(senderId),
      'senderDeviceId': serializer.toJson<String?>(senderDeviceId),
      'messageType': serializer.toJson<String>(messageType),
      'role': serializer.toJson<String>(role),
      'serverSeq': serializer.toJson<int?>(serverSeq),
      'status': serializer.toJson<String>(status),
      'replyToMessageId': serializer.toJson<String?>(replyToMessageId),
      'reactionsJson': serializer.toJson<String?>(reactionsJson),
      'isStarred': serializer.toJson<bool>(isStarred),
      'isViewOnce': serializer.toJson<bool>(isViewOnce),
      'disappearsAt': serializer.toJson<int?>(disappearsAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'serverContent': serializer.toJson<String?>(serverContent),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  MessageRow copyWith(
          {String? id,
          String? groupId,
          String? senderId,
          Value<String?> senderDeviceId = const Value.absent(),
          String? messageType,
          String? role,
          Value<int?> serverSeq = const Value.absent(),
          String? status,
          Value<String?> replyToMessageId = const Value.absent(),
          Value<String?> reactionsJson = const Value.absent(),
          bool? isStarred,
          bool? isViewOnce,
          Value<int?> disappearsAt = const Value.absent(),
          bool? isDeleted,
          Value<String?> serverContent = const Value.absent(),
          DateTime? createdAt}) =>
      MessageRow(
        id: id ?? this.id,
        groupId: groupId ?? this.groupId,
        senderId: senderId ?? this.senderId,
        senderDeviceId:
            senderDeviceId.present ? senderDeviceId.value : this.senderDeviceId,
        messageType: messageType ?? this.messageType,
        role: role ?? this.role,
        serverSeq: serverSeq.present ? serverSeq.value : this.serverSeq,
        status: status ?? this.status,
        replyToMessageId: replyToMessageId.present
            ? replyToMessageId.value
            : this.replyToMessageId,
        reactionsJson:
            reactionsJson.present ? reactionsJson.value : this.reactionsJson,
        isStarred: isStarred ?? this.isStarred,
        isViewOnce: isViewOnce ?? this.isViewOnce,
        disappearsAt:
            disappearsAt.present ? disappearsAt.value : this.disappearsAt,
        isDeleted: isDeleted ?? this.isDeleted,
        serverContent:
            serverContent.present ? serverContent.value : this.serverContent,
        createdAt: createdAt ?? this.createdAt,
      );
  MessageRow copyWithCompanion(MessagesCompanion data) {
    return MessageRow(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      senderDeviceId: data.senderDeviceId.present
          ? data.senderDeviceId.value
          : this.senderDeviceId,
      messageType:
          data.messageType.present ? data.messageType.value : this.messageType,
      role: data.role.present ? data.role.value : this.role,
      serverSeq: data.serverSeq.present ? data.serverSeq.value : this.serverSeq,
      status: data.status.present ? data.status.value : this.status,
      replyToMessageId: data.replyToMessageId.present
          ? data.replyToMessageId.value
          : this.replyToMessageId,
      reactionsJson: data.reactionsJson.present
          ? data.reactionsJson.value
          : this.reactionsJson,
      isStarred: data.isStarred.present ? data.isStarred.value : this.isStarred,
      isViewOnce:
          data.isViewOnce.present ? data.isViewOnce.value : this.isViewOnce,
      disappearsAt: data.disappearsAt.present
          ? data.disappearsAt.value
          : this.disappearsAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      serverContent: data.serverContent.present
          ? data.serverContent.value
          : this.serverContent,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageRow(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('senderId: $senderId, ')
          ..write('senderDeviceId: $senderDeviceId, ')
          ..write('messageType: $messageType, ')
          ..write('role: $role, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('status: $status, ')
          ..write('replyToMessageId: $replyToMessageId, ')
          ..write('reactionsJson: $reactionsJson, ')
          ..write('isStarred: $isStarred, ')
          ..write('isViewOnce: $isViewOnce, ')
          ..write('disappearsAt: $disappearsAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('serverContent: $serverContent, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      groupId,
      senderId,
      senderDeviceId,
      messageType,
      role,
      serverSeq,
      status,
      replyToMessageId,
      reactionsJson,
      isStarred,
      isViewOnce,
      disappearsAt,
      isDeleted,
      serverContent,
      createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageRow &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.senderId == this.senderId &&
          other.senderDeviceId == this.senderDeviceId &&
          other.messageType == this.messageType &&
          other.role == this.role &&
          other.serverSeq == this.serverSeq &&
          other.status == this.status &&
          other.replyToMessageId == this.replyToMessageId &&
          other.reactionsJson == this.reactionsJson &&
          other.isStarred == this.isStarred &&
          other.isViewOnce == this.isViewOnce &&
          other.disappearsAt == this.disappearsAt &&
          other.isDeleted == this.isDeleted &&
          other.serverContent == this.serverContent &&
          other.createdAt == this.createdAt);
}

class MessagesCompanion extends UpdateCompanion<MessageRow> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String> senderId;
  final Value<String?> senderDeviceId;
  final Value<String> messageType;
  final Value<String> role;
  final Value<int?> serverSeq;
  final Value<String> status;
  final Value<String?> replyToMessageId;
  final Value<String?> reactionsJson;
  final Value<bool> isStarred;
  final Value<bool> isViewOnce;
  final Value<int?> disappearsAt;
  final Value<bool> isDeleted;
  final Value<String?> serverContent;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.senderId = const Value.absent(),
    this.senderDeviceId = const Value.absent(),
    this.messageType = const Value.absent(),
    this.role = const Value.absent(),
    this.serverSeq = const Value.absent(),
    this.status = const Value.absent(),
    this.replyToMessageId = const Value.absent(),
    this.reactionsJson = const Value.absent(),
    this.isStarred = const Value.absent(),
    this.isViewOnce = const Value.absent(),
    this.disappearsAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.serverContent = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String id,
    required String groupId,
    required String senderId,
    this.senderDeviceId = const Value.absent(),
    this.messageType = const Value.absent(),
    this.role = const Value.absent(),
    this.serverSeq = const Value.absent(),
    this.status = const Value.absent(),
    this.replyToMessageId = const Value.absent(),
    this.reactionsJson = const Value.absent(),
    this.isStarred = const Value.absent(),
    this.isViewOnce = const Value.absent(),
    this.disappearsAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.serverContent = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        groupId = Value(groupId),
        senderId = Value(senderId),
        createdAt = Value(createdAt);
  static Insertable<MessageRow> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? senderId,
    Expression<String>? senderDeviceId,
    Expression<String>? messageType,
    Expression<String>? role,
    Expression<int>? serverSeq,
    Expression<String>? status,
    Expression<String>? replyToMessageId,
    Expression<String>? reactionsJson,
    Expression<bool>? isStarred,
    Expression<bool>? isViewOnce,
    Expression<int>? disappearsAt,
    Expression<bool>? isDeleted,
    Expression<String>? serverContent,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (senderId != null) 'sender_id': senderId,
      if (senderDeviceId != null) 'sender_device_id': senderDeviceId,
      if (messageType != null) 'message_type': messageType,
      if (role != null) 'role': role,
      if (serverSeq != null) 'server_seq': serverSeq,
      if (status != null) 'status': status,
      if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
      if (reactionsJson != null) 'reactions_json': reactionsJson,
      if (isStarred != null) 'is_starred': isStarred,
      if (isViewOnce != null) 'is_view_once': isViewOnce,
      if (disappearsAt != null) 'disappears_at': disappearsAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (serverContent != null) 'server_content': serverContent,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith(
      {Value<String>? id,
      Value<String>? groupId,
      Value<String>? senderId,
      Value<String?>? senderDeviceId,
      Value<String>? messageType,
      Value<String>? role,
      Value<int?>? serverSeq,
      Value<String>? status,
      Value<String?>? replyToMessageId,
      Value<String?>? reactionsJson,
      Value<bool>? isStarred,
      Value<bool>? isViewOnce,
      Value<int?>? disappearsAt,
      Value<bool>? isDeleted,
      Value<String?>? serverContent,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return MessagesCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      senderId: senderId ?? this.senderId,
      senderDeviceId: senderDeviceId ?? this.senderDeviceId,
      messageType: messageType ?? this.messageType,
      role: role ?? this.role,
      serverSeq: serverSeq ?? this.serverSeq,
      status: status ?? this.status,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      reactionsJson: reactionsJson ?? this.reactionsJson,
      isStarred: isStarred ?? this.isStarred,
      isViewOnce: isViewOnce ?? this.isViewOnce,
      disappearsAt: disappearsAt ?? this.disappearsAt,
      isDeleted: isDeleted ?? this.isDeleted,
      serverContent: serverContent ?? this.serverContent,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<String>(senderId.value);
    }
    if (senderDeviceId.present) {
      map['sender_device_id'] = Variable<String>(senderDeviceId.value);
    }
    if (messageType.present) {
      map['message_type'] = Variable<String>(messageType.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (serverSeq.present) {
      map['server_seq'] = Variable<int>(serverSeq.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (replyToMessageId.present) {
      map['reply_to_message_id'] = Variable<String>(replyToMessageId.value);
    }
    if (reactionsJson.present) {
      map['reactions_json'] = Variable<String>(reactionsJson.value);
    }
    if (isStarred.present) {
      map['is_starred'] = Variable<bool>(isStarred.value);
    }
    if (isViewOnce.present) {
      map['is_view_once'] = Variable<bool>(isViewOnce.value);
    }
    if (disappearsAt.present) {
      map['disappears_at'] = Variable<int>(disappearsAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (serverContent.present) {
      map['server_content'] = Variable<String>(serverContent.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('senderId: $senderId, ')
          ..write('senderDeviceId: $senderDeviceId, ')
          ..write('messageType: $messageType, ')
          ..write('role: $role, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('status: $status, ')
          ..write('replyToMessageId: $replyToMessageId, ')
          ..write('reactionsJson: $reactionsJson, ')
          ..write('isStarred: $isStarred, ')
          ..write('isViewOnce: $isViewOnce, ')
          ..write('disappearsAt: $disappearsAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('serverContent: $serverContent, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessageCiphertextsTable extends MessageCiphertexts
    with TableInfo<$MessageCiphertextsTable, MessageCiphertextRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessageCiphertextsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _messageIdMeta =
      const VerificationMeta('messageId');
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
      'message_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES messages (id)'));
  static const VerificationMeta _recipientIdMeta =
      const VerificationMeta('recipientId');
  @override
  late final GeneratedColumn<String> recipientId = GeneratedColumn<String>(
      'recipient_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recipientDeviceIdMeta =
      const VerificationMeta('recipientDeviceId');
  @override
  late final GeneratedColumn<int> recipientDeviceId = GeneratedColumn<int>(
      'recipient_device_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _ciphertextMeta =
      const VerificationMeta('ciphertext');
  @override
  late final GeneratedColumn<String> ciphertext = GeneratedColumn<String>(
      'ciphertext', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ratchetHeaderMeta =
      const VerificationMeta('ratchetHeader');
  @override
  late final GeneratedColumn<String> ratchetHeader = GeneratedColumn<String>(
      'ratchet_header', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        messageId,
        recipientId,
        recipientDeviceId,
        ciphertext,
        ratchetHeader
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message_ciphertexts';
  @override
  VerificationContext validateIntegrity(
      Insertable<MessageCiphertextRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(_messageIdMeta,
          messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta));
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('recipient_id')) {
      context.handle(
          _recipientIdMeta,
          recipientId.isAcceptableOrUnknown(
              data['recipient_id']!, _recipientIdMeta));
    } else if (isInserting) {
      context.missing(_recipientIdMeta);
    }
    if (data.containsKey('recipient_device_id')) {
      context.handle(
          _recipientDeviceIdMeta,
          recipientDeviceId.isAcceptableOrUnknown(
              data['recipient_device_id']!, _recipientDeviceIdMeta));
    } else if (isInserting) {
      context.missing(_recipientDeviceIdMeta);
    }
    if (data.containsKey('ciphertext')) {
      context.handle(
          _ciphertextMeta,
          ciphertext.isAcceptableOrUnknown(
              data['ciphertext']!, _ciphertextMeta));
    } else if (isInserting) {
      context.missing(_ciphertextMeta);
    }
    if (data.containsKey('ratchet_header')) {
      context.handle(
          _ratchetHeaderMeta,
          ratchetHeader.isAcceptableOrUnknown(
              data['ratchet_header']!, _ratchetHeaderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MessageCiphertextRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageCiphertextRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      messageId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message_id'])!,
      recipientId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recipient_id'])!,
      recipientDeviceId: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}recipient_device_id'])!,
      ciphertext: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ciphertext'])!,
      ratchetHeader: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ratchet_header']),
    );
  }

  @override
  $MessageCiphertextsTable createAlias(String alias) {
    return $MessageCiphertextsTable(attachedDatabase, alias);
  }
}

class MessageCiphertextRow extends DataClass
    implements Insertable<MessageCiphertextRow> {
  /// Row ID (UUID).
  final String id;

  /// References [Messages.id].
  final String messageId;

  /// Recipient user ID.
  final String recipientId;

  /// Recipient device ID.
  final int recipientDeviceId;

  /// Encrypted ciphertext payload.
  final String ciphertext;

  /// JSON-encoded ratchet header, if applicable.
  final String? ratchetHeader;
  const MessageCiphertextRow(
      {required this.id,
      required this.messageId,
      required this.recipientId,
      required this.recipientDeviceId,
      required this.ciphertext,
      this.ratchetHeader});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['message_id'] = Variable<String>(messageId);
    map['recipient_id'] = Variable<String>(recipientId);
    map['recipient_device_id'] = Variable<int>(recipientDeviceId);
    map['ciphertext'] = Variable<String>(ciphertext);
    if (!nullToAbsent || ratchetHeader != null) {
      map['ratchet_header'] = Variable<String>(ratchetHeader);
    }
    return map;
  }

  MessageCiphertextsCompanion toCompanion(bool nullToAbsent) {
    return MessageCiphertextsCompanion(
      id: Value(id),
      messageId: Value(messageId),
      recipientId: Value(recipientId),
      recipientDeviceId: Value(recipientDeviceId),
      ciphertext: Value(ciphertext),
      ratchetHeader: ratchetHeader == null && nullToAbsent
          ? const Value.absent()
          : Value(ratchetHeader),
    );
  }

  factory MessageCiphertextRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageCiphertextRow(
      id: serializer.fromJson<String>(json['id']),
      messageId: serializer.fromJson<String>(json['messageId']),
      recipientId: serializer.fromJson<String>(json['recipientId']),
      recipientDeviceId: serializer.fromJson<int>(json['recipientDeviceId']),
      ciphertext: serializer.fromJson<String>(json['ciphertext']),
      ratchetHeader: serializer.fromJson<String?>(json['ratchetHeader']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'messageId': serializer.toJson<String>(messageId),
      'recipientId': serializer.toJson<String>(recipientId),
      'recipientDeviceId': serializer.toJson<int>(recipientDeviceId),
      'ciphertext': serializer.toJson<String>(ciphertext),
      'ratchetHeader': serializer.toJson<String?>(ratchetHeader),
    };
  }

  MessageCiphertextRow copyWith(
          {String? id,
          String? messageId,
          String? recipientId,
          int? recipientDeviceId,
          String? ciphertext,
          Value<String?> ratchetHeader = const Value.absent()}) =>
      MessageCiphertextRow(
        id: id ?? this.id,
        messageId: messageId ?? this.messageId,
        recipientId: recipientId ?? this.recipientId,
        recipientDeviceId: recipientDeviceId ?? this.recipientDeviceId,
        ciphertext: ciphertext ?? this.ciphertext,
        ratchetHeader:
            ratchetHeader.present ? ratchetHeader.value : this.ratchetHeader,
      );
  MessageCiphertextRow copyWithCompanion(MessageCiphertextsCompanion data) {
    return MessageCiphertextRow(
      id: data.id.present ? data.id.value : this.id,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      recipientId:
          data.recipientId.present ? data.recipientId.value : this.recipientId,
      recipientDeviceId: data.recipientDeviceId.present
          ? data.recipientDeviceId.value
          : this.recipientDeviceId,
      ciphertext:
          data.ciphertext.present ? data.ciphertext.value : this.ciphertext,
      ratchetHeader: data.ratchetHeader.present
          ? data.ratchetHeader.value
          : this.ratchetHeader,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageCiphertextRow(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('recipientId: $recipientId, ')
          ..write('recipientDeviceId: $recipientDeviceId, ')
          ..write('ciphertext: $ciphertext, ')
          ..write('ratchetHeader: $ratchetHeader')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, messageId, recipientId, recipientDeviceId, ciphertext, ratchetHeader);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageCiphertextRow &&
          other.id == this.id &&
          other.messageId == this.messageId &&
          other.recipientId == this.recipientId &&
          other.recipientDeviceId == this.recipientDeviceId &&
          other.ciphertext == this.ciphertext &&
          other.ratchetHeader == this.ratchetHeader);
}

class MessageCiphertextsCompanion
    extends UpdateCompanion<MessageCiphertextRow> {
  final Value<String> id;
  final Value<String> messageId;
  final Value<String> recipientId;
  final Value<int> recipientDeviceId;
  final Value<String> ciphertext;
  final Value<String?> ratchetHeader;
  final Value<int> rowid;
  const MessageCiphertextsCompanion({
    this.id = const Value.absent(),
    this.messageId = const Value.absent(),
    this.recipientId = const Value.absent(),
    this.recipientDeviceId = const Value.absent(),
    this.ciphertext = const Value.absent(),
    this.ratchetHeader = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessageCiphertextsCompanion.insert({
    required String id,
    required String messageId,
    required String recipientId,
    required int recipientDeviceId,
    required String ciphertext,
    this.ratchetHeader = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        messageId = Value(messageId),
        recipientId = Value(recipientId),
        recipientDeviceId = Value(recipientDeviceId),
        ciphertext = Value(ciphertext);
  static Insertable<MessageCiphertextRow> custom({
    Expression<String>? id,
    Expression<String>? messageId,
    Expression<String>? recipientId,
    Expression<int>? recipientDeviceId,
    Expression<String>? ciphertext,
    Expression<String>? ratchetHeader,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (messageId != null) 'message_id': messageId,
      if (recipientId != null) 'recipient_id': recipientId,
      if (recipientDeviceId != null) 'recipient_device_id': recipientDeviceId,
      if (ciphertext != null) 'ciphertext': ciphertext,
      if (ratchetHeader != null) 'ratchet_header': ratchetHeader,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessageCiphertextsCompanion copyWith(
      {Value<String>? id,
      Value<String>? messageId,
      Value<String>? recipientId,
      Value<int>? recipientDeviceId,
      Value<String>? ciphertext,
      Value<String?>? ratchetHeader,
      Value<int>? rowid}) {
    return MessageCiphertextsCompanion(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      recipientId: recipientId ?? this.recipientId,
      recipientDeviceId: recipientDeviceId ?? this.recipientDeviceId,
      ciphertext: ciphertext ?? this.ciphertext,
      ratchetHeader: ratchetHeader ?? this.ratchetHeader,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (recipientId.present) {
      map['recipient_id'] = Variable<String>(recipientId.value);
    }
    if (recipientDeviceId.present) {
      map['recipient_device_id'] = Variable<int>(recipientDeviceId.value);
    }
    if (ciphertext.present) {
      map['ciphertext'] = Variable<String>(ciphertext.value);
    }
    if (ratchetHeader.present) {
      map['ratchet_header'] = Variable<String>(ratchetHeader.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessageCiphertextsCompanion(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('recipientId: $recipientId, ')
          ..write('recipientDeviceId: $recipientDeviceId, ')
          ..write('ciphertext: $ciphertext, ')
          ..write('ratchetHeader: $ratchetHeader, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConversationsTable extends Conversations
    with TableInfo<$ConversationsTable, ConversationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _participantIdsJsonMeta =
      const VerificationMeta('participantIdsJson');
  @override
  late final GeneratedColumn<String> participantIdsJson =
      GeneratedColumn<String>('participant_ids_json', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastMessageIdMeta =
      const VerificationMeta('lastMessageId');
  @override
  late final GeneratedColumn<String> lastMessageId = GeneratedColumn<String>(
      'last_message_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastMessageTextMeta =
      const VerificationMeta('lastMessageText');
  @override
  late final GeneratedColumn<String> lastMessageText = GeneratedColumn<String>(
      'last_message_text', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastMessageTimestampMeta =
      const VerificationMeta('lastMessageTimestamp');
  @override
  late final GeneratedColumn<DateTime> lastMessageTimestamp =
      GeneratedColumn<DateTime>('last_message_timestamp', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _unreadCountMeta =
      const VerificationMeta('unreadCount');
  @override
  late final GeneratedColumn<int> unreadCount = GeneratedColumn<int>(
      'unread_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _isPinnedMeta =
      const VerificationMeta('isPinned');
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
      'is_pinned', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_pinned" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isArchivedMeta =
      const VerificationMeta('isArchived');
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
      'is_archived', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_archived" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isMutedMeta =
      const VerificationMeta('isMuted');
  @override
  late final GeneratedColumn<bool> isMuted = GeneratedColumn<bool>(
      'is_muted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_muted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _muteUntilMeta =
      const VerificationMeta('muteUntil');
  @override
  late final GeneratedColumn<DateTime> muteUntil = GeneratedColumn<DateTime>(
      'mute_until', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _disappearingMessageTimerMsMeta =
      const VerificationMeta('disappearingMessageTimerMs');
  @override
  late final GeneratedColumn<int> disappearingMessageTimerMs =
      GeneratedColumn<int>('disappearing_message_timer_ms', aliasedName, true,
          type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _isEncryptedMeta =
      const VerificationMeta('isEncrypted');
  @override
  late final GeneratedColumn<bool> isEncrypted = GeneratedColumn<bool>(
      'is_encrypted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_encrypted" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        type,
        participantIdsJson,
        lastMessageId,
        lastMessageText,
        lastMessageTimestamp,
        unreadCount,
        isPinned,
        isArchived,
        isMuted,
        muteUntil,
        disappearingMessageTimerMs,
        isEncrypted,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversations';
  @override
  VerificationContext validateIntegrity(Insertable<ConversationRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('participant_ids_json')) {
      context.handle(
          _participantIdsJsonMeta,
          participantIdsJson.isAcceptableOrUnknown(
              data['participant_ids_json']!, _participantIdsJsonMeta));
    } else if (isInserting) {
      context.missing(_participantIdsJsonMeta);
    }
    if (data.containsKey('last_message_id')) {
      context.handle(
          _lastMessageIdMeta,
          lastMessageId.isAcceptableOrUnknown(
              data['last_message_id']!, _lastMessageIdMeta));
    }
    if (data.containsKey('last_message_text')) {
      context.handle(
          _lastMessageTextMeta,
          lastMessageText.isAcceptableOrUnknown(
              data['last_message_text']!, _lastMessageTextMeta));
    }
    if (data.containsKey('last_message_timestamp')) {
      context.handle(
          _lastMessageTimestampMeta,
          lastMessageTimestamp.isAcceptableOrUnknown(
              data['last_message_timestamp']!, _lastMessageTimestampMeta));
    }
    if (data.containsKey('unread_count')) {
      context.handle(
          _unreadCountMeta,
          unreadCount.isAcceptableOrUnknown(
              data['unread_count']!, _unreadCountMeta));
    }
    if (data.containsKey('is_pinned')) {
      context.handle(_isPinnedMeta,
          isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta));
    }
    if (data.containsKey('is_archived')) {
      context.handle(
          _isArchivedMeta,
          isArchived.isAcceptableOrUnknown(
              data['is_archived']!, _isArchivedMeta));
    }
    if (data.containsKey('is_muted')) {
      context.handle(_isMutedMeta,
          isMuted.isAcceptableOrUnknown(data['is_muted']!, _isMutedMeta));
    }
    if (data.containsKey('mute_until')) {
      context.handle(_muteUntilMeta,
          muteUntil.isAcceptableOrUnknown(data['mute_until']!, _muteUntilMeta));
    }
    if (data.containsKey('disappearing_message_timer_ms')) {
      context.handle(
          _disappearingMessageTimerMsMeta,
          disappearingMessageTimerMs.isAcceptableOrUnknown(
              data['disappearing_message_timer_ms']!,
              _disappearingMessageTimerMsMeta));
    }
    if (data.containsKey('is_encrypted')) {
      context.handle(
          _isEncryptedMeta,
          isEncrypted.isAcceptableOrUnknown(
              data['is_encrypted']!, _isEncryptedMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConversationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      participantIdsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}participant_ids_json'])!,
      lastMessageId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_message_id']),
      lastMessageText: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}last_message_text']),
      lastMessageTimestamp: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}last_message_timestamp']),
      unreadCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}unread_count'])!,
      isPinned: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_pinned'])!,
      isArchived: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_archived'])!,
      isMuted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_muted'])!,
      muteUntil: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}mute_until']),
      disappearingMessageTimerMs: attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}disappearing_message_timer_ms']),
      isEncrypted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_encrypted'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ConversationsTable createAlias(String alias) {
    return $ConversationsTable(attachedDatabase, alias);
  }
}

class ConversationRow extends DataClass implements Insertable<ConversationRow> {
  /// Conversation ID.
  final String id;

  /// Type: oneToOne or group.
  final String type;

  /// JSON array of participant user IDs.
  final String participantIdsJson;

  /// Last message ID for display ordering.
  final String? lastMessageId;

  /// Last message preview text (decrypted client-side, stored for list UI).
  final String? lastMessageText;

  /// Timestamp of the last message.
  final DateTime? lastMessageTimestamp;

  /// Number of unread messages.
  final int unreadCount;

  /// Whether this conversation is pinned.
  final bool isPinned;

  /// Whether this conversation is archived.
  final bool isArchived;

  /// Whether this conversation is muted.
  final bool isMuted;

  /// When the mute expires, if set.
  final DateTime? muteUntil;

  /// Disappearing message timer in milliseconds.
  final int? disappearingMessageTimerMs;

  /// Whether the conversation is encrypted.
  final bool isEncrypted;

  /// When the conversation was created.
  final DateTime createdAt;

  /// When the conversation was last updated.
  final DateTime updatedAt;
  const ConversationRow(
      {required this.id,
      required this.type,
      required this.participantIdsJson,
      this.lastMessageId,
      this.lastMessageText,
      this.lastMessageTimestamp,
      required this.unreadCount,
      required this.isPinned,
      required this.isArchived,
      required this.isMuted,
      this.muteUntil,
      this.disappearingMessageTimerMs,
      required this.isEncrypted,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['participant_ids_json'] = Variable<String>(participantIdsJson);
    if (!nullToAbsent || lastMessageId != null) {
      map['last_message_id'] = Variable<String>(lastMessageId);
    }
    if (!nullToAbsent || lastMessageText != null) {
      map['last_message_text'] = Variable<String>(lastMessageText);
    }
    if (!nullToAbsent || lastMessageTimestamp != null) {
      map['last_message_timestamp'] = Variable<DateTime>(lastMessageTimestamp);
    }
    map['unread_count'] = Variable<int>(unreadCount);
    map['is_pinned'] = Variable<bool>(isPinned);
    map['is_archived'] = Variable<bool>(isArchived);
    map['is_muted'] = Variable<bool>(isMuted);
    if (!nullToAbsent || muteUntil != null) {
      map['mute_until'] = Variable<DateTime>(muteUntil);
    }
    if (!nullToAbsent || disappearingMessageTimerMs != null) {
      map['disappearing_message_timer_ms'] =
          Variable<int>(disappearingMessageTimerMs);
    }
    map['is_encrypted'] = Variable<bool>(isEncrypted);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ConversationsCompanion toCompanion(bool nullToAbsent) {
    return ConversationsCompanion(
      id: Value(id),
      type: Value(type),
      participantIdsJson: Value(participantIdsJson),
      lastMessageId: lastMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageId),
      lastMessageText: lastMessageText == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageText),
      lastMessageTimestamp: lastMessageTimestamp == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageTimestamp),
      unreadCount: Value(unreadCount),
      isPinned: Value(isPinned),
      isArchived: Value(isArchived),
      isMuted: Value(isMuted),
      muteUntil: muteUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(muteUntil),
      disappearingMessageTimerMs:
          disappearingMessageTimerMs == null && nullToAbsent
              ? const Value.absent()
              : Value(disappearingMessageTimerMs),
      isEncrypted: Value(isEncrypted),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ConversationRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationRow(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      participantIdsJson:
          serializer.fromJson<String>(json['participantIdsJson']),
      lastMessageId: serializer.fromJson<String?>(json['lastMessageId']),
      lastMessageText: serializer.fromJson<String?>(json['lastMessageText']),
      lastMessageTimestamp:
          serializer.fromJson<DateTime?>(json['lastMessageTimestamp']),
      unreadCount: serializer.fromJson<int>(json['unreadCount']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      isMuted: serializer.fromJson<bool>(json['isMuted']),
      muteUntil: serializer.fromJson<DateTime?>(json['muteUntil']),
      disappearingMessageTimerMs:
          serializer.fromJson<int?>(json['disappearingMessageTimerMs']),
      isEncrypted: serializer.fromJson<bool>(json['isEncrypted']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'participantIdsJson': serializer.toJson<String>(participantIdsJson),
      'lastMessageId': serializer.toJson<String?>(lastMessageId),
      'lastMessageText': serializer.toJson<String?>(lastMessageText),
      'lastMessageTimestamp':
          serializer.toJson<DateTime?>(lastMessageTimestamp),
      'unreadCount': serializer.toJson<int>(unreadCount),
      'isPinned': serializer.toJson<bool>(isPinned),
      'isArchived': serializer.toJson<bool>(isArchived),
      'isMuted': serializer.toJson<bool>(isMuted),
      'muteUntil': serializer.toJson<DateTime?>(muteUntil),
      'disappearingMessageTimerMs':
          serializer.toJson<int?>(disappearingMessageTimerMs),
      'isEncrypted': serializer.toJson<bool>(isEncrypted),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ConversationRow copyWith(
          {String? id,
          String? type,
          String? participantIdsJson,
          Value<String?> lastMessageId = const Value.absent(),
          Value<String?> lastMessageText = const Value.absent(),
          Value<DateTime?> lastMessageTimestamp = const Value.absent(),
          int? unreadCount,
          bool? isPinned,
          bool? isArchived,
          bool? isMuted,
          Value<DateTime?> muteUntil = const Value.absent(),
          Value<int?> disappearingMessageTimerMs = const Value.absent(),
          bool? isEncrypted,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      ConversationRow(
        id: id ?? this.id,
        type: type ?? this.type,
        participantIdsJson: participantIdsJson ?? this.participantIdsJson,
        lastMessageId:
            lastMessageId.present ? lastMessageId.value : this.lastMessageId,
        lastMessageText: lastMessageText.present
            ? lastMessageText.value
            : this.lastMessageText,
        lastMessageTimestamp: lastMessageTimestamp.present
            ? lastMessageTimestamp.value
            : this.lastMessageTimestamp,
        unreadCount: unreadCount ?? this.unreadCount,
        isPinned: isPinned ?? this.isPinned,
        isArchived: isArchived ?? this.isArchived,
        isMuted: isMuted ?? this.isMuted,
        muteUntil: muteUntil.present ? muteUntil.value : this.muteUntil,
        disappearingMessageTimerMs: disappearingMessageTimerMs.present
            ? disappearingMessageTimerMs.value
            : this.disappearingMessageTimerMs,
        isEncrypted: isEncrypted ?? this.isEncrypted,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ConversationRow copyWithCompanion(ConversationsCompanion data) {
    return ConversationRow(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      participantIdsJson: data.participantIdsJson.present
          ? data.participantIdsJson.value
          : this.participantIdsJson,
      lastMessageId: data.lastMessageId.present
          ? data.lastMessageId.value
          : this.lastMessageId,
      lastMessageText: data.lastMessageText.present
          ? data.lastMessageText.value
          : this.lastMessageText,
      lastMessageTimestamp: data.lastMessageTimestamp.present
          ? data.lastMessageTimestamp.value
          : this.lastMessageTimestamp,
      unreadCount:
          data.unreadCount.present ? data.unreadCount.value : this.unreadCount,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      isArchived:
          data.isArchived.present ? data.isArchived.value : this.isArchived,
      isMuted: data.isMuted.present ? data.isMuted.value : this.isMuted,
      muteUntil: data.muteUntil.present ? data.muteUntil.value : this.muteUntil,
      disappearingMessageTimerMs: data.disappearingMessageTimerMs.present
          ? data.disappearingMessageTimerMs.value
          : this.disappearingMessageTimerMs,
      isEncrypted:
          data.isEncrypted.present ? data.isEncrypted.value : this.isEncrypted,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationRow(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('participantIdsJson: $participantIdsJson, ')
          ..write('lastMessageId: $lastMessageId, ')
          ..write('lastMessageText: $lastMessageText, ')
          ..write('lastMessageTimestamp: $lastMessageTimestamp, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('isPinned: $isPinned, ')
          ..write('isArchived: $isArchived, ')
          ..write('isMuted: $isMuted, ')
          ..write('muteUntil: $muteUntil, ')
          ..write('disappearingMessageTimerMs: $disappearingMessageTimerMs, ')
          ..write('isEncrypted: $isEncrypted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      type,
      participantIdsJson,
      lastMessageId,
      lastMessageText,
      lastMessageTimestamp,
      unreadCount,
      isPinned,
      isArchived,
      isMuted,
      muteUntil,
      disappearingMessageTimerMs,
      isEncrypted,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationRow &&
          other.id == this.id &&
          other.type == this.type &&
          other.participantIdsJson == this.participantIdsJson &&
          other.lastMessageId == this.lastMessageId &&
          other.lastMessageText == this.lastMessageText &&
          other.lastMessageTimestamp == this.lastMessageTimestamp &&
          other.unreadCount == this.unreadCount &&
          other.isPinned == this.isPinned &&
          other.isArchived == this.isArchived &&
          other.isMuted == this.isMuted &&
          other.muteUntil == this.muteUntil &&
          other.disappearingMessageTimerMs == this.disappearingMessageTimerMs &&
          other.isEncrypted == this.isEncrypted &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ConversationsCompanion extends UpdateCompanion<ConversationRow> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> participantIdsJson;
  final Value<String?> lastMessageId;
  final Value<String?> lastMessageText;
  final Value<DateTime?> lastMessageTimestamp;
  final Value<int> unreadCount;
  final Value<bool> isPinned;
  final Value<bool> isArchived;
  final Value<bool> isMuted;
  final Value<DateTime?> muteUntil;
  final Value<int?> disappearingMessageTimerMs;
  final Value<bool> isEncrypted;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ConversationsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.participantIdsJson = const Value.absent(),
    this.lastMessageId = const Value.absent(),
    this.lastMessageText = const Value.absent(),
    this.lastMessageTimestamp = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.isMuted = const Value.absent(),
    this.muteUntil = const Value.absent(),
    this.disappearingMessageTimerMs = const Value.absent(),
    this.isEncrypted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationsCompanion.insert({
    required String id,
    required String type,
    required String participantIdsJson,
    this.lastMessageId = const Value.absent(),
    this.lastMessageText = const Value.absent(),
    this.lastMessageTimestamp = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.isMuted = const Value.absent(),
    this.muteUntil = const Value.absent(),
    this.disappearingMessageTimerMs = const Value.absent(),
    this.isEncrypted = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        type = Value(type),
        participantIdsJson = Value(participantIdsJson),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<ConversationRow> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? participantIdsJson,
    Expression<String>? lastMessageId,
    Expression<String>? lastMessageText,
    Expression<DateTime>? lastMessageTimestamp,
    Expression<int>? unreadCount,
    Expression<bool>? isPinned,
    Expression<bool>? isArchived,
    Expression<bool>? isMuted,
    Expression<DateTime>? muteUntil,
    Expression<int>? disappearingMessageTimerMs,
    Expression<bool>? isEncrypted,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (participantIdsJson != null)
        'participant_ids_json': participantIdsJson,
      if (lastMessageId != null) 'last_message_id': lastMessageId,
      if (lastMessageText != null) 'last_message_text': lastMessageText,
      if (lastMessageTimestamp != null)
        'last_message_timestamp': lastMessageTimestamp,
      if (unreadCount != null) 'unread_count': unreadCount,
      if (isPinned != null) 'is_pinned': isPinned,
      if (isArchived != null) 'is_archived': isArchived,
      if (isMuted != null) 'is_muted': isMuted,
      if (muteUntil != null) 'mute_until': muteUntil,
      if (disappearingMessageTimerMs != null)
        'disappearing_message_timer_ms': disappearingMessageTimerMs,
      if (isEncrypted != null) 'is_encrypted': isEncrypted,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationsCompanion copyWith(
      {Value<String>? id,
      Value<String>? type,
      Value<String>? participantIdsJson,
      Value<String?>? lastMessageId,
      Value<String?>? lastMessageText,
      Value<DateTime?>? lastMessageTimestamp,
      Value<int>? unreadCount,
      Value<bool>? isPinned,
      Value<bool>? isArchived,
      Value<bool>? isMuted,
      Value<DateTime?>? muteUntil,
      Value<int?>? disappearingMessageTimerMs,
      Value<bool>? isEncrypted,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return ConversationsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      participantIdsJson: participantIdsJson ?? this.participantIdsJson,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isMuted: isMuted ?? this.isMuted,
      muteUntil: muteUntil ?? this.muteUntil,
      disappearingMessageTimerMs:
          disappearingMessageTimerMs ?? this.disappearingMessageTimerMs,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (participantIdsJson.present) {
      map['participant_ids_json'] = Variable<String>(participantIdsJson.value);
    }
    if (lastMessageId.present) {
      map['last_message_id'] = Variable<String>(lastMessageId.value);
    }
    if (lastMessageText.present) {
      map['last_message_text'] = Variable<String>(lastMessageText.value);
    }
    if (lastMessageTimestamp.present) {
      map['last_message_timestamp'] =
          Variable<DateTime>(lastMessageTimestamp.value);
    }
    if (unreadCount.present) {
      map['unread_count'] = Variable<int>(unreadCount.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (isMuted.present) {
      map['is_muted'] = Variable<bool>(isMuted.value);
    }
    if (muteUntil.present) {
      map['mute_until'] = Variable<DateTime>(muteUntil.value);
    }
    if (disappearingMessageTimerMs.present) {
      map['disappearing_message_timer_ms'] =
          Variable<int>(disappearingMessageTimerMs.value);
    }
    if (isEncrypted.present) {
      map['is_encrypted'] = Variable<bool>(isEncrypted.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('participantIdsJson: $participantIdsJson, ')
          ..write('lastMessageId: $lastMessageId, ')
          ..write('lastMessageText: $lastMessageText, ')
          ..write('lastMessageTimestamp: $lastMessageTimestamp, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('isPinned: $isPinned, ')
          ..write('isArchived: $isArchived, ')
          ..write('isMuted: $isMuted, ')
          ..write('muteUntil: $muteUntil, ')
          ..write('disappearingMessageTimerMs: $disappearingMessageTimerMs, ')
          ..write('isEncrypted: $isEncrypted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReceiptsTable extends Receipts
    with TableInfo<$ReceiptsTable, ReceiptRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReceiptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIdMeta =
      const VerificationMeta('messageId');
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
      'message_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _deliveredAtMeta =
      const VerificationMeta('deliveredAt');
  @override
  late final GeneratedColumn<DateTime> deliveredAt = GeneratedColumn<DateTime>(
      'delivered_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _readAtMeta = const VerificationMeta('readAt');
  @override
  late final GeneratedColumn<DateTime> readAt = GeneratedColumn<DateTime>(
      'read_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [messageId, userId, deviceId, deliveredAt, readAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'receipts';
  @override
  VerificationContext validateIntegrity(Insertable<ReceiptRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_id')) {
      context.handle(_messageIdMeta,
          messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta));
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('delivered_at')) {
      context.handle(
          _deliveredAtMeta,
          deliveredAt.isAcceptableOrUnknown(
              data['delivered_at']!, _deliveredAtMeta));
    }
    if (data.containsKey('read_at')) {
      context.handle(_readAtMeta,
          readAt.isAcceptableOrUnknown(data['read_at']!, _readAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId, userId, deviceId};
  @override
  ReceiptRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReceiptRow(
      messageId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      deliveredAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}delivered_at']),
      readAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}read_at']),
    );
  }

  @override
  $ReceiptsTable createAlias(String alias) {
    return $ReceiptsTable(attachedDatabase, alias);
  }
}

class ReceiptRow extends DataClass implements Insertable<ReceiptRow> {
  /// The message this receipt is for.
  final String messageId;

  /// The user who delivered/read.
  final String userId;

  /// The device that reported the receipt.
  final String deviceId;

  /// When the message was delivered.
  final DateTime? deliveredAt;

  /// When the message was read.
  final DateTime? readAt;
  const ReceiptRow(
      {required this.messageId,
      required this.userId,
      required this.deviceId,
      this.deliveredAt,
      this.readAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    map['user_id'] = Variable<String>(userId);
    map['device_id'] = Variable<String>(deviceId);
    if (!nullToAbsent || deliveredAt != null) {
      map['delivered_at'] = Variable<DateTime>(deliveredAt);
    }
    if (!nullToAbsent || readAt != null) {
      map['read_at'] = Variable<DateTime>(readAt);
    }
    return map;
  }

  ReceiptsCompanion toCompanion(bool nullToAbsent) {
    return ReceiptsCompanion(
      messageId: Value(messageId),
      userId: Value(userId),
      deviceId: Value(deviceId),
      deliveredAt: deliveredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deliveredAt),
      readAt:
          readAt == null && nullToAbsent ? const Value.absent() : Value(readAt),
    );
  }

  factory ReceiptRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReceiptRow(
      messageId: serializer.fromJson<String>(json['messageId']),
      userId: serializer.fromJson<String>(json['userId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      deliveredAt: serializer.fromJson<DateTime?>(json['deliveredAt']),
      readAt: serializer.fromJson<DateTime?>(json['readAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'messageId': serializer.toJson<String>(messageId),
      'userId': serializer.toJson<String>(userId),
      'deviceId': serializer.toJson<String>(deviceId),
      'deliveredAt': serializer.toJson<DateTime?>(deliveredAt),
      'readAt': serializer.toJson<DateTime?>(readAt),
    };
  }

  ReceiptRow copyWith(
          {String? messageId,
          String? userId,
          String? deviceId,
          Value<DateTime?> deliveredAt = const Value.absent(),
          Value<DateTime?> readAt = const Value.absent()}) =>
      ReceiptRow(
        messageId: messageId ?? this.messageId,
        userId: userId ?? this.userId,
        deviceId: deviceId ?? this.deviceId,
        deliveredAt: deliveredAt.present ? deliveredAt.value : this.deliveredAt,
        readAt: readAt.present ? readAt.value : this.readAt,
      );
  ReceiptRow copyWithCompanion(ReceiptsCompanion data) {
    return ReceiptRow(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deliveredAt:
          data.deliveredAt.present ? data.deliveredAt.value : this.deliveredAt,
      readAt: data.readAt.present ? data.readAt.value : this.readAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReceiptRow(')
          ..write('messageId: $messageId, ')
          ..write('userId: $userId, ')
          ..write('deviceId: $deviceId, ')
          ..write('deliveredAt: $deliveredAt, ')
          ..write('readAt: $readAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(messageId, userId, deviceId, deliveredAt, readAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReceiptRow &&
          other.messageId == this.messageId &&
          other.userId == this.userId &&
          other.deviceId == this.deviceId &&
          other.deliveredAt == this.deliveredAt &&
          other.readAt == this.readAt);
}

class ReceiptsCompanion extends UpdateCompanion<ReceiptRow> {
  final Value<String> messageId;
  final Value<String> userId;
  final Value<String> deviceId;
  final Value<DateTime?> deliveredAt;
  final Value<DateTime?> readAt;
  final Value<int> rowid;
  const ReceiptsCompanion({
    this.messageId = const Value.absent(),
    this.userId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deliveredAt = const Value.absent(),
    this.readAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReceiptsCompanion.insert({
    required String messageId,
    required String userId,
    required String deviceId,
    this.deliveredAt = const Value.absent(),
    this.readAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : messageId = Value(messageId),
        userId = Value(userId),
        deviceId = Value(deviceId);
  static Insertable<ReceiptRow> custom({
    Expression<String>? messageId,
    Expression<String>? userId,
    Expression<String>? deviceId,
    Expression<DateTime>? deliveredAt,
    Expression<DateTime>? readAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (userId != null) 'user_id': userId,
      if (deviceId != null) 'device_id': deviceId,
      if (deliveredAt != null) 'delivered_at': deliveredAt,
      if (readAt != null) 'read_at': readAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReceiptsCompanion copyWith(
      {Value<String>? messageId,
      Value<String>? userId,
      Value<String>? deviceId,
      Value<DateTime?>? deliveredAt,
      Value<DateTime?>? readAt,
      Value<int>? rowid}) {
    return ReceiptsCompanion(
      messageId: messageId ?? this.messageId,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deliveredAt.present) {
      map['delivered_at'] = Variable<DateTime>(deliveredAt.value);
    }
    if (readAt.present) {
      map['read_at'] = Variable<DateTime>(readAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReceiptsCompanion(')
          ..write('messageId: $messageId, ')
          ..write('userId: $userId, ')
          ..write('deviceId: $deviceId, ')
          ..write('deliveredAt: $deliveredAt, ')
          ..write('readAt: $readAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxItemsTable extends OutboxItems
    with TableInfo<$OutboxItemsTable, OutboxItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'conversation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _encryptedEnvelopeMeta =
      const VerificationMeta('encryptedEnvelope');
  @override
  late final GeneratedColumn<Uint8List> encryptedEnvelope =
      GeneratedColumn<Uint8List>('encrypted_envelope', aliasedName, false,
          type: DriftSqlType.blob, requiredDuringInsert: true);
  static const VerificationMeta _recipientDeviceIdsMeta =
      const VerificationMeta('recipientDeviceIds');
  @override
  late final GeneratedColumn<String> recipientDeviceIds =
      GeneratedColumn<String>('recipient_device_ids', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _retryCountMeta =
      const VerificationMeta('retryCount');
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
      'retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _nextRetryAtMeta =
      const VerificationMeta('nextRetryAt');
  @override
  late final GeneratedColumn<DateTime> nextRetryAt = GeneratedColumn<DateTime>(
      'next_retry_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        groupId,
        encryptedEnvelope,
        recipientDeviceIds,
        retryCount,
        createdAt,
        nextRetryAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_items';
  @override
  VerificationContext validateIntegrity(Insertable<OutboxItemRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
          _groupIdMeta,
          groupId.isAcceptableOrUnknown(
              data['conversation_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('encrypted_envelope')) {
      context.handle(
          _encryptedEnvelopeMeta,
          encryptedEnvelope.isAcceptableOrUnknown(
              data['encrypted_envelope']!, _encryptedEnvelopeMeta));
    } else if (isInserting) {
      context.missing(_encryptedEnvelopeMeta);
    }
    if (data.containsKey('recipient_device_ids')) {
      context.handle(
          _recipientDeviceIdsMeta,
          recipientDeviceIds.isAcceptableOrUnknown(
              data['recipient_device_ids']!, _recipientDeviceIdsMeta));
    } else if (isInserting) {
      context.missing(_recipientDeviceIdsMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
          _retryCountMeta,
          retryCount.isAcceptableOrUnknown(
              data['retry_count']!, _retryCountMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('next_retry_at')) {
      context.handle(
          _nextRetryAtMeta,
          nextRetryAt.isAcceptableOrUnknown(
              data['next_retry_at']!, _nextRetryAtMeta));
    } else if (isInserting) {
      context.missing(_nextRetryAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxItemRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      groupId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}conversation_id'])!,
      encryptedEnvelope: attachedDatabase.typeMapping.read(
          DriftSqlType.blob, data['${effectivePrefix}encrypted_envelope'])!,
      recipientDeviceIds: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}recipient_device_ids'])!,
      retryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}retry_count'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      nextRetryAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}next_retry_at'])!,
    );
  }

  @override
  $OutboxItemsTable createAlias(String alias) {
    return $OutboxItemsTable(attachedDatabase, alias);
  }
}

class OutboxItemRow extends DataClass implements Insertable<OutboxItemRow> {
  /// Outbox item ID (same as the message UUID).
  final String id;

  /// Which conversation this belongs to.
  final String groupId;

  /// The encrypted envelope blob ready to send.
  final Uint8List encryptedEnvelope;

  /// JSON array of target "userId:deviceId" strings.
  final String recipientDeviceIds;

  /// Number of send attempts so far.
  final int retryCount;

  /// When this item was queued.
  final DateTime createdAt;

  /// When the next retry is allowed.
  final DateTime nextRetryAt;
  const OutboxItemRow(
      {required this.id,
      required this.groupId,
      required this.encryptedEnvelope,
      required this.recipientDeviceIds,
      required this.retryCount,
      required this.createdAt,
      required this.nextRetryAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(groupId);
    map['encrypted_envelope'] = Variable<Uint8List>(encryptedEnvelope);
    map['recipient_device_ids'] = Variable<String>(recipientDeviceIds);
    map['retry_count'] = Variable<int>(retryCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['next_retry_at'] = Variable<DateTime>(nextRetryAt);
    return map;
  }

  OutboxItemsCompanion toCompanion(bool nullToAbsent) {
    return OutboxItemsCompanion(
      id: Value(id),
      groupId: Value(groupId),
      encryptedEnvelope: Value(encryptedEnvelope),
      recipientDeviceIds: Value(recipientDeviceIds),
      retryCount: Value(retryCount),
      createdAt: Value(createdAt),
      nextRetryAt: Value(nextRetryAt),
    );
  }

  factory OutboxItemRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxItemRow(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      encryptedEnvelope:
          serializer.fromJson<Uint8List>(json['encryptedEnvelope']),
      recipientDeviceIds:
          serializer.fromJson<String>(json['recipientDeviceIds']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      nextRetryAt: serializer.fromJson<DateTime>(json['nextRetryAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'encryptedEnvelope': serializer.toJson<Uint8List>(encryptedEnvelope),
      'recipientDeviceIds': serializer.toJson<String>(recipientDeviceIds),
      'retryCount': serializer.toJson<int>(retryCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'nextRetryAt': serializer.toJson<DateTime>(nextRetryAt),
    };
  }

  OutboxItemRow copyWith(
          {String? id,
          String? groupId,
          Uint8List? encryptedEnvelope,
          String? recipientDeviceIds,
          int? retryCount,
          DateTime? createdAt,
          DateTime? nextRetryAt}) =>
      OutboxItemRow(
        id: id ?? this.id,
        groupId: groupId ?? this.groupId,
        encryptedEnvelope: encryptedEnvelope ?? this.encryptedEnvelope,
        recipientDeviceIds: recipientDeviceIds ?? this.recipientDeviceIds,
        retryCount: retryCount ?? this.retryCount,
        createdAt: createdAt ?? this.createdAt,
        nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      );
  OutboxItemRow copyWithCompanion(OutboxItemsCompanion data) {
    return OutboxItemRow(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present
          ? data.groupId.value
          : this.groupId,
      encryptedEnvelope: data.encryptedEnvelope.present
          ? data.encryptedEnvelope.value
          : this.encryptedEnvelope,
      recipientDeviceIds: data.recipientDeviceIds.present
          ? data.recipientDeviceIds.value
          : this.recipientDeviceIds,
      retryCount:
          data.retryCount.present ? data.retryCount.value : this.retryCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      nextRetryAt:
          data.nextRetryAt.present ? data.nextRetryAt.value : this.nextRetryAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxItemRow(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('encryptedEnvelope: $encryptedEnvelope, ')
          ..write('recipientDeviceIds: $recipientDeviceIds, ')
          ..write('retryCount: $retryCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('nextRetryAt: $nextRetryAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      groupId,
      $driftBlobEquality.hash(encryptedEnvelope),
      recipientDeviceIds,
      retryCount,
      createdAt,
      nextRetryAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxItemRow &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          $driftBlobEquality.equals(
              other.encryptedEnvelope, this.encryptedEnvelope) &&
          other.recipientDeviceIds == this.recipientDeviceIds &&
          other.retryCount == this.retryCount &&
          other.createdAt == this.createdAt &&
          other.nextRetryAt == this.nextRetryAt);
}

class OutboxItemsCompanion extends UpdateCompanion<OutboxItemRow> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<Uint8List> encryptedEnvelope;
  final Value<String> recipientDeviceIds;
  final Value<int> retryCount;
  final Value<DateTime> createdAt;
  final Value<DateTime> nextRetryAt;
  final Value<int> rowid;
  const OutboxItemsCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.encryptedEnvelope = const Value.absent(),
    this.recipientDeviceIds = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxItemsCompanion.insert({
    required String id,
    required String groupId,
    required Uint8List encryptedEnvelope,
    required String recipientDeviceIds,
    this.retryCount = const Value.absent(),
    required DateTime createdAt,
    required DateTime nextRetryAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        groupId = Value(groupId),
        encryptedEnvelope = Value(encryptedEnvelope),
        recipientDeviceIds = Value(recipientDeviceIds),
        createdAt = Value(createdAt),
        nextRetryAt = Value(nextRetryAt);
  static Insertable<OutboxItemRow> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<Uint8List>? encryptedEnvelope,
    Expression<String>? recipientDeviceIds,
    Expression<int>? retryCount,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? nextRetryAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'conversation_id': groupId,
      if (encryptedEnvelope != null) 'encrypted_envelope': encryptedEnvelope,
      if (recipientDeviceIds != null)
        'recipient_device_ids': recipientDeviceIds,
      if (retryCount != null) 'retry_count': retryCount,
      if (createdAt != null) 'created_at': createdAt,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxItemsCompanion copyWith(
      {Value<String>? id,
      Value<String>? groupId,
      Value<Uint8List>? encryptedEnvelope,
      Value<String>? recipientDeviceIds,
      Value<int>? retryCount,
      Value<DateTime>? createdAt,
      Value<DateTime>? nextRetryAt,
      Value<int>? rowid}) {
    return OutboxItemsCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      encryptedEnvelope: encryptedEnvelope ?? this.encryptedEnvelope,
      recipientDeviceIds: recipientDeviceIds ?? this.recipientDeviceIds,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt ?? this.createdAt,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['conversation_id'] = Variable<String>(groupId.value);
    }
    if (encryptedEnvelope.present) {
      map['encrypted_envelope'] = Variable<Uint8List>(encryptedEnvelope.value);
    }
    if (recipientDeviceIds.present) {
      map['recipient_device_ids'] = Variable<String>(recipientDeviceIds.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxItemsCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('encryptedEnvelope: $encryptedEnvelope, ')
          ..write('recipientDeviceIds: $recipientDeviceIds, ')
          ..write('retryCount: $retryCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RatchetSessionsTable extends RatchetSessions
    with TableInfo<$RatchetSessionsTable, RatchetSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RatchetSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _encryptedStateMeta =
      const VerificationMeta('encryptedState');
  @override
  late final GeneratedColumn<Uint8List> encryptedState =
      GeneratedColumn<Uint8List>('encrypted_state', aliasedName, false,
          type: DriftSqlType.blob, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [sessionId, encryptedState, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ratchet_sessions';
  @override
  VerificationContext validateIntegrity(Insertable<RatchetSessionRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('encrypted_state')) {
      context.handle(
          _encryptedStateMeta,
          encryptedState.isAcceptableOrUnknown(
              data['encrypted_state']!, _encryptedStateMeta));
    } else if (isInserting) {
      context.missing(_encryptedStateMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId};
  @override
  RatchetSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RatchetSessionRow(
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      encryptedState: attachedDatabase.typeMapping
          .read(DriftSqlType.blob, data['${effectivePrefix}encrypted_state'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $RatchetSessionsTable createAlias(String alias) {
    return $RatchetSessionsTable(attachedDatabase, alias);
  }
}

class RatchetSessionRow extends DataClass
    implements Insertable<RatchetSessionRow> {
  /// Session key: "userId:deviceId" for 1:1, groupId for group.
  final String sessionId;

  /// Encrypted serialised state blob.
  final Uint8List encryptedState;

  /// When this session was last persisted.
  final DateTime updatedAt;
  const RatchetSessionRow(
      {required this.sessionId,
      required this.encryptedState,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['encrypted_state'] = Variable<Uint8List>(encryptedState);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RatchetSessionsCompanion toCompanion(bool nullToAbsent) {
    return RatchetSessionsCompanion(
      sessionId: Value(sessionId),
      encryptedState: Value(encryptedState),
      updatedAt: Value(updatedAt),
    );
  }

  factory RatchetSessionRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RatchetSessionRow(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      encryptedState: serializer.fromJson<Uint8List>(json['encryptedState']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'encryptedState': serializer.toJson<Uint8List>(encryptedState),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  RatchetSessionRow copyWith(
          {String? sessionId,
          Uint8List? encryptedState,
          DateTime? updatedAt}) =>
      RatchetSessionRow(
        sessionId: sessionId ?? this.sessionId,
        encryptedState: encryptedState ?? this.encryptedState,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  RatchetSessionRow copyWithCompanion(RatchetSessionsCompanion data) {
    return RatchetSessionRow(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      encryptedState: data.encryptedState.present
          ? data.encryptedState.value
          : this.encryptedState,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RatchetSessionRow(')
          ..write('sessionId: $sessionId, ')
          ..write('encryptedState: $encryptedState, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      sessionId, $driftBlobEquality.hash(encryptedState), updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RatchetSessionRow &&
          other.sessionId == this.sessionId &&
          $driftBlobEquality.equals(
              other.encryptedState, this.encryptedState) &&
          other.updatedAt == this.updatedAt);
}

class RatchetSessionsCompanion extends UpdateCompanion<RatchetSessionRow> {
  final Value<String> sessionId;
  final Value<Uint8List> encryptedState;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const RatchetSessionsCompanion({
    this.sessionId = const Value.absent(),
    this.encryptedState = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RatchetSessionsCompanion.insert({
    required String sessionId,
    required Uint8List encryptedState,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : sessionId = Value(sessionId),
        encryptedState = Value(encryptedState),
        updatedAt = Value(updatedAt);
  static Insertable<RatchetSessionRow> custom({
    Expression<String>? sessionId,
    Expression<Uint8List>? encryptedState,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (encryptedState != null) 'encrypted_state': encryptedState,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RatchetSessionsCompanion copyWith(
      {Value<String>? sessionId,
      Value<Uint8List>? encryptedState,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return RatchetSessionsCompanion(
      sessionId: sessionId ?? this.sessionId,
      encryptedState: encryptedState ?? this.encryptedState,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (encryptedState.present) {
      map['encrypted_state'] = Variable<Uint8List>(encryptedState.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RatchetSessionsCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('encryptedState: $encryptedState, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MediaItemsTable extends MediaItems
    with TableInfo<$MediaItemsTable, MediaItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mediaIdMeta =
      const VerificationMeta('mediaId');
  @override
  late final GeneratedColumn<String> mediaId = GeneratedColumn<String>(
      'media_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'conversation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _messageIdMeta =
      const VerificationMeta('messageId');
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
      'message_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _mimeTypeMeta =
      const VerificationMeta('mimeType');
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
      'mime_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _localPathMeta =
      const VerificationMeta('localPath');
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
      'local_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _downloadUrlMeta =
      const VerificationMeta('downloadUrl');
  @override
  late final GeneratedColumn<String> downloadUrl = GeneratedColumn<String>(
      'download_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _encryptedKeyJsonMeta =
      const VerificationMeta('encryptedKeyJson');
  @override
  late final GeneratedColumn<String> encryptedKeyJson = GeneratedColumn<String>(
      'encrypted_key_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sizeBytesMeta =
      const VerificationMeta('sizeBytes');
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
      'size_bytes', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _isDownloadedMeta =
      const VerificationMeta('isDownloaded');
  @override
  late final GeneratedColumn<bool> isDownloaded = GeneratedColumn<bool>(
      'is_downloaded', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_downloaded" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        mediaId,
        groupId,
        messageId,
        mimeType,
        localPath,
        downloadUrl,
        encryptedKeyJson,
        sizeBytes,
        isDownloaded
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_items';
  @override
  VerificationContext validateIntegrity(Insertable<MediaItemRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('media_id')) {
      context.handle(_mediaIdMeta,
          mediaId.isAcceptableOrUnknown(data['media_id']!, _mediaIdMeta));
    } else if (isInserting) {
      context.missing(_mediaIdMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
          _groupIdMeta,
          groupId.isAcceptableOrUnknown(
              data['conversation_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(_messageIdMeta,
          messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta));
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(_mimeTypeMeta,
          mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta));
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(_localPathMeta,
          localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta));
    }
    if (data.containsKey('download_url')) {
      context.handle(
          _downloadUrlMeta,
          downloadUrl.isAcceptableOrUnknown(
              data['download_url']!, _downloadUrlMeta));
    } else if (isInserting) {
      context.missing(_downloadUrlMeta);
    }
    if (data.containsKey('encrypted_key_json')) {
      context.handle(
          _encryptedKeyJsonMeta,
          encryptedKeyJson.isAcceptableOrUnknown(
              data['encrypted_key_json']!, _encryptedKeyJsonMeta));
    } else if (isInserting) {
      context.missing(_encryptedKeyJsonMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(_sizeBytesMeta,
          sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta));
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('is_downloaded')) {
      context.handle(
          _isDownloadedMeta,
          isDownloaded.isAcceptableOrUnknown(
              data['is_downloaded']!, _isDownloadedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mediaId};
  @override
  MediaItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaItemRow(
      mediaId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_id'])!,
      groupId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}conversation_id'])!,
      messageId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message_id'])!,
      mimeType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mime_type'])!,
      localPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_path']),
      downloadUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}download_url'])!,
      encryptedKeyJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}encrypted_key_json'])!,
      sizeBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}size_bytes'])!,
      isDownloaded: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_downloaded'])!,
    );
  }

  @override
  $MediaItemsTable createAlias(String alias) {
    return $MediaItemsTable(attachedDatabase, alias);
  }
}

class MediaItemRow extends DataClass implements Insertable<MediaItemRow> {
  /// Media ID (UUID).
  final String mediaId;

  /// Conversation the media belongs to.
  final String groupId;

  /// Message the media is attached to.
  final String messageId;

  /// MIME type (e.g., image/jpeg).
  final String mimeType;

  /// Local file path after download.
  final String? localPath;

  /// Remote download URL.
  final String downloadUrl;

  /// JSON-encoded AES key + IV for decryption.
  final String encryptedKeyJson;

  /// File size in bytes.
  final int sizeBytes;

  /// Whether the file has been downloaded and verified.
  final bool isDownloaded;
  const MediaItemRow(
      {required this.mediaId,
      required this.groupId,
      required this.messageId,
      required this.mimeType,
      this.localPath,
      required this.downloadUrl,
      required this.encryptedKeyJson,
      required this.sizeBytes,
      required this.isDownloaded});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['media_id'] = Variable<String>(mediaId);
    map['conversation_id'] = Variable<String>(groupId);
    map['message_id'] = Variable<String>(messageId);
    map['mime_type'] = Variable<String>(mimeType);
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    map['download_url'] = Variable<String>(downloadUrl);
    map['encrypted_key_json'] = Variable<String>(encryptedKeyJson);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['is_downloaded'] = Variable<bool>(isDownloaded);
    return map;
  }

  MediaItemsCompanion toCompanion(bool nullToAbsent) {
    return MediaItemsCompanion(
      mediaId: Value(mediaId),
      groupId: Value(groupId),
      messageId: Value(messageId),
      mimeType: Value(mimeType),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      downloadUrl: Value(downloadUrl),
      encryptedKeyJson: Value(encryptedKeyJson),
      sizeBytes: Value(sizeBytes),
      isDownloaded: Value(isDownloaded),
    );
  }

  factory MediaItemRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaItemRow(
      mediaId: serializer.fromJson<String>(json['mediaId']),
      groupId: serializer.fromJson<String>(json['groupId']),
      messageId: serializer.fromJson<String>(json['messageId']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      downloadUrl: serializer.fromJson<String>(json['downloadUrl']),
      encryptedKeyJson: serializer.fromJson<String>(json['encryptedKeyJson']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      isDownloaded: serializer.fromJson<bool>(json['isDownloaded']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mediaId': serializer.toJson<String>(mediaId),
      'groupId': serializer.toJson<String>(groupId),
      'messageId': serializer.toJson<String>(messageId),
      'mimeType': serializer.toJson<String>(mimeType),
      'localPath': serializer.toJson<String?>(localPath),
      'downloadUrl': serializer.toJson<String>(downloadUrl),
      'encryptedKeyJson': serializer.toJson<String>(encryptedKeyJson),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'isDownloaded': serializer.toJson<bool>(isDownloaded),
    };
  }

  MediaItemRow copyWith(
          {String? mediaId,
          String? groupId,
          String? messageId,
          String? mimeType,
          Value<String?> localPath = const Value.absent(),
          String? downloadUrl,
          String? encryptedKeyJson,
          int? sizeBytes,
          bool? isDownloaded}) =>
      MediaItemRow(
        mediaId: mediaId ?? this.mediaId,
        groupId: groupId ?? this.groupId,
        messageId: messageId ?? this.messageId,
        mimeType: mimeType ?? this.mimeType,
        localPath: localPath.present ? localPath.value : this.localPath,
        downloadUrl: downloadUrl ?? this.downloadUrl,
        encryptedKeyJson: encryptedKeyJson ?? this.encryptedKeyJson,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        isDownloaded: isDownloaded ?? this.isDownloaded,
      );
  MediaItemRow copyWithCompanion(MediaItemsCompanion data) {
    return MediaItemRow(
      mediaId: data.mediaId.present ? data.mediaId.value : this.mediaId,
      groupId: data.groupId.present
          ? data.groupId.value
          : this.groupId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      downloadUrl:
          data.downloadUrl.present ? data.downloadUrl.value : this.downloadUrl,
      encryptedKeyJson: data.encryptedKeyJson.present
          ? data.encryptedKeyJson.value
          : this.encryptedKeyJson,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      isDownloaded: data.isDownloaded.present
          ? data.isDownloaded.value
          : this.isDownloaded,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaItemRow(')
          ..write('mediaId: $mediaId, ')
          ..write('groupId: $groupId, ')
          ..write('messageId: $messageId, ')
          ..write('mimeType: $mimeType, ')
          ..write('localPath: $localPath, ')
          ..write('downloadUrl: $downloadUrl, ')
          ..write('encryptedKeyJson: $encryptedKeyJson, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('isDownloaded: $isDownloaded')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(mediaId, groupId, messageId, mimeType,
      localPath, downloadUrl, encryptedKeyJson, sizeBytes, isDownloaded);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaItemRow &&
          other.mediaId == this.mediaId &&
          other.groupId == this.groupId &&
          other.messageId == this.messageId &&
          other.mimeType == this.mimeType &&
          other.localPath == this.localPath &&
          other.downloadUrl == this.downloadUrl &&
          other.encryptedKeyJson == this.encryptedKeyJson &&
          other.sizeBytes == this.sizeBytes &&
          other.isDownloaded == this.isDownloaded);
}

class MediaItemsCompanion extends UpdateCompanion<MediaItemRow> {
  final Value<String> mediaId;
  final Value<String> groupId;
  final Value<String> messageId;
  final Value<String> mimeType;
  final Value<String?> localPath;
  final Value<String> downloadUrl;
  final Value<String> encryptedKeyJson;
  final Value<int> sizeBytes;
  final Value<bool> isDownloaded;
  final Value<int> rowid;
  const MediaItemsCompanion({
    this.mediaId = const Value.absent(),
    this.groupId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.localPath = const Value.absent(),
    this.downloadUrl = const Value.absent(),
    this.encryptedKeyJson = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.isDownloaded = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaItemsCompanion.insert({
    required String mediaId,
    required String groupId,
    required String messageId,
    required String mimeType,
    this.localPath = const Value.absent(),
    required String downloadUrl,
    required String encryptedKeyJson,
    required int sizeBytes,
    this.isDownloaded = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : mediaId = Value(mediaId),
        groupId = Value(groupId),
        messageId = Value(messageId),
        mimeType = Value(mimeType),
        downloadUrl = Value(downloadUrl),
        encryptedKeyJson = Value(encryptedKeyJson),
        sizeBytes = Value(sizeBytes);
  static Insertable<MediaItemRow> custom({
    Expression<String>? mediaId,
    Expression<String>? groupId,
    Expression<String>? messageId,
    Expression<String>? mimeType,
    Expression<String>? localPath,
    Expression<String>? downloadUrl,
    Expression<String>? encryptedKeyJson,
    Expression<int>? sizeBytes,
    Expression<bool>? isDownloaded,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mediaId != null) 'media_id': mediaId,
      if (groupId != null) 'conversation_id': groupId,
      if (messageId != null) 'message_id': messageId,
      if (mimeType != null) 'mime_type': mimeType,
      if (localPath != null) 'local_path': localPath,
      if (downloadUrl != null) 'download_url': downloadUrl,
      if (encryptedKeyJson != null) 'encrypted_key_json': encryptedKeyJson,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (isDownloaded != null) 'is_downloaded': isDownloaded,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaItemsCompanion copyWith(
      {Value<String>? mediaId,
      Value<String>? groupId,
      Value<String>? messageId,
      Value<String>? mimeType,
      Value<String?>? localPath,
      Value<String>? downloadUrl,
      Value<String>? encryptedKeyJson,
      Value<int>? sizeBytes,
      Value<bool>? isDownloaded,
      Value<int>? rowid}) {
    return MediaItemsCompanion(
      mediaId: mediaId ?? this.mediaId,
      groupId: groupId ?? this.groupId,
      messageId: messageId ?? this.messageId,
      mimeType: mimeType ?? this.mimeType,
      localPath: localPath ?? this.localPath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      encryptedKeyJson: encryptedKeyJson ?? this.encryptedKeyJson,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mediaId.present) {
      map['media_id'] = Variable<String>(mediaId.value);
    }
    if (groupId.present) {
      map['conversation_id'] = Variable<String>(groupId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (downloadUrl.present) {
      map['download_url'] = Variable<String>(downloadUrl.value);
    }
    if (encryptedKeyJson.present) {
      map['encrypted_key_json'] = Variable<String>(encryptedKeyJson.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (isDownloaded.present) {
      map['is_downloaded'] = Variable<bool>(isDownloaded.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaItemsCompanion(')
          ..write('mediaId: $mediaId, ')
          ..write('groupId: $groupId, ')
          ..write('messageId: $messageId, ')
          ..write('mimeType: $mimeType, ')
          ..write('localPath: $localPath, ')
          ..write('downloadUrl: $downloadUrl, ')
          ..write('encryptedKeyJson: $encryptedKeyJson, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('isDownloaded: $isDownloaded, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UnackedRatchetsTable extends UnackedRatchets
    with TableInfo<$UnackedRatchetsTable, UnackedRatchetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UnackedRatchetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sessionKeyMeta =
      const VerificationMeta('sessionKey');
  @override
  late final GeneratedColumn<String> sessionKey = GeneratedColumn<String>(
      'session_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sessionTypeMeta =
      const VerificationMeta('sessionType');
  @override
  late final GeneratedColumn<String> sessionType = GeneratedColumn<String>(
      'session_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _serializedStateMeta =
      const VerificationMeta('serializedState');
  @override
  late final GeneratedColumn<String> serializedState = GeneratedColumn<String>(
      'serialized_state', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, sessionKey, sessionType, serializedState, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'unacked_ratchets';
  @override
  VerificationContext validateIntegrity(Insertable<UnackedRatchetRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_key')) {
      context.handle(
          _sessionKeyMeta,
          sessionKey.isAcceptableOrUnknown(
              data['session_key']!, _sessionKeyMeta));
    } else if (isInserting) {
      context.missing(_sessionKeyMeta);
    }
    if (data.containsKey('session_type')) {
      context.handle(
          _sessionTypeMeta,
          sessionType.isAcceptableOrUnknown(
              data['session_type']!, _sessionTypeMeta));
    } else if (isInserting) {
      context.missing(_sessionTypeMeta);
    }
    if (data.containsKey('serialized_state')) {
      context.handle(
          _serializedStateMeta,
          serializedState.isAcceptableOrUnknown(
              data['serialized_state']!, _serializedStateMeta));
    } else if (isInserting) {
      context.missing(_serializedStateMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UnackedRatchetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UnackedRatchetRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sessionKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_key'])!,
      sessionType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_type'])!,
      serializedState: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}serialized_state'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $UnackedRatchetsTable createAlias(String alias) {
    return $UnackedRatchetsTable(attachedDatabase, alias);
  }
}

class UnackedRatchetRow extends DataClass
    implements Insertable<UnackedRatchetRow> {
  /// Unique ID for this unacked snapshot.
  final String id;

  /// Session key: "userId:deviceId".
  final String sessionKey;

  /// Session type: "doubleRatchet" or "senderKey".
  final String sessionType;

  /// JSON-serialised ratchet state snapshot.
  final String serializedState;

  /// When this snapshot was created.
  final DateTime createdAt;
  const UnackedRatchetRow(
      {required this.id,
      required this.sessionKey,
      required this.sessionType,
      required this.serializedState,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_key'] = Variable<String>(sessionKey);
    map['session_type'] = Variable<String>(sessionType);
    map['serialized_state'] = Variable<String>(serializedState);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  UnackedRatchetsCompanion toCompanion(bool nullToAbsent) {
    return UnackedRatchetsCompanion(
      id: Value(id),
      sessionKey: Value(sessionKey),
      sessionType: Value(sessionType),
      serializedState: Value(serializedState),
      createdAt: Value(createdAt),
    );
  }

  factory UnackedRatchetRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UnackedRatchetRow(
      id: serializer.fromJson<String>(json['id']),
      sessionKey: serializer.fromJson<String>(json['sessionKey']),
      sessionType: serializer.fromJson<String>(json['sessionType']),
      serializedState: serializer.fromJson<String>(json['serializedState']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionKey': serializer.toJson<String>(sessionKey),
      'sessionType': serializer.toJson<String>(sessionType),
      'serializedState': serializer.toJson<String>(serializedState),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  UnackedRatchetRow copyWith(
          {String? id,
          String? sessionKey,
          String? sessionType,
          String? serializedState,
          DateTime? createdAt}) =>
      UnackedRatchetRow(
        id: id ?? this.id,
        sessionKey: sessionKey ?? this.sessionKey,
        sessionType: sessionType ?? this.sessionType,
        serializedState: serializedState ?? this.serializedState,
        createdAt: createdAt ?? this.createdAt,
      );
  UnackedRatchetRow copyWithCompanion(UnackedRatchetsCompanion data) {
    return UnackedRatchetRow(
      id: data.id.present ? data.id.value : this.id,
      sessionKey:
          data.sessionKey.present ? data.sessionKey.value : this.sessionKey,
      sessionType:
          data.sessionType.present ? data.sessionType.value : this.sessionType,
      serializedState: data.serializedState.present
          ? data.serializedState.value
          : this.serializedState,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UnackedRatchetRow(')
          ..write('id: $id, ')
          ..write('sessionKey: $sessionKey, ')
          ..write('sessionType: $sessionType, ')
          ..write('serializedState: $serializedState, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sessionKey, sessionType, serializedState, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UnackedRatchetRow &&
          other.id == this.id &&
          other.sessionKey == this.sessionKey &&
          other.sessionType == this.sessionType &&
          other.serializedState == this.serializedState &&
          other.createdAt == this.createdAt);
}

class UnackedRatchetsCompanion extends UpdateCompanion<UnackedRatchetRow> {
  final Value<String> id;
  final Value<String> sessionKey;
  final Value<String> sessionType;
  final Value<String> serializedState;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const UnackedRatchetsCompanion({
    this.id = const Value.absent(),
    this.sessionKey = const Value.absent(),
    this.sessionType = const Value.absent(),
    this.serializedState = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UnackedRatchetsCompanion.insert({
    required String id,
    required String sessionKey,
    required String sessionType,
    required String serializedState,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        sessionKey = Value(sessionKey),
        sessionType = Value(sessionType),
        serializedState = Value(serializedState),
        createdAt = Value(createdAt);
  static Insertable<UnackedRatchetRow> custom({
    Expression<String>? id,
    Expression<String>? sessionKey,
    Expression<String>? sessionType,
    Expression<String>? serializedState,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionKey != null) 'session_key': sessionKey,
      if (sessionType != null) 'session_type': sessionType,
      if (serializedState != null) 'serialized_state': serializedState,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UnackedRatchetsCompanion copyWith(
      {Value<String>? id,
      Value<String>? sessionKey,
      Value<String>? sessionType,
      Value<String>? serializedState,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return UnackedRatchetsCompanion(
      id: id ?? this.id,
      sessionKey: sessionKey ?? this.sessionKey,
      sessionType: sessionType ?? this.sessionType,
      serializedState: serializedState ?? this.serializedState,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionKey.present) {
      map['session_key'] = Variable<String>(sessionKey.value);
    }
    if (sessionType.present) {
      map['session_type'] = Variable<String>(sessionType.value);
    }
    if (serializedState.present) {
      map['serialized_state'] = Variable<String>(serializedState.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UnackedRatchetsCompanion(')
          ..write('id: $id, ')
          ..write('sessionKey: $sessionKey, ')
          ..write('sessionType: $sessionType, ')
          ..write('serializedState: $serializedState, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DecryptedMessagesTable extends DecryptedMessages
    with TableInfo<$DecryptedMessagesTable, DecryptedMessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DecryptedMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIdMeta =
      const VerificationMeta('messageId');
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
      'message_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _plaintextMeta =
      const VerificationMeta('plaintext');
  @override
  late final GeneratedColumn<String> plaintext = GeneratedColumn<String>(
      'plaintext', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _mediaJsonMeta =
      const VerificationMeta('mediaJson');
  @override
  late final GeneratedColumn<String> mediaJson = GeneratedColumn<String>(
      'media_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cachedAtMeta =
      const VerificationMeta('cachedAt');
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
      'cached_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [messageId, plaintext, mediaJson, cachedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'decrypted_messages';
  @override
  VerificationContext validateIntegrity(
      Insertable<DecryptedMessageRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_id')) {
      context.handle(_messageIdMeta,
          messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta));
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('plaintext')) {
      context.handle(_plaintextMeta,
          plaintext.isAcceptableOrUnknown(data['plaintext']!, _plaintextMeta));
    } else if (isInserting) {
      context.missing(_plaintextMeta);
    }
    if (data.containsKey('media_json')) {
      context.handle(_mediaJsonMeta,
          mediaJson.isAcceptableOrUnknown(data['media_json']!, _mediaJsonMeta));
    }
    if (data.containsKey('cached_at')) {
      context.handle(_cachedAtMeta,
          cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta));
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId};
  @override
  DecryptedMessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DecryptedMessageRow(
      messageId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message_id'])!,
      plaintext: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plaintext'])!,
      mediaJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_json']),
      cachedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}cached_at'])!,
    );
  }

  @override
  $DecryptedMessagesTable createAlias(String alias) {
    return $DecryptedMessagesTable(attachedDatabase, alias);
  }
}

class DecryptedMessageRow extends DataClass
    implements Insertable<DecryptedMessageRow> {
  /// References [Messages.id].
  final String messageId;

  /// Decrypted plaintext.
  final String plaintext;

  /// JSON-encoded media metadata, if the message has media.
  final String? mediaJson;

  /// When this cache entry was stored.
  final DateTime cachedAt;
  const DecryptedMessageRow(
      {required this.messageId,
      required this.plaintext,
      this.mediaJson,
      required this.cachedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    map['plaintext'] = Variable<String>(plaintext);
    if (!nullToAbsent || mediaJson != null) {
      map['media_json'] = Variable<String>(mediaJson);
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  DecryptedMessagesCompanion toCompanion(bool nullToAbsent) {
    return DecryptedMessagesCompanion(
      messageId: Value(messageId),
      plaintext: Value(plaintext),
      mediaJson: mediaJson == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaJson),
      cachedAt: Value(cachedAt),
    );
  }

  factory DecryptedMessageRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DecryptedMessageRow(
      messageId: serializer.fromJson<String>(json['messageId']),
      plaintext: serializer.fromJson<String>(json['plaintext']),
      mediaJson: serializer.fromJson<String?>(json['mediaJson']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'messageId': serializer.toJson<String>(messageId),
      'plaintext': serializer.toJson<String>(plaintext),
      'mediaJson': serializer.toJson<String?>(mediaJson),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  DecryptedMessageRow copyWith(
          {String? messageId,
          String? plaintext,
          Value<String?> mediaJson = const Value.absent(),
          DateTime? cachedAt}) =>
      DecryptedMessageRow(
        messageId: messageId ?? this.messageId,
        plaintext: plaintext ?? this.plaintext,
        mediaJson: mediaJson.present ? mediaJson.value : this.mediaJson,
        cachedAt: cachedAt ?? this.cachedAt,
      );
  DecryptedMessageRow copyWithCompanion(DecryptedMessagesCompanion data) {
    return DecryptedMessageRow(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      plaintext: data.plaintext.present ? data.plaintext.value : this.plaintext,
      mediaJson: data.mediaJson.present ? data.mediaJson.value : this.mediaJson,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DecryptedMessageRow(')
          ..write('messageId: $messageId, ')
          ..write('plaintext: $plaintext, ')
          ..write('mediaJson: $mediaJson, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(messageId, plaintext, mediaJson, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DecryptedMessageRow &&
          other.messageId == this.messageId &&
          other.plaintext == this.plaintext &&
          other.mediaJson == this.mediaJson &&
          other.cachedAt == this.cachedAt);
}

class DecryptedMessagesCompanion extends UpdateCompanion<DecryptedMessageRow> {
  final Value<String> messageId;
  final Value<String> plaintext;
  final Value<String?> mediaJson;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const DecryptedMessagesCompanion({
    this.messageId = const Value.absent(),
    this.plaintext = const Value.absent(),
    this.mediaJson = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DecryptedMessagesCompanion.insert({
    required String messageId,
    required String plaintext,
    this.mediaJson = const Value.absent(),
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  })  : messageId = Value(messageId),
        plaintext = Value(plaintext),
        cachedAt = Value(cachedAt);
  static Insertable<DecryptedMessageRow> custom({
    Expression<String>? messageId,
    Expression<String>? plaintext,
    Expression<String>? mediaJson,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (plaintext != null) 'plaintext': plaintext,
      if (mediaJson != null) 'media_json': mediaJson,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DecryptedMessagesCompanion copyWith(
      {Value<String>? messageId,
      Value<String>? plaintext,
      Value<String?>? mediaJson,
      Value<DateTime>? cachedAt,
      Value<int>? rowid}) {
    return DecryptedMessagesCompanion(
      messageId: messageId ?? this.messageId,
      plaintext: plaintext ?? this.plaintext,
      mediaJson: mediaJson ?? this.mediaJson,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (plaintext.present) {
      map['plaintext'] = Variable<String>(plaintext.value);
    }
    if (mediaJson.present) {
      map['media_json'] = Variable<String>(mediaJson.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DecryptedMessagesCompanion(')
          ..write('messageId: $messageId, ')
          ..write('plaintext: $plaintext, ')
          ..write('mediaJson: $mediaJson, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProcessedDistributionsTable extends ProcessedDistributions
    with TableInfo<$ProcessedDistributionsTable, ProcessedDistributionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProcessedDistributionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIdMeta =
      const VerificationMeta('messageId');
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
      'message_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _processedAtMeta =
      const VerificationMeta('processedAt');
  @override
  late final GeneratedColumn<DateTime> processedAt = GeneratedColumn<DateTime>(
      'processed_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [messageId, processedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'processed_distributions';
  @override
  VerificationContext validateIntegrity(
      Insertable<ProcessedDistributionRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_id')) {
      context.handle(_messageIdMeta,
          messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta));
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('processed_at')) {
      context.handle(
          _processedAtMeta,
          processedAt.isAcceptableOrUnknown(
              data['processed_at']!, _processedAtMeta));
    } else if (isInserting) {
      context.missing(_processedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId};
  @override
  ProcessedDistributionRow map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProcessedDistributionRow(
      messageId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message_id'])!,
      processedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}processed_at'])!,
    );
  }

  @override
  $ProcessedDistributionsTable createAlias(String alias) {
    return $ProcessedDistributionsTable(attachedDatabase, alias);
  }
}

class ProcessedDistributionRow extends DataClass
    implements Insertable<ProcessedDistributionRow> {
  /// The distribution message ID.
  final String messageId;

  /// When it was processed.
  final DateTime processedAt;
  const ProcessedDistributionRow(
      {required this.messageId, required this.processedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    map['processed_at'] = Variable<DateTime>(processedAt);
    return map;
  }

  ProcessedDistributionsCompanion toCompanion(bool nullToAbsent) {
    return ProcessedDistributionsCompanion(
      messageId: Value(messageId),
      processedAt: Value(processedAt),
    );
  }

  factory ProcessedDistributionRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProcessedDistributionRow(
      messageId: serializer.fromJson<String>(json['messageId']),
      processedAt: serializer.fromJson<DateTime>(json['processedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'messageId': serializer.toJson<String>(messageId),
      'processedAt': serializer.toJson<DateTime>(processedAt),
    };
  }

  ProcessedDistributionRow copyWith(
          {String? messageId, DateTime? processedAt}) =>
      ProcessedDistributionRow(
        messageId: messageId ?? this.messageId,
        processedAt: processedAt ?? this.processedAt,
      );
  ProcessedDistributionRow copyWithCompanion(
      ProcessedDistributionsCompanion data) {
    return ProcessedDistributionRow(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      processedAt:
          data.processedAt.present ? data.processedAt.value : this.processedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProcessedDistributionRow(')
          ..write('messageId: $messageId, ')
          ..write('processedAt: $processedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(messageId, processedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProcessedDistributionRow &&
          other.messageId == this.messageId &&
          other.processedAt == this.processedAt);
}

class ProcessedDistributionsCompanion
    extends UpdateCompanion<ProcessedDistributionRow> {
  final Value<String> messageId;
  final Value<DateTime> processedAt;
  final Value<int> rowid;
  const ProcessedDistributionsCompanion({
    this.messageId = const Value.absent(),
    this.processedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProcessedDistributionsCompanion.insert({
    required String messageId,
    required DateTime processedAt,
    this.rowid = const Value.absent(),
  })  : messageId = Value(messageId),
        processedAt = Value(processedAt);
  static Insertable<ProcessedDistributionRow> custom({
    Expression<String>? messageId,
    Expression<DateTime>? processedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (processedAt != null) 'processed_at': processedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProcessedDistributionsCompanion copyWith(
      {Value<String>? messageId,
      Value<DateTime>? processedAt,
      Value<int>? rowid}) {
    return ProcessedDistributionsCompanion(
      messageId: messageId ?? this.messageId,
      processedAt: processedAt ?? this.processedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (processedAt.present) {
      map['processed_at'] = Variable<DateTime>(processedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProcessedDistributionsCompanion(')
          ..write('messageId: $messageId, ')
          ..write('processedAt: $processedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $MessageCiphertextsTable messageCiphertexts =
      $MessageCiphertextsTable(this);
  late final $ConversationsTable conversations = $ConversationsTable(this);
  late final $ReceiptsTable receipts = $ReceiptsTable(this);
  late final $OutboxItemsTable outboxItems = $OutboxItemsTable(this);
  late final $RatchetSessionsTable ratchetSessions =
      $RatchetSessionsTable(this);
  late final $MediaItemsTable mediaItems = $MediaItemsTable(this);
  late final $UnackedRatchetsTable unackedRatchets =
      $UnackedRatchetsTable(this);
  late final $DecryptedMessagesTable decryptedMessages =
      $DecryptedMessagesTable(this);
  late final $ProcessedDistributionsTable processedDistributions =
      $ProcessedDistributionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        messages,
        messageCiphertexts,
        conversations,
        receipts,
        outboxItems,
        ratchetSessions,
        mediaItems,
        unackedRatchets,
        decryptedMessages,
        processedDistributions
      ];
}

typedef $$MessagesTableCreateCompanionBuilder = MessagesCompanion Function({
  required String id,
  required String groupId,
  required String senderId,
  Value<String?> senderDeviceId,
  Value<String> messageType,
  Value<String> role,
  Value<int?> serverSeq,
  Value<String> status,
  Value<String?> replyToMessageId,
  Value<String?> reactionsJson,
  Value<bool> isStarred,
  Value<bool> isViewOnce,
  Value<int?> disappearsAt,
  Value<bool> isDeleted,
  Value<String?> serverContent,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$MessagesTableUpdateCompanionBuilder = MessagesCompanion Function({
  Value<String> id,
  Value<String> groupId,
  Value<String> senderId,
  Value<String?> senderDeviceId,
  Value<String> messageType,
  Value<String> role,
  Value<int?> serverSeq,
  Value<String> status,
  Value<String?> replyToMessageId,
  Value<String?> reactionsJson,
  Value<bool> isStarred,
  Value<bool> isViewOnce,
  Value<int?> disappearsAt,
  Value<bool> isDeleted,
  Value<String?> serverContent,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$MessagesTableReferences
    extends BaseReferences<_$AppDatabase, $MessagesTable, MessageRow> {
  $$MessagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MessageCiphertextsTable,
      List<MessageCiphertextRow>> _messageCiphertextsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.messageCiphertexts,
          aliasName: $_aliasNameGenerator(
              db.messages.id, db.messageCiphertexts.messageId));

  $$MessageCiphertextsTableProcessedTableManager get messageCiphertextsRefs {
    final manager = $$MessageCiphertextsTableTableManager(
            $_db, $_db.messageCiphertexts)
        .filter((f) => f.messageId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_messageCiphertextsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$MessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senderId => $composableBuilder(
      column: $table.senderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senderDeviceId => $composableBuilder(
      column: $table.senderDeviceId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get messageType => $composableBuilder(
      column: $table.messageType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get serverSeq => $composableBuilder(
      column: $table.serverSeq, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get replyToMessageId => $composableBuilder(
      column: $table.replyToMessageId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reactionsJson => $composableBuilder(
      column: $table.reactionsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isStarred => $composableBuilder(
      column: $table.isStarred, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isViewOnce => $composableBuilder(
      column: $table.isViewOnce, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get disappearsAt => $composableBuilder(
      column: $table.disappearsAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverContent => $composableBuilder(
      column: $table.serverContent, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  Expression<bool> messageCiphertextsRefs(
      Expression<bool> Function($$MessageCiphertextsTableFilterComposer f) f) {
    final $$MessageCiphertextsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.messageCiphertexts,
        getReferencedColumn: (t) => t.messageId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MessageCiphertextsTableFilterComposer(
              $db: $db,
              $table: $db.messageCiphertexts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$MessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senderId => $composableBuilder(
      column: $table.senderId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senderDeviceId => $composableBuilder(
      column: $table.senderDeviceId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get messageType => $composableBuilder(
      column: $table.messageType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get serverSeq => $composableBuilder(
      column: $table.serverSeq, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get replyToMessageId => $composableBuilder(
      column: $table.replyToMessageId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reactionsJson => $composableBuilder(
      column: $table.reactionsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isStarred => $composableBuilder(
      column: $table.isStarred, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isViewOnce => $composableBuilder(
      column: $table.isViewOnce, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get disappearsAt => $composableBuilder(
      column: $table.disappearsAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverContent => $composableBuilder(
      column: $table.serverContent,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<String> get senderDeviceId => $composableBuilder(
      column: $table.senderDeviceId, builder: (column) => column);

  GeneratedColumn<String> get messageType => $composableBuilder(
      column: $table.messageType, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<int> get serverSeq =>
      $composableBuilder(column: $table.serverSeq, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get replyToMessageId => $composableBuilder(
      column: $table.replyToMessageId, builder: (column) => column);

  GeneratedColumn<String> get reactionsJson => $composableBuilder(
      column: $table.reactionsJson, builder: (column) => column);

  GeneratedColumn<bool> get isStarred =>
      $composableBuilder(column: $table.isStarred, builder: (column) => column);

  GeneratedColumn<bool> get isViewOnce => $composableBuilder(
      column: $table.isViewOnce, builder: (column) => column);

  GeneratedColumn<int> get disappearsAt => $composableBuilder(
      column: $table.disappearsAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get serverContent => $composableBuilder(
      column: $table.serverContent, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> messageCiphertextsRefs<T extends Object>(
      Expression<T> Function($$MessageCiphertextsTableAnnotationComposer a) f) {
    final $$MessageCiphertextsTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.messageCiphertexts,
            getReferencedColumn: (t) => t.messageId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$MessageCiphertextsTableAnnotationComposer(
                  $db: $db,
                  $table: $db.messageCiphertexts,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$MessagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MessagesTable,
    MessageRow,
    $$MessagesTableFilterComposer,
    $$MessagesTableOrderingComposer,
    $$MessagesTableAnnotationComposer,
    $$MessagesTableCreateCompanionBuilder,
    $$MessagesTableUpdateCompanionBuilder,
    (MessageRow, $$MessagesTableReferences),
    MessageRow,
    PrefetchHooks Function({bool messageCiphertextsRefs})> {
  $$MessagesTableTableManager(_$AppDatabase db, $MessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> groupId = const Value.absent(),
            Value<String> senderId = const Value.absent(),
            Value<String?> senderDeviceId = const Value.absent(),
            Value<String> messageType = const Value.absent(),
            Value<String> role = const Value.absent(),
            Value<int?> serverSeq = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> replyToMessageId = const Value.absent(),
            Value<String?> reactionsJson = const Value.absent(),
            Value<bool> isStarred = const Value.absent(),
            Value<bool> isViewOnce = const Value.absent(),
            Value<int?> disappearsAt = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<String?> serverContent = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MessagesCompanion(
            id: id,
            groupId: groupId,
            senderId: senderId,
            senderDeviceId: senderDeviceId,
            messageType: messageType,
            role: role,
            serverSeq: serverSeq,
            status: status,
            replyToMessageId: replyToMessageId,
            reactionsJson: reactionsJson,
            isStarred: isStarred,
            isViewOnce: isViewOnce,
            disappearsAt: disappearsAt,
            isDeleted: isDeleted,
            serverContent: serverContent,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String groupId,
            required String senderId,
            Value<String?> senderDeviceId = const Value.absent(),
            Value<String> messageType = const Value.absent(),
            Value<String> role = const Value.absent(),
            Value<int?> serverSeq = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> replyToMessageId = const Value.absent(),
            Value<String?> reactionsJson = const Value.absent(),
            Value<bool> isStarred = const Value.absent(),
            Value<bool> isViewOnce = const Value.absent(),
            Value<int?> disappearsAt = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<String?> serverContent = const Value.absent(),
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              MessagesCompanion.insert(
            id: id,
            groupId: groupId,
            senderId: senderId,
            senderDeviceId: senderDeviceId,
            messageType: messageType,
            role: role,
            serverSeq: serverSeq,
            status: status,
            replyToMessageId: replyToMessageId,
            reactionsJson: reactionsJson,
            isStarred: isStarred,
            isViewOnce: isViewOnce,
            disappearsAt: disappearsAt,
            isDeleted: isDeleted,
            serverContent: serverContent,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$MessagesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({messageCiphertextsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (messageCiphertextsRefs) db.messageCiphertexts
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (messageCiphertextsRefs)
                    await $_getPrefetchedData<MessageRow, $MessagesTable,
                            MessageCiphertextRow>(
                        currentTable: table,
                        referencedTable: $$MessagesTableReferences
                            ._messageCiphertextsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$MessagesTableReferences(db, table, p0)
                                .messageCiphertextsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.messageId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$MessagesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MessagesTable,
    MessageRow,
    $$MessagesTableFilterComposer,
    $$MessagesTableOrderingComposer,
    $$MessagesTableAnnotationComposer,
    $$MessagesTableCreateCompanionBuilder,
    $$MessagesTableUpdateCompanionBuilder,
    (MessageRow, $$MessagesTableReferences),
    MessageRow,
    PrefetchHooks Function({bool messageCiphertextsRefs})>;
typedef $$MessageCiphertextsTableCreateCompanionBuilder
    = MessageCiphertextsCompanion Function({
  required String id,
  required String messageId,
  required String recipientId,
  required int recipientDeviceId,
  required String ciphertext,
  Value<String?> ratchetHeader,
  Value<int> rowid,
});
typedef $$MessageCiphertextsTableUpdateCompanionBuilder
    = MessageCiphertextsCompanion Function({
  Value<String> id,
  Value<String> messageId,
  Value<String> recipientId,
  Value<int> recipientDeviceId,
  Value<String> ciphertext,
  Value<String?> ratchetHeader,
  Value<int> rowid,
});

final class $$MessageCiphertextsTableReferences extends BaseReferences<
    _$AppDatabase, $MessageCiphertextsTable, MessageCiphertextRow> {
  $$MessageCiphertextsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $MessagesTable _messageIdTable(_$AppDatabase db) =>
      db.messages.createAlias($_aliasNameGenerator(
          db.messageCiphertexts.messageId, db.messages.id));

  $$MessagesTableProcessedTableManager get messageId {
    final $_column = $_itemColumn<String>('message_id')!;

    final manager = $$MessagesTableTableManager($_db, $_db.messages)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_messageIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$MessageCiphertextsTableFilterComposer
    extends Composer<_$AppDatabase, $MessageCiphertextsTable> {
  $$MessageCiphertextsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recipientId => $composableBuilder(
      column: $table.recipientId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get recipientDeviceId => $composableBuilder(
      column: $table.recipientDeviceId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ciphertext => $composableBuilder(
      column: $table.ciphertext, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ratchetHeader => $composableBuilder(
      column: $table.ratchetHeader, builder: (column) => ColumnFilters(column));

  $$MessagesTableFilterComposer get messageId {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.messageId,
        referencedTable: $db.messages,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MessagesTableFilterComposer(
              $db: $db,
              $table: $db.messages,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MessageCiphertextsTableOrderingComposer
    extends Composer<_$AppDatabase, $MessageCiphertextsTable> {
  $$MessageCiphertextsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recipientId => $composableBuilder(
      column: $table.recipientId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get recipientDeviceId => $composableBuilder(
      column: $table.recipientDeviceId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ciphertext => $composableBuilder(
      column: $table.ciphertext, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ratchetHeader => $composableBuilder(
      column: $table.ratchetHeader,
      builder: (column) => ColumnOrderings(column));

  $$MessagesTableOrderingComposer get messageId {
    final $$MessagesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.messageId,
        referencedTable: $db.messages,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MessagesTableOrderingComposer(
              $db: $db,
              $table: $db.messages,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MessageCiphertextsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessageCiphertextsTable> {
  $$MessageCiphertextsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get recipientId => $composableBuilder(
      column: $table.recipientId, builder: (column) => column);

  GeneratedColumn<int> get recipientDeviceId => $composableBuilder(
      column: $table.recipientDeviceId, builder: (column) => column);

  GeneratedColumn<String> get ciphertext => $composableBuilder(
      column: $table.ciphertext, builder: (column) => column);

  GeneratedColumn<String> get ratchetHeader => $composableBuilder(
      column: $table.ratchetHeader, builder: (column) => column);

  $$MessagesTableAnnotationComposer get messageId {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.messageId,
        referencedTable: $db.messages,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MessagesTableAnnotationComposer(
              $db: $db,
              $table: $db.messages,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MessageCiphertextsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MessageCiphertextsTable,
    MessageCiphertextRow,
    $$MessageCiphertextsTableFilterComposer,
    $$MessageCiphertextsTableOrderingComposer,
    $$MessageCiphertextsTableAnnotationComposer,
    $$MessageCiphertextsTableCreateCompanionBuilder,
    $$MessageCiphertextsTableUpdateCompanionBuilder,
    (MessageCiphertextRow, $$MessageCiphertextsTableReferences),
    MessageCiphertextRow,
    PrefetchHooks Function({bool messageId})> {
  $$MessageCiphertextsTableTableManager(
      _$AppDatabase db, $MessageCiphertextsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessageCiphertextsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessageCiphertextsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessageCiphertextsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> messageId = const Value.absent(),
            Value<String> recipientId = const Value.absent(),
            Value<int> recipientDeviceId = const Value.absent(),
            Value<String> ciphertext = const Value.absent(),
            Value<String?> ratchetHeader = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MessageCiphertextsCompanion(
            id: id,
            messageId: messageId,
            recipientId: recipientId,
            recipientDeviceId: recipientDeviceId,
            ciphertext: ciphertext,
            ratchetHeader: ratchetHeader,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String messageId,
            required String recipientId,
            required int recipientDeviceId,
            required String ciphertext,
            Value<String?> ratchetHeader = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MessageCiphertextsCompanion.insert(
            id: id,
            messageId: messageId,
            recipientId: recipientId,
            recipientDeviceId: recipientDeviceId,
            ciphertext: ciphertext,
            ratchetHeader: ratchetHeader,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$MessageCiphertextsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({messageId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (messageId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.messageId,
                    referencedTable:
                        $$MessageCiphertextsTableReferences._messageIdTable(db),
                    referencedColumn: $$MessageCiphertextsTableReferences
                        ._messageIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$MessageCiphertextsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MessageCiphertextsTable,
    MessageCiphertextRow,
    $$MessageCiphertextsTableFilterComposer,
    $$MessageCiphertextsTableOrderingComposer,
    $$MessageCiphertextsTableAnnotationComposer,
    $$MessageCiphertextsTableCreateCompanionBuilder,
    $$MessageCiphertextsTableUpdateCompanionBuilder,
    (MessageCiphertextRow, $$MessageCiphertextsTableReferences),
    MessageCiphertextRow,
    PrefetchHooks Function({bool messageId})>;
typedef $$ConversationsTableCreateCompanionBuilder = ConversationsCompanion
    Function({
  required String id,
  required String type,
  required String participantIdsJson,
  Value<String?> lastMessageId,
  Value<String?> lastMessageText,
  Value<DateTime?> lastMessageTimestamp,
  Value<int> unreadCount,
  Value<bool> isPinned,
  Value<bool> isArchived,
  Value<bool> isMuted,
  Value<DateTime?> muteUntil,
  Value<int?> disappearingMessageTimerMs,
  Value<bool> isEncrypted,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ConversationsTableUpdateCompanionBuilder = ConversationsCompanion
    Function({
  Value<String> id,
  Value<String> type,
  Value<String> participantIdsJson,
  Value<String?> lastMessageId,
  Value<String?> lastMessageText,
  Value<DateTime?> lastMessageTimestamp,
  Value<int> unreadCount,
  Value<bool> isPinned,
  Value<bool> isArchived,
  Value<bool> isMuted,
  Value<DateTime?> muteUntil,
  Value<int?> disappearingMessageTimerMs,
  Value<bool> isEncrypted,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$ConversationsTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get participantIdsJson => $composableBuilder(
      column: $table.participantIdsJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastMessageId => $composableBuilder(
      column: $table.lastMessageId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastMessageText => $composableBuilder(
      column: $table.lastMessageText,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastMessageTimestamp => $composableBuilder(
      column: $table.lastMessageTimestamp,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get unreadCount => $composableBuilder(
      column: $table.unreadCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isPinned => $composableBuilder(
      column: $table.isPinned, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isMuted => $composableBuilder(
      column: $table.isMuted, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get muteUntil => $composableBuilder(
      column: $table.muteUntil, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get disappearingMessageTimerMs => $composableBuilder(
      column: $table.disappearingMessageTimerMs,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isEncrypted => $composableBuilder(
      column: $table.isEncrypted, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$ConversationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get participantIdsJson => $composableBuilder(
      column: $table.participantIdsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastMessageId => $composableBuilder(
      column: $table.lastMessageId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastMessageText => $composableBuilder(
      column: $table.lastMessageText,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastMessageTimestamp => $composableBuilder(
      column: $table.lastMessageTimestamp,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get unreadCount => $composableBuilder(
      column: $table.unreadCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPinned => $composableBuilder(
      column: $table.isPinned, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isMuted => $composableBuilder(
      column: $table.isMuted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get muteUntil => $composableBuilder(
      column: $table.muteUntil, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get disappearingMessageTimerMs => $composableBuilder(
      column: $table.disappearingMessageTimerMs,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isEncrypted => $composableBuilder(
      column: $table.isEncrypted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ConversationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get participantIdsJson => $composableBuilder(
      column: $table.participantIdsJson, builder: (column) => column);

  GeneratedColumn<String> get lastMessageId => $composableBuilder(
      column: $table.lastMessageId, builder: (column) => column);

  GeneratedColumn<String> get lastMessageText => $composableBuilder(
      column: $table.lastMessageText, builder: (column) => column);

  GeneratedColumn<DateTime> get lastMessageTimestamp => $composableBuilder(
      column: $table.lastMessageTimestamp, builder: (column) => column);

  GeneratedColumn<int> get unreadCount => $composableBuilder(
      column: $table.unreadCount, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => column);

  GeneratedColumn<bool> get isMuted =>
      $composableBuilder(column: $table.isMuted, builder: (column) => column);

  GeneratedColumn<DateTime> get muteUntil =>
      $composableBuilder(column: $table.muteUntil, builder: (column) => column);

  GeneratedColumn<int> get disappearingMessageTimerMs => $composableBuilder(
      column: $table.disappearingMessageTimerMs, builder: (column) => column);

  GeneratedColumn<bool> get isEncrypted => $composableBuilder(
      column: $table.isEncrypted, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ConversationsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ConversationsTable,
    ConversationRow,
    $$ConversationsTableFilterComposer,
    $$ConversationsTableOrderingComposer,
    $$ConversationsTableAnnotationComposer,
    $$ConversationsTableCreateCompanionBuilder,
    $$ConversationsTableUpdateCompanionBuilder,
    (
      ConversationRow,
      BaseReferences<_$AppDatabase, $ConversationsTable, ConversationRow>
    ),
    ConversationRow,
    PrefetchHooks Function()> {
  $$ConversationsTableTableManager(_$AppDatabase db, $ConversationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> participantIdsJson = const Value.absent(),
            Value<String?> lastMessageId = const Value.absent(),
            Value<String?> lastMessageText = const Value.absent(),
            Value<DateTime?> lastMessageTimestamp = const Value.absent(),
            Value<int> unreadCount = const Value.absent(),
            Value<bool> isPinned = const Value.absent(),
            Value<bool> isArchived = const Value.absent(),
            Value<bool> isMuted = const Value.absent(),
            Value<DateTime?> muteUntil = const Value.absent(),
            Value<int?> disappearingMessageTimerMs = const Value.absent(),
            Value<bool> isEncrypted = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConversationsCompanion(
            id: id,
            type: type,
            participantIdsJson: participantIdsJson,
            lastMessageId: lastMessageId,
            lastMessageText: lastMessageText,
            lastMessageTimestamp: lastMessageTimestamp,
            unreadCount: unreadCount,
            isPinned: isPinned,
            isArchived: isArchived,
            isMuted: isMuted,
            muteUntil: muteUntil,
            disappearingMessageTimerMs: disappearingMessageTimerMs,
            isEncrypted: isEncrypted,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String type,
            required String participantIdsJson,
            Value<String?> lastMessageId = const Value.absent(),
            Value<String?> lastMessageText = const Value.absent(),
            Value<DateTime?> lastMessageTimestamp = const Value.absent(),
            Value<int> unreadCount = const Value.absent(),
            Value<bool> isPinned = const Value.absent(),
            Value<bool> isArchived = const Value.absent(),
            Value<bool> isMuted = const Value.absent(),
            Value<DateTime?> muteUntil = const Value.absent(),
            Value<int?> disappearingMessageTimerMs = const Value.absent(),
            Value<bool> isEncrypted = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ConversationsCompanion.insert(
            id: id,
            type: type,
            participantIdsJson: participantIdsJson,
            lastMessageId: lastMessageId,
            lastMessageText: lastMessageText,
            lastMessageTimestamp: lastMessageTimestamp,
            unreadCount: unreadCount,
            isPinned: isPinned,
            isArchived: isArchived,
            isMuted: isMuted,
            muteUntil: muteUntil,
            disappearingMessageTimerMs: disappearingMessageTimerMs,
            isEncrypted: isEncrypted,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ConversationsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ConversationsTable,
    ConversationRow,
    $$ConversationsTableFilterComposer,
    $$ConversationsTableOrderingComposer,
    $$ConversationsTableAnnotationComposer,
    $$ConversationsTableCreateCompanionBuilder,
    $$ConversationsTableUpdateCompanionBuilder,
    (
      ConversationRow,
      BaseReferences<_$AppDatabase, $ConversationsTable, ConversationRow>
    ),
    ConversationRow,
    PrefetchHooks Function()>;
typedef $$ReceiptsTableCreateCompanionBuilder = ReceiptsCompanion Function({
  required String messageId,
  required String userId,
  required String deviceId,
  Value<DateTime?> deliveredAt,
  Value<DateTime?> readAt,
  Value<int> rowid,
});
typedef $$ReceiptsTableUpdateCompanionBuilder = ReceiptsCompanion Function({
  Value<String> messageId,
  Value<String> userId,
  Value<String> deviceId,
  Value<DateTime?> deliveredAt,
  Value<DateTime?> readAt,
  Value<int> rowid,
});

class $$ReceiptsTableFilterComposer
    extends Composer<_$AppDatabase, $ReceiptsTable> {
  $$ReceiptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get messageId => $composableBuilder(
      column: $table.messageId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deliveredAt => $composableBuilder(
      column: $table.deliveredAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get readAt => $composableBuilder(
      column: $table.readAt, builder: (column) => ColumnFilters(column));
}

class $$ReceiptsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReceiptsTable> {
  $$ReceiptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get messageId => $composableBuilder(
      column: $table.messageId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deliveredAt => $composableBuilder(
      column: $table.deliveredAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get readAt => $composableBuilder(
      column: $table.readAt, builder: (column) => ColumnOrderings(column));
}

class $$ReceiptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReceiptsTable> {
  $$ReceiptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<DateTime> get deliveredAt => $composableBuilder(
      column: $table.deliveredAt, builder: (column) => column);

  GeneratedColumn<DateTime> get readAt =>
      $composableBuilder(column: $table.readAt, builder: (column) => column);
}

class $$ReceiptsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ReceiptsTable,
    ReceiptRow,
    $$ReceiptsTableFilterComposer,
    $$ReceiptsTableOrderingComposer,
    $$ReceiptsTableAnnotationComposer,
    $$ReceiptsTableCreateCompanionBuilder,
    $$ReceiptsTableUpdateCompanionBuilder,
    (ReceiptRow, BaseReferences<_$AppDatabase, $ReceiptsTable, ReceiptRow>),
    ReceiptRow,
    PrefetchHooks Function()> {
  $$ReceiptsTableTableManager(_$AppDatabase db, $ReceiptsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReceiptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReceiptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReceiptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> messageId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> deviceId = const Value.absent(),
            Value<DateTime?> deliveredAt = const Value.absent(),
            Value<DateTime?> readAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReceiptsCompanion(
            messageId: messageId,
            userId: userId,
            deviceId: deviceId,
            deliveredAt: deliveredAt,
            readAt: readAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String messageId,
            required String userId,
            required String deviceId,
            Value<DateTime?> deliveredAt = const Value.absent(),
            Value<DateTime?> readAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReceiptsCompanion.insert(
            messageId: messageId,
            userId: userId,
            deviceId: deviceId,
            deliveredAt: deliveredAt,
            readAt: readAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ReceiptsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ReceiptsTable,
    ReceiptRow,
    $$ReceiptsTableFilterComposer,
    $$ReceiptsTableOrderingComposer,
    $$ReceiptsTableAnnotationComposer,
    $$ReceiptsTableCreateCompanionBuilder,
    $$ReceiptsTableUpdateCompanionBuilder,
    (ReceiptRow, BaseReferences<_$AppDatabase, $ReceiptsTable, ReceiptRow>),
    ReceiptRow,
    PrefetchHooks Function()>;
typedef $$OutboxItemsTableCreateCompanionBuilder = OutboxItemsCompanion
    Function({
  required String id,
  required String groupId,
  required Uint8List encryptedEnvelope,
  required String recipientDeviceIds,
  Value<int> retryCount,
  required DateTime createdAt,
  required DateTime nextRetryAt,
  Value<int> rowid,
});
typedef $$OutboxItemsTableUpdateCompanionBuilder = OutboxItemsCompanion
    Function({
  Value<String> id,
  Value<String> groupId,
  Value<Uint8List> encryptedEnvelope,
  Value<String> recipientDeviceIds,
  Value<int> retryCount,
  Value<DateTime> createdAt,
  Value<DateTime> nextRetryAt,
  Value<int> rowid,
});

class $$OutboxItemsTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxItemsTable> {
  $$OutboxItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupId => $composableBuilder(
      column: $table.groupId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<Uint8List> get encryptedEnvelope => $composableBuilder(
      column: $table.encryptedEnvelope,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recipientDeviceIds => $composableBuilder(
      column: $table.recipientDeviceIds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get nextRetryAt => $composableBuilder(
      column: $table.nextRetryAt, builder: (column) => ColumnFilters(column));
}

class $$OutboxItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxItemsTable> {
  $$OutboxItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupId => $composableBuilder(
      column: $table.groupId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<Uint8List> get encryptedEnvelope => $composableBuilder(
      column: $table.encryptedEnvelope,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recipientDeviceIds => $composableBuilder(
      column: $table.recipientDeviceIds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get nextRetryAt => $composableBuilder(
      column: $table.nextRetryAt, builder: (column) => ColumnOrderings(column));
}

class $$OutboxItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxItemsTable> {
  $$OutboxItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => column);

  GeneratedColumn<Uint8List> get encryptedEnvelope => $composableBuilder(
      column: $table.encryptedEnvelope, builder: (column) => column);

  GeneratedColumn<String> get recipientDeviceIds => $composableBuilder(
      column: $table.recipientDeviceIds, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get nextRetryAt => $composableBuilder(
      column: $table.nextRetryAt, builder: (column) => column);
}

class $$OutboxItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OutboxItemsTable,
    OutboxItemRow,
    $$OutboxItemsTableFilterComposer,
    $$OutboxItemsTableOrderingComposer,
    $$OutboxItemsTableAnnotationComposer,
    $$OutboxItemsTableCreateCompanionBuilder,
    $$OutboxItemsTableUpdateCompanionBuilder,
    (
      OutboxItemRow,
      BaseReferences<_$AppDatabase, $OutboxItemsTable, OutboxItemRow>
    ),
    OutboxItemRow,
    PrefetchHooks Function()> {
  $$OutboxItemsTableTableManager(_$AppDatabase db, $OutboxItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> groupId = const Value.absent(),
            Value<Uint8List> encryptedEnvelope = const Value.absent(),
            Value<String> recipientDeviceIds = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> nextRetryAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxItemsCompanion(
            id: id,
            groupId: groupId,
            encryptedEnvelope: encryptedEnvelope,
            recipientDeviceIds: recipientDeviceIds,
            retryCount: retryCount,
            createdAt: createdAt,
            nextRetryAt: nextRetryAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String groupId,
            required Uint8List encryptedEnvelope,
            required String recipientDeviceIds,
            Value<int> retryCount = const Value.absent(),
            required DateTime createdAt,
            required DateTime nextRetryAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxItemsCompanion.insert(
            id: id,
            groupId: groupId,
            encryptedEnvelope: encryptedEnvelope,
            recipientDeviceIds: recipientDeviceIds,
            retryCount: retryCount,
            createdAt: createdAt,
            nextRetryAt: nextRetryAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OutboxItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OutboxItemsTable,
    OutboxItemRow,
    $$OutboxItemsTableFilterComposer,
    $$OutboxItemsTableOrderingComposer,
    $$OutboxItemsTableAnnotationComposer,
    $$OutboxItemsTableCreateCompanionBuilder,
    $$OutboxItemsTableUpdateCompanionBuilder,
    (
      OutboxItemRow,
      BaseReferences<_$AppDatabase, $OutboxItemsTable, OutboxItemRow>
    ),
    OutboxItemRow,
    PrefetchHooks Function()>;
typedef $$RatchetSessionsTableCreateCompanionBuilder = RatchetSessionsCompanion
    Function({
  required String sessionId,
  required Uint8List encryptedState,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$RatchetSessionsTableUpdateCompanionBuilder = RatchetSessionsCompanion
    Function({
  Value<String> sessionId,
  Value<Uint8List> encryptedState,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$RatchetSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $RatchetSessionsTable> {
  $$RatchetSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<Uint8List> get encryptedState => $composableBuilder(
      column: $table.encryptedState,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$RatchetSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $RatchetSessionsTable> {
  $$RatchetSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<Uint8List> get encryptedState => $composableBuilder(
      column: $table.encryptedState,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$RatchetSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RatchetSessionsTable> {
  $$RatchetSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<Uint8List> get encryptedState => $composableBuilder(
      column: $table.encryptedState, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$RatchetSessionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RatchetSessionsTable,
    RatchetSessionRow,
    $$RatchetSessionsTableFilterComposer,
    $$RatchetSessionsTableOrderingComposer,
    $$RatchetSessionsTableAnnotationComposer,
    $$RatchetSessionsTableCreateCompanionBuilder,
    $$RatchetSessionsTableUpdateCompanionBuilder,
    (
      RatchetSessionRow,
      BaseReferences<_$AppDatabase, $RatchetSessionsTable, RatchetSessionRow>
    ),
    RatchetSessionRow,
    PrefetchHooks Function()> {
  $$RatchetSessionsTableTableManager(
      _$AppDatabase db, $RatchetSessionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RatchetSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RatchetSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RatchetSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> sessionId = const Value.absent(),
            Value<Uint8List> encryptedState = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RatchetSessionsCompanion(
            sessionId: sessionId,
            encryptedState: encryptedState,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String sessionId,
            required Uint8List encryptedState,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              RatchetSessionsCompanion.insert(
            sessionId: sessionId,
            encryptedState: encryptedState,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RatchetSessionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RatchetSessionsTable,
    RatchetSessionRow,
    $$RatchetSessionsTableFilterComposer,
    $$RatchetSessionsTableOrderingComposer,
    $$RatchetSessionsTableAnnotationComposer,
    $$RatchetSessionsTableCreateCompanionBuilder,
    $$RatchetSessionsTableUpdateCompanionBuilder,
    (
      RatchetSessionRow,
      BaseReferences<_$AppDatabase, $RatchetSessionsTable, RatchetSessionRow>
    ),
    RatchetSessionRow,
    PrefetchHooks Function()>;
typedef $$MediaItemsTableCreateCompanionBuilder = MediaItemsCompanion Function({
  required String mediaId,
  required String groupId,
  required String messageId,
  required String mimeType,
  Value<String?> localPath,
  required String downloadUrl,
  required String encryptedKeyJson,
  required int sizeBytes,
  Value<bool> isDownloaded,
  Value<int> rowid,
});
typedef $$MediaItemsTableUpdateCompanionBuilder = MediaItemsCompanion Function({
  Value<String> mediaId,
  Value<String> groupId,
  Value<String> messageId,
  Value<String> mimeType,
  Value<String?> localPath,
  Value<String> downloadUrl,
  Value<String> encryptedKeyJson,
  Value<int> sizeBytes,
  Value<bool> isDownloaded,
  Value<int> rowid,
});

class $$MediaItemsTableFilterComposer
    extends Composer<_$AppDatabase, $MediaItemsTable> {
  $$MediaItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get mediaId => $composableBuilder(
      column: $table.mediaId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupId => $composableBuilder(
      column: $table.groupId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get messageId => $composableBuilder(
      column: $table.messageId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mimeType => $composableBuilder(
      column: $table.mimeType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get downloadUrl => $composableBuilder(
      column: $table.downloadUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get encryptedKeyJson => $composableBuilder(
      column: $table.encryptedKeyJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sizeBytes => $composableBuilder(
      column: $table.sizeBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDownloaded => $composableBuilder(
      column: $table.isDownloaded, builder: (column) => ColumnFilters(column));
}

class $$MediaItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $MediaItemsTable> {
  $$MediaItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get mediaId => $composableBuilder(
      column: $table.mediaId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupId => $composableBuilder(
      column: $table.groupId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get messageId => $composableBuilder(
      column: $table.messageId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mimeType => $composableBuilder(
      column: $table.mimeType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get downloadUrl => $composableBuilder(
      column: $table.downloadUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get encryptedKeyJson => $composableBuilder(
      column: $table.encryptedKeyJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
      column: $table.sizeBytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDownloaded => $composableBuilder(
      column: $table.isDownloaded,
      builder: (column) => ColumnOrderings(column));
}

class $$MediaItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MediaItemsTable> {
  $$MediaItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get mediaId =>
      $composableBuilder(column: $table.mediaId, builder: (column) => column);

  GeneratedColumn<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get downloadUrl => $composableBuilder(
      column: $table.downloadUrl, builder: (column) => column);

  GeneratedColumn<String> get encryptedKeyJson => $composableBuilder(
      column: $table.encryptedKeyJson, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<bool> get isDownloaded => $composableBuilder(
      column: $table.isDownloaded, builder: (column) => column);
}

class $$MediaItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MediaItemsTable,
    MediaItemRow,
    $$MediaItemsTableFilterComposer,
    $$MediaItemsTableOrderingComposer,
    $$MediaItemsTableAnnotationComposer,
    $$MediaItemsTableCreateCompanionBuilder,
    $$MediaItemsTableUpdateCompanionBuilder,
    (
      MediaItemRow,
      BaseReferences<_$AppDatabase, $MediaItemsTable, MediaItemRow>
    ),
    MediaItemRow,
    PrefetchHooks Function()> {
  $$MediaItemsTableTableManager(_$AppDatabase db, $MediaItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> mediaId = const Value.absent(),
            Value<String> groupId = const Value.absent(),
            Value<String> messageId = const Value.absent(),
            Value<String> mimeType = const Value.absent(),
            Value<String?> localPath = const Value.absent(),
            Value<String> downloadUrl = const Value.absent(),
            Value<String> encryptedKeyJson = const Value.absent(),
            Value<int> sizeBytes = const Value.absent(),
            Value<bool> isDownloaded = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MediaItemsCompanion(
            mediaId: mediaId,
            groupId: groupId,
            messageId: messageId,
            mimeType: mimeType,
            localPath: localPath,
            downloadUrl: downloadUrl,
            encryptedKeyJson: encryptedKeyJson,
            sizeBytes: sizeBytes,
            isDownloaded: isDownloaded,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String mediaId,
            required String groupId,
            required String messageId,
            required String mimeType,
            Value<String?> localPath = const Value.absent(),
            required String downloadUrl,
            required String encryptedKeyJson,
            required int sizeBytes,
            Value<bool> isDownloaded = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MediaItemsCompanion.insert(
            mediaId: mediaId,
            groupId: groupId,
            messageId: messageId,
            mimeType: mimeType,
            localPath: localPath,
            downloadUrl: downloadUrl,
            encryptedKeyJson: encryptedKeyJson,
            sizeBytes: sizeBytes,
            isDownloaded: isDownloaded,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MediaItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MediaItemsTable,
    MediaItemRow,
    $$MediaItemsTableFilterComposer,
    $$MediaItemsTableOrderingComposer,
    $$MediaItemsTableAnnotationComposer,
    $$MediaItemsTableCreateCompanionBuilder,
    $$MediaItemsTableUpdateCompanionBuilder,
    (
      MediaItemRow,
      BaseReferences<_$AppDatabase, $MediaItemsTable, MediaItemRow>
    ),
    MediaItemRow,
    PrefetchHooks Function()>;
typedef $$UnackedRatchetsTableCreateCompanionBuilder = UnackedRatchetsCompanion
    Function({
  required String id,
  required String sessionKey,
  required String sessionType,
  required String serializedState,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$UnackedRatchetsTableUpdateCompanionBuilder = UnackedRatchetsCompanion
    Function({
  Value<String> id,
  Value<String> sessionKey,
  Value<String> sessionType,
  Value<String> serializedState,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$UnackedRatchetsTableFilterComposer
    extends Composer<_$AppDatabase, $UnackedRatchetsTable> {
  $$UnackedRatchetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sessionKey => $composableBuilder(
      column: $table.sessionKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sessionType => $composableBuilder(
      column: $table.sessionType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serializedState => $composableBuilder(
      column: $table.serializedState,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$UnackedRatchetsTableOrderingComposer
    extends Composer<_$AppDatabase, $UnackedRatchetsTable> {
  $$UnackedRatchetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sessionKey => $composableBuilder(
      column: $table.sessionKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sessionType => $composableBuilder(
      column: $table.sessionType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serializedState => $composableBuilder(
      column: $table.serializedState,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$UnackedRatchetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UnackedRatchetsTable> {
  $$UnackedRatchetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionKey => $composableBuilder(
      column: $table.sessionKey, builder: (column) => column);

  GeneratedColumn<String> get sessionType => $composableBuilder(
      column: $table.sessionType, builder: (column) => column);

  GeneratedColumn<String> get serializedState => $composableBuilder(
      column: $table.serializedState, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$UnackedRatchetsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UnackedRatchetsTable,
    UnackedRatchetRow,
    $$UnackedRatchetsTableFilterComposer,
    $$UnackedRatchetsTableOrderingComposer,
    $$UnackedRatchetsTableAnnotationComposer,
    $$UnackedRatchetsTableCreateCompanionBuilder,
    $$UnackedRatchetsTableUpdateCompanionBuilder,
    (
      UnackedRatchetRow,
      BaseReferences<_$AppDatabase, $UnackedRatchetsTable, UnackedRatchetRow>
    ),
    UnackedRatchetRow,
    PrefetchHooks Function()> {
  $$UnackedRatchetsTableTableManager(
      _$AppDatabase db, $UnackedRatchetsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UnackedRatchetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UnackedRatchetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UnackedRatchetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> sessionKey = const Value.absent(),
            Value<String> sessionType = const Value.absent(),
            Value<String> serializedState = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UnackedRatchetsCompanion(
            id: id,
            sessionKey: sessionKey,
            sessionType: sessionType,
            serializedState: serializedState,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String sessionKey,
            required String sessionType,
            required String serializedState,
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              UnackedRatchetsCompanion.insert(
            id: id,
            sessionKey: sessionKey,
            sessionType: sessionType,
            serializedState: serializedState,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UnackedRatchetsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UnackedRatchetsTable,
    UnackedRatchetRow,
    $$UnackedRatchetsTableFilterComposer,
    $$UnackedRatchetsTableOrderingComposer,
    $$UnackedRatchetsTableAnnotationComposer,
    $$UnackedRatchetsTableCreateCompanionBuilder,
    $$UnackedRatchetsTableUpdateCompanionBuilder,
    (
      UnackedRatchetRow,
      BaseReferences<_$AppDatabase, $UnackedRatchetsTable, UnackedRatchetRow>
    ),
    UnackedRatchetRow,
    PrefetchHooks Function()>;
typedef $$DecryptedMessagesTableCreateCompanionBuilder
    = DecryptedMessagesCompanion Function({
  required String messageId,
  required String plaintext,
  Value<String?> mediaJson,
  required DateTime cachedAt,
  Value<int> rowid,
});
typedef $$DecryptedMessagesTableUpdateCompanionBuilder
    = DecryptedMessagesCompanion Function({
  Value<String> messageId,
  Value<String> plaintext,
  Value<String?> mediaJson,
  Value<DateTime> cachedAt,
  Value<int> rowid,
});

class $$DecryptedMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $DecryptedMessagesTable> {
  $$DecryptedMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get messageId => $composableBuilder(
      column: $table.messageId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get plaintext => $composableBuilder(
      column: $table.plaintext, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mediaJson => $composableBuilder(
      column: $table.mediaJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnFilters(column));
}

class $$DecryptedMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $DecryptedMessagesTable> {
  $$DecryptedMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get messageId => $composableBuilder(
      column: $table.messageId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get plaintext => $composableBuilder(
      column: $table.plaintext, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mediaJson => $composableBuilder(
      column: $table.mediaJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnOrderings(column));
}

class $$DecryptedMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DecryptedMessagesTable> {
  $$DecryptedMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get plaintext =>
      $composableBuilder(column: $table.plaintext, builder: (column) => column);

  GeneratedColumn<String> get mediaJson =>
      $composableBuilder(column: $table.mediaJson, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$DecryptedMessagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DecryptedMessagesTable,
    DecryptedMessageRow,
    $$DecryptedMessagesTableFilterComposer,
    $$DecryptedMessagesTableOrderingComposer,
    $$DecryptedMessagesTableAnnotationComposer,
    $$DecryptedMessagesTableCreateCompanionBuilder,
    $$DecryptedMessagesTableUpdateCompanionBuilder,
    (
      DecryptedMessageRow,
      BaseReferences<_$AppDatabase, $DecryptedMessagesTable,
          DecryptedMessageRow>
    ),
    DecryptedMessageRow,
    PrefetchHooks Function()> {
  $$DecryptedMessagesTableTableManager(
      _$AppDatabase db, $DecryptedMessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DecryptedMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DecryptedMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DecryptedMessagesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> messageId = const Value.absent(),
            Value<String> plaintext = const Value.absent(),
            Value<String?> mediaJson = const Value.absent(),
            Value<DateTime> cachedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DecryptedMessagesCompanion(
            messageId: messageId,
            plaintext: plaintext,
            mediaJson: mediaJson,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String messageId,
            required String plaintext,
            Value<String?> mediaJson = const Value.absent(),
            required DateTime cachedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              DecryptedMessagesCompanion.insert(
            messageId: messageId,
            plaintext: plaintext,
            mediaJson: mediaJson,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DecryptedMessagesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DecryptedMessagesTable,
    DecryptedMessageRow,
    $$DecryptedMessagesTableFilterComposer,
    $$DecryptedMessagesTableOrderingComposer,
    $$DecryptedMessagesTableAnnotationComposer,
    $$DecryptedMessagesTableCreateCompanionBuilder,
    $$DecryptedMessagesTableUpdateCompanionBuilder,
    (
      DecryptedMessageRow,
      BaseReferences<_$AppDatabase, $DecryptedMessagesTable,
          DecryptedMessageRow>
    ),
    DecryptedMessageRow,
    PrefetchHooks Function()>;
typedef $$ProcessedDistributionsTableCreateCompanionBuilder
    = ProcessedDistributionsCompanion Function({
  required String messageId,
  required DateTime processedAt,
  Value<int> rowid,
});
typedef $$ProcessedDistributionsTableUpdateCompanionBuilder
    = ProcessedDistributionsCompanion Function({
  Value<String> messageId,
  Value<DateTime> processedAt,
  Value<int> rowid,
});

class $$ProcessedDistributionsTableFilterComposer
    extends Composer<_$AppDatabase, $ProcessedDistributionsTable> {
  $$ProcessedDistributionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get messageId => $composableBuilder(
      column: $table.messageId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get processedAt => $composableBuilder(
      column: $table.processedAt, builder: (column) => ColumnFilters(column));
}

class $$ProcessedDistributionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProcessedDistributionsTable> {
  $$ProcessedDistributionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get messageId => $composableBuilder(
      column: $table.messageId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get processedAt => $composableBuilder(
      column: $table.processedAt, builder: (column) => ColumnOrderings(column));
}

class $$ProcessedDistributionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProcessedDistributionsTable> {
  $$ProcessedDistributionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<DateTime> get processedAt => $composableBuilder(
      column: $table.processedAt, builder: (column) => column);
}

class $$ProcessedDistributionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProcessedDistributionsTable,
    ProcessedDistributionRow,
    $$ProcessedDistributionsTableFilterComposer,
    $$ProcessedDistributionsTableOrderingComposer,
    $$ProcessedDistributionsTableAnnotationComposer,
    $$ProcessedDistributionsTableCreateCompanionBuilder,
    $$ProcessedDistributionsTableUpdateCompanionBuilder,
    (
      ProcessedDistributionRow,
      BaseReferences<_$AppDatabase, $ProcessedDistributionsTable,
          ProcessedDistributionRow>
    ),
    ProcessedDistributionRow,
    PrefetchHooks Function()> {
  $$ProcessedDistributionsTableTableManager(
      _$AppDatabase db, $ProcessedDistributionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProcessedDistributionsTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$ProcessedDistributionsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProcessedDistributionsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> messageId = const Value.absent(),
            Value<DateTime> processedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProcessedDistributionsCompanion(
            messageId: messageId,
            processedAt: processedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String messageId,
            required DateTime processedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ProcessedDistributionsCompanion.insert(
            messageId: messageId,
            processedAt: processedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ProcessedDistributionsTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $ProcessedDistributionsTable,
        ProcessedDistributionRow,
        $$ProcessedDistributionsTableFilterComposer,
        $$ProcessedDistributionsTableOrderingComposer,
        $$ProcessedDistributionsTableAnnotationComposer,
        $$ProcessedDistributionsTableCreateCompanionBuilder,
        $$ProcessedDistributionsTableUpdateCompanionBuilder,
        (
          ProcessedDistributionRow,
          BaseReferences<_$AppDatabase, $ProcessedDistributionsTable,
              ProcessedDistributionRow>
        ),
        ProcessedDistributionRow,
        PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$MessageCiphertextsTableTableManager get messageCiphertexts =>
      $$MessageCiphertextsTableTableManager(_db, _db.messageCiphertexts);
  $$ConversationsTableTableManager get conversations =>
      $$ConversationsTableTableManager(_db, _db.conversations);
  $$ReceiptsTableTableManager get receipts =>
      $$ReceiptsTableTableManager(_db, _db.receipts);
  $$OutboxItemsTableTableManager get outboxItems =>
      $$OutboxItemsTableTableManager(_db, _db.outboxItems);
  $$RatchetSessionsTableTableManager get ratchetSessions =>
      $$RatchetSessionsTableTableManager(_db, _db.ratchetSessions);
  $$MediaItemsTableTableManager get mediaItems =>
      $$MediaItemsTableTableManager(_db, _db.mediaItems);
  $$UnackedRatchetsTableTableManager get unackedRatchets =>
      $$UnackedRatchetsTableTableManager(_db, _db.unackedRatchets);
  $$DecryptedMessagesTableTableManager get decryptedMessages =>
      $$DecryptedMessagesTableTableManager(_db, _db.decryptedMessages);
  $$ProcessedDistributionsTableTableManager get processedDistributions =>
      $$ProcessedDistributionsTableTableManager(
          _db, _db.processedDistributions);
}
