import 'dart:async';

import 'package:chat_engine/src/domain/models/connection_state.dart';
import 'package:chat_engine/src/transport/dto/realtime_event.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages Supabase Realtime subscriptions for incoming message
/// notifications and Sender Key recovery broadcasts.
///
/// Each space gets two channels:
/// - `chat:{spaceId}` -- Postgres changes on the `messages` table.
/// - `sk-recovery:{spaceId}` -- Broadcast channel for SK recovery
///   requests.
class RealtimeListener {
  /// Creates a [RealtimeListener].
  ///
  /// [client] is the Supabase client whose Realtime transport is used.
  RealtimeListener({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  /// Active message channels keyed by space ID.
  final Map<String, RealtimeChannel> _messageChannels =
      <String, RealtimeChannel>{};

  /// Active SK-recovery channels keyed by space ID.
  final Map<String, RealtimeChannel> _skChannels =
      <String, RealtimeChannel>{};

  /// Stream controllers for message events keyed by space ID.
  final Map<String, StreamController<RealtimeMessageEvent>>
      _messageControllers =
      <String, StreamController<RealtimeMessageEvent>>{};

  /// Stream controllers for SK recovery requests keyed by space ID.
  final Map<String, StreamController<SKRecoveryRequest>> _skControllers =
      <String, StreamController<SKRecoveryRequest>>{};

  final StreamController<EngineConnectionState> _connectionController =
      StreamController<EngineConnectionState>.broadcast();

  /// A stream of engine connection state changes derived from Realtime
  /// channel status callbacks.
  Stream<EngineConnectionState> get connectionState =>
      _connectionController.stream;

  /// Subscribes to new-message Postgres change events for [spaceId].
  ///
  /// Returns a broadcast stream of [RealtimeMessageEvent]s. Calling
  /// this multiple times for the same space returns the same stream.
  Stream<RealtimeMessageEvent> subscribeToSpace(String spaceId) {
    if (_messageControllers.containsKey(spaceId)) {
      return _messageControllers[spaceId]!.stream;
    }

    final controller = StreamController<RealtimeMessageEvent>.broadcast();
    _messageControllers[spaceId] = controller;

    final channel = _client.channel(
      'chat:$spaceId',
      opts: const RealtimeChannelConfig(private: true),
    );

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'space_id',
            value: spaceId,
          ),
          callback: (PostgresChangePayload payload) {
            final event = RealtimeMessageEvent.fromPostgresPayload(
              payload.newRecord,
            );
            if (!controller.isClosed) {
              controller.add(event);
            }
          },
        )
        .subscribe((RealtimeSubscribeStatus status, Object? error) {
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          if (!_connectionController.isClosed) {
            _connectionController.add(EngineConnectionState.connected);
          }
        case RealtimeSubscribeStatus.channelError:
          if (!_connectionController.isClosed) {
            _connectionController.add(EngineConnectionState.disconnected);
          }
        case RealtimeSubscribeStatus.closed:
          if (!_connectionController.isClosed) {
            _connectionController.add(EngineConnectionState.disconnected);
          }
        case RealtimeSubscribeStatus.timedOut:
          if (!_connectionController.isClosed) {
            _connectionController.add(EngineConnectionState.connecting);
          }
      }
    });

    _messageChannels[spaceId] = channel;
    return controller.stream;
  }

  /// Subscribes to Sender Key recovery requests for [spaceId].
  ///
  /// Only events not originating from [myUserId] are emitted to avoid
  /// processing our own broadcasts.
  Stream<SKRecoveryRequest> subscribeToSKRecovery(
    String spaceId,
    String myUserId,
  ) {
    if (_skControllers.containsKey(spaceId)) {
      return _skControllers[spaceId]!.stream;
    }

    final controller = StreamController<SKRecoveryRequest>.broadcast();
    _skControllers[spaceId] = controller;

    final channel = _client.channel(
      'sk-recovery:$spaceId',
      opts: const RealtimeChannelConfig(private: true),
    );

    channel
        .onBroadcast(
          event: 'sk_request',
          callback: (Map<String, dynamic> payload) {
            final request = SKRecoveryRequest.fromBroadcastPayload(payload);
            // Ignore our own broadcasts.
            if (request.requesterId != myUserId && !controller.isClosed) {
              controller.add(request);
            }
          },
        )
        .subscribe();

    _skChannels[spaceId] = channel;
    return controller.stream;
  }

  /// Broadcasts a Sender Key recovery request to all peers in [spaceId].
  Future<void> broadcastSKRequest({
    required String spaceId,
    required String requesterId,
    required int requesterDeviceId,
    required String targetSenderId,
  }) async {
    final channelName = 'sk-recovery:$spaceId';

    // Reuse existing channel or create a temporary one.
    var channel = _skChannels[spaceId];
    final isTemp = channel == null;

    if (isTemp) {
      channel = _client.channel(
        channelName,
        opts: const RealtimeChannelConfig(private: true),
      );
      // We must subscribe before we can send.
      final completer = Completer<void>();
      channel.subscribe((status, _) {
        if (status == RealtimeSubscribeStatus.subscribed &&
            !completer.isCompleted) {
          completer.complete();
        }
      });
      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );
    }

    await channel.sendBroadcastMessage(
      event: 'sk_request',
      payload: SKRecoveryRequest(
        requesterId: requesterId,
        requesterDeviceId: requesterDeviceId,
        targetSenderId: targetSenderId,
        spaceId: spaceId,
      ).toBroadcastPayload(),
    );

    if (isTemp) {
      await channel.unsubscribe();
    }
  }

  /// Unsubscribes from both message and SK-recovery channels for [spaceId].
  Future<void> unsubscribeFromSpace(String spaceId) async {
    final msgChannel = _messageChannels.remove(spaceId);
    if (msgChannel != null) {
      await msgChannel.unsubscribe();
    }
    await _messageControllers.remove(spaceId)?.close();

    final skChannel = _skChannels.remove(spaceId);
    if (skChannel != null) {
      await skChannel.unsubscribe();
    }
    await _skControllers.remove(spaceId)?.close();
  }

  /// Unsubscribes from all active channels.
  Future<void> unsubscribeAll() async {
    final spaceIds = <String>{
      ..._messageChannels.keys,
      ..._skChannels.keys,
    };
    for (final spaceId in spaceIds) {
      await unsubscribeFromSpace(spaceId);
    }
  }

  /// Releases all resources.
  Future<void> dispose() async {
    await unsubscribeAll();
    await _connectionController.close();
  }
}
