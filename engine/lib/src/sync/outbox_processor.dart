import 'dart:convert';
import 'dart:typed_data';

import 'package:hello_engine/src/persistence/database/app_database.dart';
import 'package:hello_engine/src/persistence/repositories/outbox_repository.dart';
import 'package:hello_engine/src/sync/sync_observer.dart';
import 'package:hello_engine/src/transport/dto/message_envelope.dart';
import 'package:hello_engine/src/transport/supabase_client.dart';

/// Drains the offline outbox queue with retry and exponential backoff.
///
/// Pending items are sent in sequential batches of [batchSize]. On
/// failure, items are scheduled for retry with increasing delays up
/// to [maxRetries] attempts, after which they are permanently deleted.
class OutboxProcessor {
  /// Creates an [OutboxProcessor].
  OutboxProcessor({
    required OutboxRepository outboxRepository,
    required SupabaseClientWrapper apiClient,
    this.observer,
  })  : _outbox = outboxRepository,
        _api = apiClient;

  final OutboxRepository _outbox;
  final SupabaseClientWrapper _api;

  /// Optional observer for diagnostic callbacks.
  final SyncObserver? observer;

  /// Maximum number of retry attempts before an item is discarded.
  static const int maxRetries = 10;

  /// Number of items fetched per drain iteration.
  static const int batchSize = 5;

  /// Drains all pending outbox items in batches of [batchSize].
  ///
  /// Each batch is processed in parallel. The method loops until no
  /// more items are ready for retry.
  Future<void> drainOutbox() async {
    var sent = 0;
    var failed = 0;

    while (true) {
      final pending = await _outbox.getPending(limit: batchSize);
      if (pending.isEmpty) break;

      final results = await Future.wait(
        pending.map(_processItem),
      );

      for (final success in results) {
        if (success) {
          sent++;
        } else {
          failed++;
        }
      }
    }

    observer?.onOutboxDrained(sent, failed);
  }

  Future<bool> _processItem(OutboxItemRow item) async {
    try {
      final envelope = MessageEnvelope.fromJson(
        _decodeEnvelope(item.encryptedEnvelope),
      );
      await _api.sendMessage(envelope);
      await _outbox.markSent(item.id);
      return true;
    } catch (_) {
      if (item.retryCount >= maxRetries) {
        await _outbox.delete(item.id);
      } else {
        final backoff = Duration(
          seconds: _exponentialBackoff(item.retryCount),
        );
        await _outbox.markFailed(item.id, retryAfter: backoff);
      }
      return false;
    }
  }

  /// Returns the backoff delay in seconds for the given [attempt].
  ///
  /// Progression: 1, 2, 4, 8, 16, 32, 60, 60, 60, 60.
  int _exponentialBackoff(int attempt) {
    final base = 1 << attempt; // 2^attempt
    return base.clamp(1, 60);
  }

  Map<String, dynamic> _decodeEnvelope(Uint8List bytes) {
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }
}
