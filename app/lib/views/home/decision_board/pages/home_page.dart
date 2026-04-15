import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/filtered_feed_providers.dart';
import '../../../../providers/focus_sources_provider.dart';
import '../../../../services/palette_extractor.dart';
import '../../../../theme.dart';
import '../chromatic_atmosphere.dart';
import 'home/context_label.dart';
import 'home/cosmos_sender_model.dart';
import 'home/foreground_avatar.dart';
import 'home/queue_row.dart';

/// Cosmos Home — floating avatar surface.
///
/// Ambient state: atmosphere + foreground avatar + context label +
/// queue row (or "all caught up" empty state). Tapping an avatar
/// will open the Expanded state in Phase 5 (Task 15); this task
/// only builds the Ambient layer.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  /// Captured at initState to survive Riverpod 3's dispose-before-
  /// state-dispose ordering (see root CLAUDE.md landmine #12 ancestry).
  FocusSourceStack? _focusStack;
  String? _pushedSourceId;

  @override
  void initState() {
    super.initState();
    _focusStack = ref.read(focusSourcesProvider.notifier);
  }

  @override
  void dispose() {
    if (_pushedSourceId != null) {
      _focusStack?.pop(_pushedSourceId!);
    }
    super.dispose();
  }

  /// Push the foreground sender's signature palette into the focus
  /// source stack at priority 20 (above tab fallback 10, below
  /// detail-route 50 — per spec).
  Future<void> _syncForegroundPalette(PendingSender? sender) async {
    final stack = _focusStack;
    if (stack == null) return;

    if (sender == null) {
      if (_pushedSourceId != null) {
        stack.pop(_pushedSourceId!);
        _pushedSourceId = null;
      }
      return;
    }

    final id = 'home_fg_${sender.id}';
    if (_pushedSourceId == id) return; // unchanged

    final palette = await PaletteExtractor.resolve(
      ContentRef(signatureId: sender.name, kind: 'dm'),
    );
    if (!mounted) return;
    if (_pushedSourceId != null && _pushedSourceId != id) {
      stack.pop(_pushedSourceId!);
    }
    stack.push(FocusSource(
      id: id,
      palette: palette,
      priority: 20,
    ));
    _pushedSourceId = id;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final foreground = ref.watch(freshestPendingSenderProvider);
    final queue = ref.watch(pendingSendersQueueProvider);

    // Side-effect: keep the focus stack in sync with the foreground
    // sender. Uses post-frame to avoid ref writes during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncForegroundPalette(foreground);
    });

    // Empty state: no pending items at all.
    if (foreground == null && queue.isEmpty) {
      return AtmosphereDensityScope(
        density: AtmosphereDensity.focus,
        child: Center(
          child: Text(
            'all caught up',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: HelloColors.inkTertiary,
            ),
          ),
        ),
      );
    }

    return AtmosphereDensityScope(
      density: AtmosphereDensity.focus,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;

          return Stack(
            children: [
              // Foreground avatar — upper-third, centered
              if (foreground != null)
                Positioned(
                  top: h * 0.18,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ForegroundAvatar(sender: foreground),
                  ),
                ),

              // Context label — 12pt below foreground (~140 + 12 from anchor)
              if (foreground != null)
                Positioned(
                  top: h * 0.18 + 140 + 12,
                  left: 0,
                  right: 0,
                  child: Center(child: ContextLabel(sender: foreground)),
                ),

              // Queue row — 32pt below context label (~14pt label text + 32 gap)
              Positioned(
                top: h * 0.18 + 140 + 12 + 20 + 32,
                left: 0,
                right: 0,
                child: Center(child: QueueRow(senders: queue)),
              ),
            ],
          );
        },
      ),
    );
  }
}
