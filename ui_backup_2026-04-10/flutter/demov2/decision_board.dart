import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../main.dart';
import '../theme.dart';
import 'group_summary_card.dart';
import 'swim_lane_rail.dart';
import '../providers/decrypted_item_payload.dart';
import '../providers/plans_provider.dart';

/// Category routing table — mirrors React DecisionBoard.tsx.
const _categoryLabels = <String, String>{
  'hotel': 'hotels',
  'hotels': 'hotels',
  'restaurant': 'restaurants',
  'restaurants': 'restaurants',
  'activity': 'things to do',
  'experience': 'experiences',
  'experiences': 'experiences',
  'flight': 'flights',
  'flights': 'flights',
  'dining': 'dining',
  'gifts': 'gifts',
  'decorations': 'decorations',
  'ideas': 'ideas',
};

String _routeCategory(DecryptedItemPayload item) {
  final cat = (item.category ?? 'ideas').toLowerCase();
  return _categoryLabels[cat] ?? cat;
}

class DecisionBoard extends ConsumerWidget {
  final String groupId;

  const DecisionBoard({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(engineProvider);
    final engineDecisions = engine as ChatEngineDecisions;

    final plansAsync = ref.watch(decryptedPlansProvider(groupId));

    return plansAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: HelloColors.accent),
      ),
      error: (e, st) => Center(
        child: Text('Error: $e', style: HelloTypography.hint),
      ),
      data: (allItems) {
        if (allItems.isEmpty) {
          return const Center(
            child: Text('No items yet. Tap + to add one.', style: HelloTypography.hint),
          );
        }

        // Separate locked items
        final lockedItems = allItems.where((i) => i.isLocked).toList();
        final activeItems = allItems.where((i) => !i.isLocked).toList();

        // Group active items by category
        final Map<String, List<DecryptedItemPayload>> grouped = {};
        for (final item in activeItems) {
          final key = _routeCategory(item);
          grouped.putIfAbsent(key, () => []).add(item);
        }

        // Sort each group by weighted score desc, then agreement score desc
        for (final list in grouped.values) {
          list.sort((a, b) {
            final ws = b.weightedScore.compareTo(a.weightedScore);
            if (ws != 0) return ws;
            return b.agreementScore.compareTo(a.agreementScore);
          });
        }

        // Sort groups by total weighted score desc
        final sortedKeys = grouped.keys.toList()
          ..sort((a, b) {
            final totalA = grouped[a]!.fold<double>(0, (s, i) => s + i.weightedScore);
            final totalB = grouped[b]!.fold<double>(0, (s, i) => s + i.weightedScore);
            return totalB.compareTo(totalA);
          });

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary card
              GroupSummaryCard(items: allItems),

              // Locked trophies (collapsed)
              if (lockedItems.isNotEmpty)
                LockedRailSummary(items: lockedItems),

              // Category swim lanes
              for (final key in sortedKeys)
                SwimLaneRail(
                  category: key,
                  items: grouped[key]!,
                  onReact: (item, reaction) {
                    engineDecisions.reactToItem(item.id, reaction);
                  },
                  onLock: (item) {
                    engineDecisions.lockItem(
                      item.id,
                      CommitmentProof(type: 'mock', value: 'booked', submittedBy: 'me'),
                    );
                  },
                ),

              const SizedBox(height: 100), // Bottom padding for FAB
            ],
          ),
        );
      },
    );
  }
}
