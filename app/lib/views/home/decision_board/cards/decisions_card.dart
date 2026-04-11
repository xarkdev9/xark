import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/decisions_provider.dart';
import 'card_header.dart';
import 'decision_row.dart';
import 'empty_state.dart';
import 'see_all_row.dart';

/// Decisions card. Cross-group active decisions via client-side
/// merge. Up to 10 rows + See all N row.
class DecisionsCard extends ConsumerWidget {
  final VoidCallback onHeaderTap;
  final void Function(String decisionId) onRowTap;
  final VoidCallback onEmptyCtaTap;

  const DecisionsCard({
    super.key,
    required this.onHeaderTap,
    required this.onRowTap,
    required this.onEmptyCtaTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decisionsAsync = ref.watch(activeDecisionsProvider);
    final count = decisionsAsync.value?.length ?? 0;

    return Column(
      children: [
        CardHeader(
          title: 'DECISIONS',
          unreadCount: count,
          onTap: onHeaderTap,
        ),
        Expanded(
          child: decisionsAsync.when(
            data: (decisions) {
              if (decisions.isEmpty) {
                return CardEmptyState(
                  kind: EmptyStateKind.decisions,
                  onCtaTap: onEmptyCtaTap,
                );
              }
              return ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount:
                    decisions.length > 10 ? 10 : decisions.length,
                itemBuilder: (context, index) {
                  if (decisions.length > 10 && index == 9) {
                    return SeeAllRow(
                      count: decisions.length,
                      onTap: onHeaderTap,
                    );
                  }
                  return DecisionRow(
                    item: decisions[index],
                    onTap: () => onRowTap(decisions[index].id),
                  );
                },
              );
            },
            loading: () => const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFF6B35),
                ),
              ),
            ),
            error: (_, _) => CardEmptyState(
              kind: EmptyStateKind.decisions,
              onCtaTap: onEmptyCtaTap,
            ),
          ),
        ),
      ],
    );
  }
}
