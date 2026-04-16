import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/playground_provider.dart';
import '../../../utils/haptics.dart';
import 'consensus_banner.dart';

/// Wraps the decision board scaffold and listens for consensus events.
///
/// When a playground item crosses 80% agreement (and transitions to `locked`),
/// this widget fires haptic feedback and shows a [ConsensusBanner] overlay
/// that auto-dismisses after 3 seconds.
class ConsensusWatcher extends ConsumerStatefulWidget {
  final Widget child;

  const ConsensusWatcher({super.key, required this.child});

  @override
  ConsumerState<ConsensusWatcher> createState() => _ConsensusWatcherState();
}

class _ConsensusWatcherState extends ConsumerState<ConsensusWatcher> {
  bool _bannerVisible = false;
  String _bannerText = 'Consensus Reached';
  Timer? _dismissTimer;
  ProviderSubscription<AsyncValue<String>>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual<AsyncValue<String>>(
      playgroundConsensusEventProvider,
      (previous, next) {
        next.whenData((itemId) {
          if (!mounted) return;

          // Look up the item title from the provider
          final items = ref.read(playgroundDecisionsProvider);
          final item = items.where((i) => i.id == itemId).firstOrNull;
          final title = item?.ciphertextPayload ?? 'Item';
          // For playground items, ciphertextPayload holds the display title.
          // If it's 'mock', fall back to the item id.
          final displayTitle =
              (title == 'mock' || title.isEmpty) ? itemId : title;

          HelloHaptic.celebrate();

          _dismissTimer?.cancel();
          setState(() {
            _bannerVisible = true;
            _bannerText = '$displayTitle — Locked';
          });

          _dismissTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() => _bannerVisible = false);
            }
          });
        });
      },
    );
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        // Always render Positioned even when banner hidden (landmine #9)
        Positioned.fill(child: widget.child),
        Positioned(
          top: topPadding + 12,
          left: 0,
          right: 0,
          child: Center(
            child: ConsensusBanner(
              isVisible: _bannerVisible,
              text: _bannerText,
            ),
          ),
        ),
      ],
    );
  }
}
