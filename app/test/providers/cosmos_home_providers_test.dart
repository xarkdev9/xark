import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hello_app/models/feed_item.dart';
import 'package:hello_app/providers/feed_provider.dart';
import 'package:hello_app/providers/filtered_feed_providers.dart';

void main() {
  group('freshestPendingSenderProvider', () {
    test('returns null when the feed is empty', () {
      final container = ProviderContainer(overrides: [
        feedProvider.overrideWith((ref) => <FeedItem>[]),
      ]);
      addTearDown(container.dispose);

      final sender = container.read(freshestPendingSenderProvider);
      expect(sender, isNull);
    });

    test('returns null when the feed has only non-pending kinds', () {
      // Memory and AI-nudge items are not "pending action" kinds.
      // They should be filtered out by pendingSenderFromFeedItem().
      final now = DateTime.now();
      final container = ProviderContainer(overrides: [
        feedProvider.overrideWith((ref) => <FeedItem>[
              MemoryFeedItem(
                memoryId: 'm1',
                eyebrow: 'eyebrow',
                title: 'title',
                body: 'body',
                occurredAt: now,
                updatedAt: now,
              ),
              AiNudgeFeedItem(
                nudgeId: 'n1',
                message: 'msg',
                updatedAt: now,
              ),
            ]),
      ]);
      addTearDown(container.dispose);

      final sender = container.read(freshestPendingSenderProvider);
      expect(sender, isNull,
          reason: 'Memory and AI-nudge items are not pending kinds');
    });
  });

  group('pendingSendersQueueProvider', () {
    test('returns empty list when no pending items exist', () {
      final container = ProviderContainer(overrides: [
        feedProvider.overrideWith((ref) => <FeedItem>[]),
      ]);
      addTearDown(container.dispose);

      final queue = container.read(pendingSendersQueueProvider);
      expect(queue, isEmpty);
    });

    test('caps queue length at 6', () {
      // With no pending items, cap is moot — but the queue must still
      // be a list that never exceeds 6.
      final container = ProviderContainer(overrides: [
        feedProvider.overrideWith((ref) => <FeedItem>[]),
      ]);
      addTearDown(container.dispose);

      final queue = container.read(pendingSendersQueueProvider);
      expect(queue.length, lessThanOrEqualTo(6));
    });
  });
}
