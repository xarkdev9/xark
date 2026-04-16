import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/feed_item.dart';
import '../../../../models/trip.dart';
import '../../../../providers/focus_sources_provider.dart';
import '../../../../services/palette_extractor.dart';
import '../../../../theme.dart';
import '../../../../utils/haptics.dart';
import '../chromatic_atmosphere.dart';
import '../plasma/plasma.dart';

/// Push a full-screen trip detail page via iOS-style route.
void openTripPage(BuildContext context, FeedItem item) {
  final Trip trip;
  if (item is TripFeedItem) {
    trip = item.trip;
  } else if (item is FocusHeroFeedItem) {
    trip = item.trip;
  } else {
    return;
  }
  Navigator.of(context).push(
    CupertinoPageRoute<void>(
      builder: (_) => _TripPage(trip: trip),
    ),
  );
}

class _TripPage extends ConsumerStatefulWidget {
  final Trip trip;
  const _TripPage({required this.trip});

  @override
  ConsumerState<_TripPage> createState() => _TripPageState();
}

class _TripPageState extends ConsumerState<_TripPage> {
  Trip get trip => widget.trip;

  bool _focusPushed = false;
  Animation<double>? _routeAnim;
  // Captured at initState; used in dispose() because Riverpod 3 disposes
  // the ref before State.dispose() runs.
  FocusSourceStack? _focusStack;

  @override
  void initState() {
    super.initState();
    _focusStack = ref.read(focusSourcesProvider.notifier);
  }

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
    final photoUrl = trip.photoUrl;
    final palette = await PaletteExtractor.resolve(
      ContentRef(
        photoPath: photoUrl.startsWith('assets/') ? photoUrl : null,
        photoUrl: photoUrl.startsWith('http') ? photoUrl : null,
        kind: 'trip',
      ),
    );
    if (!mounted) return;
    _focusStack?.push(
      FocusSource(
        id: 'trip_${trip.id}',
        palette: palette,
        priority: 50,
        routeAnimation: _routeAnim,
      ),
    );
  }

  void _onRouteTick() {
    if (!mounted) return;
    _focusStack?.touch();
  }

  @override
  void dispose() {
    _routeAnim?.removeListener(_onRouteTick);
    _focusStack?.pop('trip_${trip.id}');
    super.dispose();
  }

  String _dateRange() {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final s = trip.startDate;
    final e = trip.endDate;
    return '${months[s.month - 1]} ${s.day} \u2013 ${months[e.month - 1]} ${e.day}';
  }

  int _daysUntil() {
    return trip.startDate.difference(DateTime.now()).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final days = _daysUntil();

    return AtmosphereDensityScope(
      density: AtmosphereDensity.focus,
      child: Scaffold(
      backgroundColor: HelloColors.voidBg,
      body: Column(
        children: [
          // Hero photo
          SizedBox(
            height: 280,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  trip.photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => ColoredBox(
                    color: trip.accentColor.withValues(alpha: 0.3),
                  ),
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return ColoredBox(
                      color: trip.accentColor.withValues(alpha: 0.3),
                    );
                  },
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x44000000), Colors.transparent],
                      stops: [0.0, 0.4],
                    ),
                  ),
                ),
                // Back button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 8,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Trip details
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 40),
              children: [
                // Phase badge
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: trip.accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      trip.phase.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1.5,
                        color: trip.accentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Destination
                Text(
                  trip.destination,
                  style: HelloText.title,
                ),
                const SizedBox(height: 6),

                // Date range
                Text(
                  _dateRange(),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    color: HelloColors.inkSecondary,
                  ),
                ),
                const SizedBox(height: 20),

                // Stats row
                Row(
                  children: [
                    if (days > 0) ...[
                      _Stat(
                        value: '$days',
                        label: days == 1 ? 'day away' : 'days away',
                      ),
                      const SizedBox(width: 24),
                    ],
                    _Stat(
                      value: '${trip.memberIds.length}',
                      label: trip.memberIds.length == 1 ? 'member' : 'members',
                    ),
                    if (trip.pendingDecisionCount > 0) ...[
                      const SizedBox(width: 24),
                      _Stat(
                        value: '${trip.pendingDecisionCount}',
                        label: 'pending',
                        usePlasma: true,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 32),

                // Enter Plans CTA
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HelloHaptic.tap();
                    // Placeholder — navigates to Plans tab or trip planner in future
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Plans view — coming soon',
                          style: HelloText.body.copyWith(
                            color: HelloColors.inkPrimary,
                          ),
                        ),
                        backgroundColor: HelloColors.recessed,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: PlasmaFill(
                    borderRadius: BorderRadius.circular(14),
                    height: 56,
                    child: const Center(
                      child: Text(
                        'Enter Plans',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 2.5,
                          color: Color(0xFFF0EFF4),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final bool usePlasma;
  const _Stat({
    required this.value,
    required this.label,
    this.usePlasma = false,
  });

  @override
  Widget build(BuildContext context) {
    final valueWidget = Text(
      value,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 28,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.5,
        height: 1,
        color: HelloColors.inkPrimary,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        usePlasma ? PlasmaTint(child: valueWidget) : valueWidget,
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w300,
            color: HelloColors.inkTertiary,
          ),
        ),
      ],
    );
  }
}
