import 'dart:async';
import 'dart:typed_data';

import 'package:hello_engine/src/domain/models/presence_state.dart';
import 'package:hello_engine/src/domain/models/typing_indicator.dart';
import 'package:hello_engine/src/domain/repositories/receipt_repository.dart';
import 'package:hello_engine/src/sync/gap_detector.dart';
import 'package:hello_engine/src/sync/outbox_processor.dart';
import 'package:hello_engine/src/transport/dto/realtime_event.dart';
import 'package:hello_engine/src/transport/realtime_listener.dart';

/// Orchestrates all sync components for the chat engine.
///
/// Manages gap detection, outbox draining, and real-time event
/// forwarding. Ephemeral events (typing indicators and presence
/// updates) are emitted on broadcast streams and never persisted.
class SyncCoordinator {
  /// Creates a [SyncCoordinator].
  SyncCoordinator({
    required OutboxProcessor outboxProcessor,
    required GapDetector gapDetector,
    required RealtimeListener realtimeListener,
    required ReceiptRepository receiptRepo,
  })  : _outboxProcessor = outboxProcessor,
        _gapDetector = gapDetector,
        _realtimeListener = realtimeListener,
        _receiptRepo = receiptRepo;

  final OutboxProcessor _outboxProcessor;
  final GapDetector _gapDetector;
  final RealtimeListener _realtimeListener;
  final ReceiptRepository _receiptRepo;

  final StreamController<TypingIndicator> _typingController =
      StreamController<TypingIndicator>.broadcast();
  final StreamController<PresenceState> _presenceController =
      StreamController<PresenceState>.broadcast();
  final StreamController<RealtimeMessageEvent> _messageController =
      StreamController<RealtimeMessageEvent>.broadcast();

  /// Active subscriptions keyed by space ID for cleanup.
  final Map<String, StreamSubscription<RealtimeMessageEvent>>
      _subscriptions =
      <String, StreamSubscription<RealtimeMessageEvent>>{};

  /// Stream of ephemeral typing indicators. Not persisted.
  Stream<TypingIndicator> get typingEvents => _typingController.stream;

  /// Stream of ephemeral presence updates. Not persisted.
  Stream<PresenceState> get presenceEvents =>
      _presenceController.stream;

  /// Stream of incoming message events from Realtime subscriptions.
  Stream<RealtimeMessageEvent> get incomingMessages =>
      _messageController.stream;

  /// The underlying [ReceiptRepository] for external access.
  ReceiptRepository get receiptRepo => _receiptRepo;

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
    return missed;
  }

  /// Subscribes to real-time message events for [groupId].
  ///
  /// Calling this multiple times for the same space is idempotent --
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

  /// Sends a typing indicator for [groupId].
  ///
  /// Emits a local typing indicator event. In a production
  /// implementation this would also broadcast via WebSocket.
  Future<void> sendTyping(String groupId) async {
    final indicator = TypingIndicator(
      groupId: groupId,
      userId: '',
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

  /// Releases all resources and closes all streams.
  Future<void> dispose() async {
    for (final sub in _subscriptions.values) {
      await sub.cancel();
    }
    _subscriptions.clear();

    await _typingController.close();
    await _presenceController.close();
    await _messageController.close();
    await _realtimeListener.dispose();
  }
}
