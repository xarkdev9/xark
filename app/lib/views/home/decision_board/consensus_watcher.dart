import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/playground_provider.dart';
import 'consensus_banner.dart';

/// Wraps the scaffold body and listens for consensus-lock events
/// from the playground provider. When a decision locks (agreement
/// >= 80%), shows a transient top banner via [ConsensusBanner].
class ConsensusWatcher extends ConsumerStatefulWidget {
  final Widget child;
  const ConsensusWatcher({super.key, required this.child});

  @override
  ConsumerState<ConsensusWatcher> createState() => _ConsensusWatcherState();
}

class _ConsensusWatcherState extends ConsumerState<ConsensusWatcher> {
  bool _showBanner = false;
  String _bannerText = 'Consensus Reached';
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    ref.listenManual(playgroundConsensusEventProvider, (_, next) {
      final itemId = next.value;
      if (itemId != null) {
        setState(() {
          _showBanner = true;
          _bannerText = 'Consensus reached!';
        });
        _dismissTimer?.cancel();
        _dismissTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _showBanner = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: widget.child),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          child: ConsensusBanner(
            isVisible: _showBanner,
            text: _bannerText,
          ),
        ),
      ],
    );
  }
}
