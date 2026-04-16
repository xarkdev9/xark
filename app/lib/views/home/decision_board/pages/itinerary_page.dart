import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/feed_item.dart';
import '../../../../providers/focus_sources_provider.dart';
import '../../../../services/palette_extractor.dart';
import '../../../../theme.dart';
import '../chromatic_atmosphere.dart';

/// Opens a full-screen itinerary detail page via a Cupertino push transition.
void openItineraryPage(BuildContext context, FeedItem item) {
  if (item is! ItineraryFeedItem) return;
  Navigator.of(context).push(
    CupertinoPageRoute(
      builder: (_) => _ItineraryPage(item: item),
    ),
  );
}

class _ItineraryPage extends ConsumerStatefulWidget {
  final ItineraryFeedItem item;
  const _ItineraryPage({required this.item});

  @override
  ConsumerState<_ItineraryPage> createState() => _ItineraryPageState();
}

class _ItineraryPageState extends ConsumerState<_ItineraryPage> {
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
    final palette = await PaletteExtractor.resolve(
      const ContentRef(kind: 'itinerary'),
    );
    if (!mounted) return;
    _focusStack?.push(
      FocusSource(
        id: 'itinerary_${widget.item.event.id}',
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
    _focusStack?.pop('itinerary_${widget.item.event.id}');
    super.dispose();
  }

  IconData _iconForTitle(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('flight') || lower.contains('fly')) {
      return Icons.flight_rounded;
    }
    if (lower.contains('hotel') || lower.contains('stay') || lower.contains('check')) {
      return Icons.hotel_rounded;
    }
    return Icons.flag_rounded;
  }

  String _formatDateTime(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final amPm = dt.hour < 12 ? 'AM' : 'PM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $hour:$minute $amPm';
  }

  _BlockStatus _statusForDate(DateTime dt) {
    return dt.isBefore(DateTime.now()) ? _BlockStatus.booked : _BlockStatus.pending;
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.item.event;
    return AtmosphereDensityScope(
      density: AtmosphereDensity.focus,
      child: Scaffold(
      backgroundColor: HelloColors.voidBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: HelloColors.inkPrimary),
        title: Text(
          event.title,
          style: HelloText.body.copyWith(letterSpacing: -0.2),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Location header
            Row(
              children: [
                Icon(Icons.place_outlined, size: 16, color: HelloColors.inkSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    event.location,
                    style: HelloText.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${event.memberIds.length} attending',
              style: HelloText.label,
            ),
            const SizedBox(height: 28),

            // Itinerary blocks — synthesized from the event data.
            // The ItineraryEvent model carries a single event; we display
            // it as the primary block and add placeholder blocks to show
            // the page layout for when richer data is available.
            _ItineraryBlock(
              icon: _iconForTitle(event.title),
              title: event.title,
              timeText: _formatDateTime(event.startsAt),
              status: _statusForDate(event.startsAt),
            ),
            const SizedBox(height: 12),
            _ItineraryBlock(
              icon: Icons.hotel_rounded,
              title: 'Accommodation',
              timeText: 'Check-in TBD',
              status: _BlockStatus.pending,
            ),
            const SizedBox(height: 12),
            _ItineraryBlock(
              icon: Icons.flag_rounded,
              title: 'Activity',
              timeText: 'Details pending',
              status: _BlockStatus.pending,
            ),
          ],
        ),
      ),
      ),
    );
  }
}

enum _BlockStatus { booked, pending }

class _ItineraryBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String timeText;
  final _BlockStatus status;

  const _ItineraryBlock({
    required this.icon,
    required this.title,
    required this.timeText,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HelloColors.surfaceDeep,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: HelloColors.recessed,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: HelloColors.inkSecondary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: HelloText.body.copyWith(height: 1.2)),
                const SizedBox(height: 4),
                Text(timeText, style: HelloText.caption),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _StatusIndicator(status: status),
        ],
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final _BlockStatus status;
  const _StatusIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case _BlockStatus.booked:
        return Icon(
          Icons.check_circle_rounded,
          size: 20,
          color: HelloColors.liveGreen,
        );
      case _BlockStatus.pending:
        return Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: HelloColors.scoreLow,
            shape: BoxShape.circle,
          ),
        );
    }
  }
}
