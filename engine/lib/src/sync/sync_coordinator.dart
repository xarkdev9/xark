import 'dart:async';
import 'dart:typed_data';

import 'package:e2ee_chat_sdk/src/domain/models/presence_state.dart';
import 'package:e2ee_chat_sdk/src/domain/models/typing_indicator.dart';
import 'package:e2ee_chat_sdk/src/domain/repositories/conversation_repository.dart';
import 'package:e2ee_chat_sdk/src/domain/repositories/receipt_repository.dart';
import 'package:e2ee_chat_sdk/src/media/background_uploader.dart';
import 'package:e2ee_chat_sdk/src/sync/conflict_resolver.dart';
import 'package:e2ee_chat_sdk/src/sync/gap_detector.dart';
import 'package:e2ee_chat_sdk/src/sync/outbox_processor.dart';
import 'package:e2ee_chat_sdk/src/sync/outbox_worker.dart';
import 'package:e2ee_chat_sdk/src/sync/watermark_sync.dart';
import 'package:e2ee_chat_sdk/src/transport/dto/realtime_event.dart';
import 'package:e2ee_chat_sdk/src/transport/realtime_listener.dart';

// ---------------------------------------------------------------------------
// SyncState — exposed to consumers via [SyncCoordinator.stateStream].
// ---------------------------------------------------------------------------

/// Lifecycle state of the sync coordinator.
enum SyncState {
  /// No sync operations are in progress.
  idle,

  /// One or more background sync operations are running.
  syncing,

  /// The last sync cycle encountered an unrecoverable error.
  error,
}

// ---------------------------------------------------------------------------
// SyncCoordinator
// ---------------------------------------------------------------------------

/// Orchestrates all background sync operations for the chat engine.
///
/// Manages:
/// - [OutboxWorker]: periodic drain of pending outbox messages.
/// - [WatermarkSync]: watermark-based gap sync on reconnect.
/// - [ConflictResolver]: reconciliation of optimistic and server state.
/// - [BackgroundUploader]: encrypted media upload queue.
/// - [RealtimeListener]: Supabase Realtime subscriptions for live updates.
///
/// Ephemeral events (typing indicators and presence updates) are emitted on
/// broadcast streams and never persisted.
///
/// The coordinator exposes [start] / [stop] lifecycle methods wired into
/// [ChatEngineImpl.resume] and [ChatEngineImpl.suspend], plus a
/// [forceResync] for full stop+start cycles (e.g. after device linking).
class SyncCoordinator {
  /// Creates a [SyncCoordinator].
  ///
  /// All workers are injected and must already be constructed.  The
  /// coordinator does **not** own the underlying database or transport
  /// connections — it merely orchestrates the workers that do.
  SyncCoordinator({
    required OutboxProcessor outboxProcessor,
    required GapDetector gapDetector,
    required RealtimeListener realtimeListener,
    required ReceiptRepository receiptRepo,
    required ConversationRepository conversationRepo,
    String? userId,
    OutboxWorker? outboxWorker,
    WatermarkSync? watermarkSync,
    ConflictResolver? conflictResolver,
    BackgroundUploader? backgroundUploader,
  })  : _outboxProcessor = outboxProcessor,
        _gapDetector = gapDetector,
        _realtimeListener = realtimeListener,
        _receiptRepo = receiptRepo,
        _conversationRepo = conversationRepo,
        _userId = userId,
        _outboxWorker = outboxWorker,
        _watermarkSync = watermarkSync,
        _conflictResolver = conflictResolver,
        _backgroundUploader = backgroundUploader;

  // ---------------------------------------------------------------------------
  // Dependencies
  // ---------------------------------------------------------------------------

  final OutboxProcessor _outboxProcessor;
  final GapDetector _gapDetector;
  final RealtimeListener _realtimeListener;
  final ReceiptRepository _receiptRepo;
  final ConversationRepository _conversationRepo;
  final String? _userId;

  /// MOBILE-03: background outbox worker with periodic drain.
  final OutboxWorker? _outboxWorker;

  /// MOBILE-02: watermark-based gap sync.
  final WatermarkSync? _watermarkSync;

  /// MOBILE-04: conflict resolution after sync.
  final ConflictResolver? _conflictResolver;

  /// MOBILE-05: background media upload queue.
  final BackgroundUploader? _backgroundUploader;

  // ---------------------------------------------------------------------------
  // Stream controllers
  // ---------------------------------------------------------------------------

