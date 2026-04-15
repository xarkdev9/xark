import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/filtered_feed_providers.dart';
import '../../../../providers/focus_sources_provider.dart';
import '../../../../services/palette_extractor.dart';
import '../../../../theme.dart';
import '../chromatic_atmosphere.dart';
import 'home/action_words_row.dart';
import 'home/context_label.dart';
import 'home/cosmos_sender_model.dart';
import 'home/foreground_avatar.dart';
import 'home/queue_row.dart';

/// Cosmos Home — floating avatar surface.
///
/// Ambient state: atmosphere + foreground avatar + context label +
/// queue row (or "all caught up" empty state).
///
/// Expanded state: tap any avatar (foreground or queue) → queue +
/// label cross-fade out (180ms), full message text + ActionWordsRow
/// cross-fade in. Tap-outside dismisses. All in-place — NO route push.
///
/// Action taps in this task STUB to dismissal. Task 19 replaces the
/// stubs with the 1700ms reward sequence (levitation + plasma
/// infusion + atmosphere pulse + ascent + handoff) + 500ms delay
/// before the Expanded collapse so the ActionWord's plasma sweep
/// completes visibly.
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
  /// state-dispose ordering.
  FocusSourceStack? _focusStack;
  String? _pushedSourceId;

  /// The sender whose action surface is currently expanded in-place.
  /// Null = Ambient state (queue + context label visible).
  PendingSender? _focusedSender;

  /// Controller for the open-DM reply field (only populated when the
  /// focused sender has MessageKind.openText).
  final TextEditingController _replyController = TextEditingController();

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
    _replyController.dispose();
    super.dispose();
  }

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
    if (_pushedSourceId == id) return;

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

  void _onAvatarTap(PendingSender sender) {
    setState(() {
      _focusedSender = sender;
      _replyController.clear();
    });
  }

  void _dismissExpansion() {
    setState(() {
      _focusedSender = null;
      _replyController.clear();
    });
  }

  /// STUB — Task 19 replaces with reward-sequence firing + 500ms delay.
  void _onActionTap(String word) {
    _dismissExpansion();
  }

  /// STUB — Task 19 replaces with engine call + reward sequence.
  void _onReplySubmit() {
    _dismissExpansion();
  }

  /// Full message text shown in the Expanded state (where the
  /// context label was). For now uses the sender's subject. Task 19's
  /// Great Wiring fetches the real recent inbound for DMs.
  String _expandedMessageText(PendingSender sender) {
    return sender.subject.isEmpty ? '(no message content)' : sender.subject;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final foreground = ref.watch(freshestPendingSenderProvider);
    final queue = ref.watch(pendingSendersQueueProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncForegroundPalette(_focusedSender ?? foreground);
    });

    // Empty state: no pending items at all.
    if (foreground == null && queue.isEmpty && _focusedSender == null) {
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

    final isExpanded = _focusedSender != null;
    final displayedSender = _focusedSender ?? foreground;

    return AtmosphereDensityScope(
      density: AtmosphereDensity.focus,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;

          return Stack(
            children: [
              // Dismiss layer — always rendered, gated by IgnorePointer
              // (landmine #9: never use `if (cond) Positioned(...)` inside
              // a Stack with gesture recognizers; toggle hit behavior
              // instead of mounting/unmounting).
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !isExpanded,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _dismissExpansion,
                  ),
                ),
              ),

              // Foreground avatar — always rendered when a sender exists.
              if (displayedSender != null)
                Positioned(
                  top: h * 0.18,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ForegroundAvatar(
                      sender: displayedSender,
                      onTap: isExpanded
                          ? null
                          : () => _onAvatarTap(displayedSender),
                    ),
                  ),
                ),

              // Ambient layer — context label + queue row.
              // Cross-fades OUT (180ms) when _focusedSender is set.
              AnimatedOpacity(
                opacity: isExpanded ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: isExpanded,
                  child: Stack(
                    children: [
                      if (foreground != null)
                        Positioned(
                          top: h * 0.18 + 140 + 12,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: ContextLabel(sender: foreground),
                          ),
                        ),
                      Positioned(
                        top: h * 0.18 + 140 + 12 + 20 + 32,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: QueueRow(
                            senders: queue,
                            onTap: _onAvatarTap,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Expanded layer — full message text + action words row.
              // Cross-fades IN (180ms) when _focusedSender is set.
              AnimatedOpacity(
                opacity: isExpanded ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: !isExpanded,
                  child: displayedSender == null || !isExpanded
                      ? const SizedBox.shrink()
                      : Stack(
                          children: [
                            // Full message text — where the context
                            // label was.
                            Positioned(
                              top: h * 0.18 + 140 + 12,
                              left: 24,
                              right: 24,
                              child: Text(
                                _expandedMessageText(displayedSender),
                                textAlign: TextAlign.center,
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                  color: HelloColors.inkPrimary,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            // Action words row — where the queue row was.
                            Positioned(
                              top: h * 0.18 + 140 + 12 + 130 + 32,
                              left: 32,
                              right: 32,
                              child: ActionWordsRow(
                                kind: displayedSender.messageKind,
                                onAction: _onActionTap,
                                replyController: _replyController,
                                onReplySubmit: _onReplySubmit,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
