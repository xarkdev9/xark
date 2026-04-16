import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/feed_item.dart';
import '../../../../providers/focus_sources_provider.dart';
import '../../../../providers/playground_provider.dart';
import '../../../../services/palette_extractor.dart';
import '../../../../theme.dart';
import '../../../../utils/haptics.dart';
import '../chromatic_atmosphere.dart';
import '../plasma/plasma.dart';

/// Push a full-screen decision detail page via iOS-style route.
void openDecisionPage(BuildContext context, FeedItem item) {
  Navigator.of(context).push(
    CupertinoPageRoute<void>(
      builder: (_) => _DecisionPage(item: item),
    ),
  );
}

class _DecisionPage extends ConsumerStatefulWidget {
  final FeedItem item;
  const _DecisionPage({required this.item});

  @override
  ConsumerState<_DecisionPage> createState() => _DecisionPageState();
}

class _DecisionPageState extends ConsumerState<_DecisionPage> {
  bool _focusPushed = false;
  Animation<double>? _routeAnim;
  String? _pushedSourceId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_focusPushed) return;
    final anim = ModalRoute.of(context)?.animation;
    _routeAnim = anim;
    anim?.addListener(_onRouteTick);
    _focusPushed = true;
    _pushFocusSource();
  }

  Future<void> _pushFocusSource() async {
    final data = _extract();
    final itemId = data.itemId ?? 'unknown';
    final photoUrl = data.photoUrl;
    final ref0 = ContentRef(
      photoPath: photoUrl != null && photoUrl.startsWith('assets/')
          ? photoUrl
          : null,
      photoUrl: photoUrl != null && photoUrl.startsWith('http') ? photoUrl : null,
      kind: 'decision',
    );
    final palette = await PaletteExtractor.resolve(ref0);
    if (!mounted) return;
    final id = 'decision_$itemId';
    _pushedSourceId = id;
    ref.read(focusSourcesProvider.notifier).push(
          FocusSource(
            id: id,
            palette: palette,
            priority: 50,
            routeAnimation: _routeAnim,
          ),
        );
  }

  void _onRouteTick() {
    if (!mounted) return;
    ref.read(focusSourcesProvider.notifier).touch();
  }

  @override
  void dispose() {
    _routeAnim?.removeListener(_onRouteTick);
    if (_pushedSourceId != null) {
      ref.read(focusSourcesProvider.notifier).pop(_pushedSourceId!);
    }
    super.dispose();
  }

  ({
    String title,
    String? subtitle,
    String? photoUrl,
    String? itemId,
    bool isLiveEvent,
  }) _extract() {
    final it = widget.item;
    if (it is DecisionHeroFeedItem) {
      return (
        title: it.title,
        subtitle: it.subtitle,
        photoUrl: it.photoUrl,
        itemId: it.item.id,
        isLiveEvent: it.liveTag == 'LIVE EVENT',
      );
    }
    if (it is DecisionSmallFeedItem) {
      return (
        title: it.title,
        subtitle: it.eyebrow,
        photoUrl: null,
        itemId: it.item.id,
        isLiveEvent: false,
      );
    }
    return (
      title: 'Decision',
      subtitle: null,
      photoUrl: null,
      itemId: null,
      isLiveEvent: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _extract();

    // Get live item from playground provider
    final decisions = ref.watch(playgroundDecisionsProvider);
    final liveItem = data.itemId != null
        ? decisions.where((d) => d.id == data.itemId).firstOrNull
        : null;
    final liveScore = liveItem?.agreementScore ?? 0.0;
    final myVote = liveItem?.reactions['me'];
    final scorePct = (liveScore * 100).round();

    return AtmosphereDensityScope(
      density: AtmosphereDensity.focus,
      child: Scaffold(
      backgroundColor: HelloColors.voidBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with back button and eyebrow
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: HelloColors.inkPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    data.isLiveEvent ? 'LIVE EVENT' : 'DECISION',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1.5,
                      color: data.isLiveEvent
                          ? HelloColors.liveGreen
                          : HelloColors.inkTertiary,
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                children: [
                  // Photo
                  if (data.photoUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: Image.network(
                            data.photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => ColoredBox(
                              color: HelloColors.surfaceDeep,
                            ),
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return ColoredBox(
                                color: HelloColors.surfaceDeep,
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                  // Title
                  Text(
                    data.title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 26,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.3,
                      height: 1.1,
                      color: HelloColors.inkPrimary,
                    ),
                  ),

                  // Subtitle
                  if (data.subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      data.subtitle!,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        color: HelloColors.inkSecondary,
                      ),
                    ),
                  ],

                  // Consensus score
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text(
                        '$scorePct%',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 36,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.5,
                          color: HelloColors.inkPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'consensus',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          color: HelloColors.inkTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  PlasmaProgressBar(
                    value: liveScore.clamp(0.0, 1.0),
                    height: 4,
                  ),

                  // Vote buttons
                  const SizedBox(height: 28),
                  _VoteButton(
                    label: 'Love it',
                    active: myVote == 'love_it',
                    onTap: () {
                      HelloHaptic.tap();
                      if (data.itemId != null) {
                        ref.read(playgroundDecisionsProvider.notifier).vote(data.itemId!, 'love_it', 'me');
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _VoteButton(
                    label: 'Works for me',
                    active: myVote == 'works_for_me',
                    onTap: () {
                      HelloHaptic.tap();
                      if (data.itemId != null) {
                        ref.read(playgroundDecisionsProvider.notifier).vote(data.itemId!, 'works_for_me', 'me');
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _VoteButton(
                    label: 'Not for me',
                    active: myVote == 'not_for_me',
                    onTap: () {
                      HelloHaptic.tap();
                      if (data.itemId != null) {
                        ref.read(playgroundDecisionsProvider.notifier).vote(data.itemId!, 'not_for_me', 'me');
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _VoteButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: active
          ? PlasmaStroke(
              width: 1,
              borderRadius: BorderRadius.circular(12),
              child: PlasmaFill(
                alpha: 0.22,
                borderRadius: BorderRadius.circular(12),
                height: 52,
                child: Center(
                  child: PlasmaTint(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.white, // opaque for srcIn
                      ),
                    ),
                  ),
                ),
              ),
            )
          : Container(
              height: 52,
              decoration: BoxDecoration(
                color: HelloColors.recessed,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: HelloColors.inkPrimary,
                ),
              ),
            ),
    );
  }
}