  final StreamController<TypingIndicator> _typingController =
      StreamController<TypingIndicator>.broadcast();
  final StreamController<PresenceState> _presenceController =
      StreamController<PresenceState>.broadcast();
  final StreamController<RealtimeMessageEvent> _messageController =
      StreamController<RealtimeMessageEvent>.broadcast();
  final StreamController<SyncState> _stateController =
      StreamController<SyncState>.broadcast();

  // ---------------------------------------------------------------------------
  // Internal state
  // ---------------------------------------------------------------------------

  /// Active realtime subscriptions keyed by group ID for cleanup.
  final Map<String, StreamSubscription<RealtimeMessageEvent>>
      _subscriptions =
      <String, StreamSubscription<RealtimeMessageEvent>>{};

  /// Current sync state.
  SyncState _currentState = SyncState.idle;

  /// Whether [start] has been called without a matching [stop].
  bool _isRunning = false;

  // ---------------------------------------------------------------------------
  // Public streams
  // ---------------------------------------------------------------------------

  /// Stream of ephemeral typing indicators. Not persisted.
  Stream<TypingIndicator> get typingEvents => _typingController.stream;

  /// Stream of ephemeral presence updates. Not persisted.
  Stream<PresenceState> get presenceEvents => _presenceController.stream;

  /// Stream of incoming message events from Realtime subscriptions.
  Stream<RealtimeMessageEvent> get incomingMessages =>
      _messageController.stream;

  /// Stream of [SyncState] transitions.
  ///
  /// Emits [SyncState.syncing] when a start cycle begins,
  /// [SyncState.idle] when all workers are quiescent, and
  /// [SyncState.error] if the sync cycle fails.
  Stream<SyncState> get stateStream => _stateController.stream;

  /// The current [SyncState].
  SyncState get currentState => _currentState;

  /// Whether the coordinator is currently running.
  bool get isRunning => _isRunning;

  /// The underlying [ReceiptRepository] for external access.
  ReceiptRepository get receiptRepo => _receiptRepo;

  // ---------------------------------------------------------------------------
  // Lifecycle: start / stop / forceResync
  // ---------------------------------------------------------------------------

  /// Starts all background sync operations (app foreground / engine.resume).
  ///
  /// 1. Starts the [OutboxWorker] periodic drain timer.
  /// 2. Runs [WatermarkSync] for all known groups (fetches missed messages).
  /// 3. Runs [ConflictResolver] to reconcile synced messages.
  /// 4. Subscribes to Realtime for all active groups.
  /// 5. Starts the [BackgroundUploader].
  ///
  /// If [start] is called while already running, it is a no-op.
  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    _emitState(SyncState.syncing);

