import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:e2ee_chat_sdk/src/persistence/database/app_database.dart';
import 'package:e2ee_chat_sdk/src/ports/message_gateway.dart';
import 'package:e2ee_chat_sdk/src/sync/sync_observer.dart';

/// Background worker that drains the outbox queue to the server with
/// exponential backoff.
///
/// **Critical invariant:** items for the same `groupId` are drained
/// serially to prevent Double Ratchet chain scrambling. Groups themselves
/// are processed concurrently.
class OutboxWorker {
  /// Creates an [OutboxWorker].
  ///
  /// [db] is the drift database for outbox and message queries.
  /// [gateway] is the network port for sending envelopes.
  /// [observer] receives diagnostic callbacks.
  /// [pollInterval] controls the timer period (default 2 seconds).
  OutboxWorker({
    required AppDatabase db,
    required MessageGateway gateway,
    SyncObserver? observer,
    Duration pollInterval = const Duration(seconds: 2),
  })  : _db = db,
        _gateway = gateway,
        _observer = observer,
        _pollInterval = pollInterval;

  final AppDatabase _db;
  final MessageGateway _gateway;
  final SyncObserver? _observer;
  final Duration _pollInterval;

  Timer? _timer;
  bool _isDraining = false;
  bool _disposed = false;

  /// Maximum retry attempts before marking a message as permanently failed.
  static const int maxRetries = 10;

  /// Base backoff duration in seconds (doubles each retry).
  static const int _baseBackoffSeconds = 2;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Starts the periodic drain timer.
  ///
  /// Safe to call multiple times -- subsequent calls are no-ops while the
  /// timer is already running.
  void start() {
    if (_timer != null || _disposed) return;
    _timer = Timer.periodic(_pollInterval, (_) => drain());
  }

  /// Stops the periodic timer. In-flight drain cycles will finish but no
  /// new cycles will begin.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Stops the worker and marks it as disposed. Cannot be restarted.
  void dispose() {
    _disposed = true;
    stop();
    _pendingCountController.close();
  }

  // ---------------------------------------------------------------------------
  // Drain cycle
  // ---------------------------------------------------------------------------

  /// Runs a single drain cycle.
  ///
  /// Fetches all retryable outbox items, groups them by `groupId`, and
  /// processes each group serially (to protect ratchet ordering) while
  /// groups run concurrently.
  ///
  /// Guarded by [_isDraining] to prevent overlapping cycles.
  Future<void> drain() async {
    if (_isDraining || _disposed) return;
    _isDraining = true;

    try {
      final now = DateTime.now();
      final pending = await _fetchRetryableItems(now);
      if (pending.isEmpty) return;

      // Group by groupId for serial per-group drain.
      final byGroup = <String, List<OutboxItemRow>>{};
      for (final item in pending) {
        byGroup.putIfAbsent(item.groupId, () => []).add(item);
      }

      var totalSent = 0;
      var totalFailed = 0;

      // Process all groups concurrently; within each group, drain serially.
      final groupResults = await Future.wait(
        byGroup.values.map(_drainGroup),
      );

      for (final (sent, failed) in groupResults) {
        totalSent += sent;
        totalFailed += failed;
      }

      if (totalSent > 0 || totalFailed > 0) {
        _observer?.onOutboxDrained(totalSent, totalFailed);
      }

      // Notify pending-count listeners.
      await _emitPendingCount();
    } finally {
      _isDraining = false;
    }
  }

  /// Drains a single group's items serially to preserve ratchet ordering.
  ///
  /// Returns `(sentCount, failedCount)`.
  Future<(int, int)> _drainGroup(List<OutboxItemRow> items) async {
    var sent = 0;
    var failed = 0;

    for (final item in items) {
      final success = await _processItem(item);
      if (success) {
        sent++;
      } else {
        failed++;
      }
    }

    return (sent, failed);
  }

  /// Attempts to send a single outbox item.
  ///
  /// On success: deletes the outbox row and updates the local message
  /// status to `sent` with the server-assigned sequence number.
  ///
  /// On failure: increments `retryCount` and schedules exponential backoff.
  /// After [maxRetries] attempts, marks the message as permanently failed.
  Future<bool> _processItem(OutboxItemRow item) async {
    try {
      final envelope = _decodeEnvelope(item.encryptedEnvelope);
      final result = await _gateway.sendMessage(envelope);

      // Delete from outbox.
      await (_db.delete(_db.outboxItems)
            ..where((t) => t.id.equals(item.id)))
          .go();

      // Update local message status to 'sent' with server_seq.
      await (_db.update(_db.messages)..where((t) => t.id.equals(item.id)))
          .write(
        MessagesCompanion(
          status: const Value('sent'),
          serverSeq: Value(result.serverSeq),
        ),
      );

      return true;
    } catch (_) {
      final newRetryCount = item.retryCount + 1;

      if (newRetryCount >= maxRetries) {
        // Permanently failed -- remove from outbox and mark message as failed.
        await (_db.delete(_db.outboxItems)
              ..where((t) => t.id.equals(item.id)))
            .go();

        await (_db.update(_db.messages)..where((t) => t.id.equals(item.id)))
            .write(const MessagesCompanion(status: Value('failed')));
      } else {
        // Schedule retry with exponential backoff.
        final backoffSeconds = _exponentialBackoff(newRetryCount);
        final nextRetry =
            DateTime.now().add(Duration(seconds: backoffSeconds));

        await (_db.update(_db.outboxItems)
              ..where((t) => t.id.equals(item.id)))
            .write(
          OutboxItemsCompanion(
            retryCount: Value(newRetryCount),
            nextRetryAt: Value(nextRetry),
          ),
        );
      }

      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Pending count stream
  // ---------------------------------------------------------------------------

  final StreamController<int> _pendingCountController =
      StreamController<int>.broadcast();

  /// A broadcast stream emitting the number of pending outbox items.
  ///
  /// Useful for driving a UI badge that shows unsent message count.
  Stream<int> watchPendingCount() => _pendingCountController.stream;

  Future<void> _emitPendingCount() async {
    if (_pendingCountController.isClosed) return;
    final count = await _countPendingItems();
    if (!_pendingCountController.isClosed) {
      _pendingCountController.add(count);
    }
  }

  // ---------------------------------------------------------------------------
  // Database helpers
  // ---------------------------------------------------------------------------

  /// Fetches outbox items whose `nextRetryAt` is at or before [now],
  /// ordered by `createdAt` ascending (oldest first).
  Future<List<OutboxItemRow>> _fetchRetryableItems(DateTime now) async {
    final query = _db.select(_db.outboxItems)
      ..where((t) => t.nextRetryAt.isSmallerOrEqualValue(now))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query.get();
  }

  /// Returns the total count of items still in the outbox.
  Future<int> _countPendingItems() async {
    final countExpr = _db.outboxItems.id.count();
    final query = _db.selectOnly(_db.outboxItems)..addColumns([countExpr]);
    final result = await query.getSingle();
    return result.read(countExpr) ?? 0;
  }

  /// Calculates exponential backoff seconds for a given retry [attempt].
  ///
  /// Progression: 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024
  /// (base 2s doubled each attempt).
  static int _exponentialBackoff(int attempt) {
    return _baseBackoffSeconds * (1 << (attempt - 1));
  }

  /// Decodes a JSON envelope from the stored blob bytes.
  static Map<String, dynamic> _decodeEnvelope(Uint8List bytes) {
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }
}
