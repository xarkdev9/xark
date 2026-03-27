// ignore_for_file: prefer_const_constructors

import 'dart:async';

import 'package:hello_engine/src/domain/models/connection_state.dart';
import 'package:hello_engine/src/transport/dto/realtime_event.dart';
import 'package:hello_engine/src/transport/realtime_listener.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show
        SupabaseClient,
        RealtimeChannel,
        RealtimeChannelConfig,
        RealtimeSubscribeStatus,
        PostgresChangeEvent,
        PostgresChangeFilter,
        PostgresChangeFilterType,
        PostgresChangePayload;

void main() {
  // -------------------------------------------------------------------------
  // RealtimeMessageEvent parsing
  // -------------------------------------------------------------------------
  group('RealtimeMessageEvent.fromPostgresPayload', () {
    test('parses a complete E2EE message record', () {
      final record = <String, dynamic>{
        'id': 'msg-001',
        'group_id': 'space-travel',
        'user_id': 'name_alice',
        'sender_device_id': 1,
        'message_type': 'e2ee',
        'created_at': '2026-03-26T14:30:00.000Z',
      };

      final event = RealtimeMessageEvent.fromPostgresPayload(record);

      expect(event.messageId, 'msg-001');
      expect(event.groupId, 'space-travel');
      expect(event.senderId, 'name_alice');
      expect(event.senderDeviceId, 1);
      expect(event.messageType, 'e2ee');
      expect(event.createdAt, DateTime.utc(2026, 3, 26, 14, 30));
    });

    test('handles sender_key_dist message type', () {
      final record = <String, dynamic>{
        'id': 'sk-dist-1',
        'group_id': 'group-1',
        'user_id': 'name_bob',
        'sender_device_id': 2,
        'message_type': 'sender_key_dist',
        'created_at': '2026-03-26T10:00:00.000Z',
      };

      final event = RealtimeMessageEvent.fromPostgresPayload(record);

      expect(event.messageType, 'sender_key_dist');
      expect(event.senderId, 'name_bob');
    });

    test('handles null sender_device_id (system messages)', () {
      final record = <String, dynamic>{
        'id': 'sys-1',
        'group_id': 'space-abc',
        'user_id': 'system',
        'sender_device_id': null,
        'message_type': 'system',
        'created_at': '2026-01-01T00:00:00.000Z',
      };

      final event = RealtimeMessageEvent.fromPostgresPayload(record);

      expect(event.senderDeviceId, isNull);
      expect(event.messageType, 'system');
    });

    test('defaults message_type to e2ee when absent', () {
      final record = <String, dynamic>{
        'id': 'msg-2',
        'group_id': 'sp',
        'user_id': 'name_carol',
        'created_at': '2026-06-15T12:00:00.000Z',
      };

      final event = RealtimeMessageEvent.fromPostgresPayload(record);
      expect(event.messageType, 'e2ee');
    });

    test('parses hello AI assistant messages', () {
      final record = <String, dynamic>{
        'id': 'hello-msg-1',
        'group_id': 'space-trip',
        'user_id': 'name_hello',
        'sender_device_id': null,
        'message_type': 'hello',
        'created_at': '2026-03-26T15:00:00.000Z',
      };

      final event = RealtimeMessageEvent.fromPostgresPayload(record);

      expect(event.messageType, 'hello');
      expect(event.senderId, 'name_hello');
      expect(event.senderDeviceId, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // SKRecoveryRequest parsing
  // -------------------------------------------------------------------------
  group('SKRecoveryRequest', () {
    test('parses from broadcast payload with snake_case keys', () {
      final payload = <String, dynamic>{
        'requester_id': 'name_bob',
        'requester_device_id': 2,
        'target_sender_id': 'name_alice',
        'group_id': 'group-xyz',
      };

      final request = SKRecoveryRequest.fromBroadcastPayload(payload);

      expect(request.requesterId, 'name_bob');
      expect(request.requesterDeviceId, 2);
      expect(request.targetSenderId, 'name_alice');
      expect(request.groupId, 'group-xyz');
    });

    test('round-trips through toBroadcastPayload', () {
      final original = SKRecoveryRequest(
        requesterId: 'name_carol',
        requesterDeviceId: 3,
        targetSenderId: 'name_dave',
        groupId: 'grp-1',
      );

      final payload = original.toBroadcastPayload();
      final restored = SKRecoveryRequest.fromBroadcastPayload(payload);

      expect(restored.requesterId, original.requesterId);
      expect(restored.requesterDeviceId, original.requesterDeviceId);
      expect(restored.targetSenderId, original.targetSenderId);
      expect(restored.groupId, original.groupId);
    });

    test('toBroadcastPayload produces all required snake_case keys', () {
      final request = SKRecoveryRequest(
        requesterId: 'u1',
        requesterDeviceId: 1,
        targetSenderId: 'u2',
        groupId: 's1',
      );

      final payload = request.toBroadcastPayload();

      // These exact keys must match what the React app expects
      expect(payload, containsPair('requester_id', 'u1'));
      expect(payload, containsPair('requester_device_id', 1));
      expect(payload, containsPair('target_sender_id', 'u2'));
      expect(payload, containsPair('group_id', 's1'));
      expect(payload.length, 4); // No extra keys
    });
  });

  // -------------------------------------------------------------------------
  // RealtimeListener lifecycle (unit tests without real Supabase)
  // -------------------------------------------------------------------------
  group('RealtimeListener lifecycle', () {
    test('subscribeToSpace does not create duplicate channels', () async {
      final client = _FakeSupabaseClientWithChannels();
      final listener = RealtimeListener(client: client);

      // Both calls should succeed without error — the listener dedup
      // logic prevents creating multiple subscriptions for the same space.
      final stream1 = listener.subscribeToSpace('space-1');
      final stream2 = listener.subscribeToSpace('space-1');

      // Both are non-null broadcast streams for the same space.
      expect(stream1, isA<Stream<RealtimeMessageEvent>>());
      expect(stream2, isA<Stream<RealtimeMessageEvent>>());

      // Only 1 channel should have been created (the second call reuses).
      expect(client.channelCallCount('chat:space-1'), 1);

      await listener.dispose();
    });

    test('subscribeToSpace creates separate channels for different spaces',
        () async {
      final client = _FakeSupabaseClientWithChannels();
      final listener = RealtimeListener(client: client);

      listener.subscribeToSpace('space-1');
      listener.subscribeToSpace('space-2');

      expect(client.channelCallCount('chat:space-1'), 1);
      expect(client.channelCallCount('chat:space-2'), 1);

      await listener.dispose();
    });

    test('subscribeToSKRecovery does not create duplicate channels', () async {
      final client = _FakeSupabaseClientWithChannels();
      final listener = RealtimeListener(client: client);

      final stream1 = listener.subscribeToSKRecovery('space-1', 'me');
      final stream2 = listener.subscribeToSKRecovery('space-1', 'me');

      expect(stream1, isA<Stream<SKRecoveryRequest>>());
      expect(stream2, isA<Stream<SKRecoveryRequest>>());
      expect(client.channelCallCount('sk-recovery:space-1'), 1);

      await listener.dispose();
    });

    test('connectionState stream emits', () async {
      final client = _FakeSupabaseClientWithChannels();
      final listener = RealtimeListener(client: client);

      // connectionState is a broadcast stream; just verify it's accessible
      expect(listener.connectionState, isA<Stream<EngineConnectionState>>());

      await listener.dispose();
    });
  });
}

/// Minimal fake SupabaseClient that returns stub RealtimeChannels
/// and tracks how many times each channel name was requested.
class _FakeSupabaseClientWithChannels implements SupabaseClient {
  final _channels = <String, _FakeRealtimeChannel>{};
  final _callCounts = <String, int>{};

  int channelCallCount(String name) => _callCounts[name] ?? 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #channel) {
      final name = invocation.positionalArguments.first as String;
      _callCounts[name] = (_callCounts[name] ?? 0) + 1;
      return _channels.putIfAbsent(name, _FakeRealtimeChannel.new);
    }
    return null;
  }
}

/// Minimal fake RealtimeChannel that accepts subscriptions without
/// connecting to a real server. Uses noSuchMethod for all methods
/// to avoid signature mismatches with the actual Supabase SDK.
class _FakeRealtimeChannel implements RealtimeChannel {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    // For methods that return RealtimeChannel (chaining), return this.
    if (invocation.memberName == #onPostgresChanges ||
        invocation.memberName == #onBroadcast ||
        invocation.memberName == #subscribe) {
      // subscribe callback: immediately fire subscribed
      if (invocation.memberName == #subscribe &&
          invocation.positionalArguments.isNotEmpty) {
        final cb = invocation.positionalArguments.first;
        if (cb is Function) {
          cb(RealtimeSubscribeStatus.subscribed, null);
        }
      }
      return this;
    }
    // For unsubscribe (returns Future<String>)
    if (invocation.memberName == #unsubscribe) {
      return Future<String>.value('ok');
    }
    return null;
  }
}