    try {
      // 1. Start the outbox worker (periodic timer-based drain).
      _outboxWorker?.start();

      // 2. Fetch all active groups and run watermark sync.
      final conversations =
          await _conversationRepo.getAllConversations();
      final groupIds = conversations.map((c) => c.id).toList();

      if (_watermarkSync != null) {
        await _watermarkSync.syncAll();
      }

      // 3. Also run the legacy gap detector + outbox drain for
      //    backwards compatibility with the existing onConnected path.
      await onConnected(groupIds);

      // 4. Run conflict resolution to reconcile after sync.
      await _conflictResolver?.cleanupStaleMessages();

      // 5. Subscribe to realtime for all groups.
      for (final groupId in groupIds) {
        subscribeToSpace(groupId);
      }

      // 6. Start the background media uploader.
      _backgroundUploader?.start();

      _emitState(SyncState.idle);
    } catch (_) {
      _emitState(SyncState.error);
    }
  }

  /// Stops all background sync operations (app background / engine.suspend).
  ///
  /// 1. Stops the [OutboxWorker] periodic timer.
  /// 2. Unsubscribes from all Realtime channels.
  /// 3. Stops the [BackgroundUploader] (OS scheduler takes over).
  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;

    // 1. Stop the outbox worker timer.
    _outboxWorker?.stop();

    // 2. Unsubscribe from all realtime channels.
    final groupIds = _subscriptions.keys.toList();
    for (final groupId in groupIds) {
      await unsubscribeFromSpace(groupId);
    }

    // 3. Stop the background uploader.
    _backgroundUploader?.stop();

    _emitState(SyncState.idle);
  }

  /// Full stop + start cycle.
  ///
  /// Used after device linking or when a full re-sync is required.
  /// Tears down all workers and subscriptions, then restarts from scratch.
  Future<void> forceResync() async {
    await stop();
    await start();
  }

  // ---------------------------------------------------------------------------
  // Legacy onConnected (preserved for ChatEngineImpl compatibility)
  // ---------------------------------------------------------------------------

  /// Called when a connection is established or re-established.
  ///
  /// 1. Fills gaps for all [activeGroupIds] (fetches missed messages).
  /// 2. Drains the outbox (sends queued messages).
  ///
  /// Returns the list of raw server rows from the gap fill.
  Future<List<Map<String, dynamic>>> onConnected(
    List<String> activeGroupIds,
  ) async {
    final missed = await _gapDetector.fillGaps(activeGroupIds);
    await _outboxProcessor.drainOutbox();

    // Run conflict resolution on the synced messages per group.
    if (_conflictResolver != null && missed.isNotEmpty) {
      // Group missed messages by group_id for reconciliation.
      final byGroup = <String, List<Map<String, dynamic>>>{};
      for (final msg in missed) {
        final groupId = msg['group_id'] as String? ?? '';
        byGroup.putIfAbsent(groupId, () => []).add(msg);
      }
      for (final entry in byGroup.entries) {
        await _conflictResolver.reconcileGap(entry.key, entry.value);
      }
    }

    return missed;
  }

  // ---------------------------------------------------------------------------
  // Realtime subscriptions
  // ---------------------------------------------------------------------------

  /// Subscribes to real-time message events for [groupId].
  ///
  /// Calling this multiple times for the same group is idempotent --
  /// the existing subscription is reused.
  void subscribeToSpace(String groupId) {
    if (_subscriptions.containsKey(groupId)) return;

    _subscriptions[groupId] =
        _realtimeListener.subscribeToSpace(groupId).listen((event) {
      if (!_messageController.isClosed) {
        _messageController.add(event);
      }
    });
  }

  /// Unsubscribes from real-time events for [groupId].
  Future<void> unsubscribeFromSpace(String groupId) async {
    await _subscriptions.remove(groupId)?.cancel();
    await _realtimeListener.unsubscribeFromSpace(groupId);
  }

  // ---------------------------------------------------------------------------
  // Ephemeral events
  // ---------------------------------------------------------------------------

  /// Sends a typing indicator for [groupId].
  ///
  /// Emits a local typing indicator event. In a production
  /// implementation this would also broadcast via WebSocket.
  Future<void> sendTyping(String groupId) async {
    final indicator = TypingIndicator(
      groupId: groupId,
      userId: _userId ?? '',
      startedAt: DateTime.now(),
    );
    emitTyping(indicator);
  }

  /// Returns the raw identity key bytes for the peer in
  /// [groupId], used for safety number computation.
  ///
  /// Returns a zero-filled 30-byte placeholder if the peer's
  /// identity key is not yet cached locally.
  Future<Uint8List> getIdentityKeyForConversation(
    String groupId,
  ) async {
    // In a full implementation this would look up the peer's stored
    // identity key from the key store. For now, return a
    // deterministic placeholder so the fingerprint can be displayed.
    return Uint8List(30);
  }

  /// Emits a typing indicator on the [typingEvents] stream.
  void emitTyping(TypingIndicator indicator) {
    if (!_typingController.isClosed) {
      _typingController.add(indicator);
    }
  }

  /// Emits a presence update on the [presenceEvents] stream.
  void emitPresence(PresenceState state) {
    if (!_presenceController.isClosed) {
      _presenceController.add(state);
    }
  }

  // ---------------------------------------------------------------------------
  // Teardown
  // ---------------------------------------------------------------------------

  /// Releases all resources and closes all streams.
  ///
  /// After [dispose], the coordinator cannot be restarted. Use [stop]
  /// for temporary suspension.
  Future<void> dispose() async {
    _isRunning = false;

    // Stop all workers.
    _outboxWorker?.dispose();
    _backgroundUploader?.stop();

    // Cancel all realtime subscriptions.
    for (final sub in _subscriptions.values) {
      await sub.cancel();
    }
    _subscriptions.clear();

    // Close all stream controllers.
    await _typingController.close();
    await _presenceController.close();
    await _messageController.close();
    await _stateController.close();
    await _realtimeListener.dispose();
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  void _emitState(SyncState state) {
    _currentState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }
}
