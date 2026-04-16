import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hello_app/theme.dart';
import 'package:hello_app/views/home/decision_board/plasma/plasma_clock.dart';

class TriageDemoPage extends StatelessWidget {
  const TriageDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PlasmaClock(
      child: Scaffold(
        backgroundColor: HelloColors.voidBg,
        body: const ZStackRolodexDemo(),
      ),
    );
  }
}

enum TriageKind { rsvp, pay, reply, vote, call, none }

class TriagePulse {
  final String title;
  final String subtitle;
  final TriageKind kind;
  final Color ambientColor;
  final dynamic payload;
  const TriagePulse(this.title, this.subtitle, this.kind, this.ambientColor, [this.payload]);
}

class _ZItem {
  final int index;
  final double offset;
  final double distance;
  final TriagePulse pulse;
  _ZItem({required this.index, required this.offset, required this.distance, required this.pulse});
}

class ZStackRolodexDemo extends StatefulWidget {
  const ZStackRolodexDemo({super.key});

  @override
  State<ZStackRolodexDemo> createState() => _ZStackRolodexDemoState();
}

class _ZStackRolodexDemoState extends State<ZStackRolodexDemo> {
  late PageController _verticalController;
  int _currentIndex = 0;

  final List<TriagePulse> _pulses = [
    const TriagePulse('Vote Tokyo', '3 options available', TriageKind.vote, Color(0xFF5E2B66)),
    const TriagePulse('Pay Ram', '\$45.00', TriageKind.pay, Color(0xFFD94B2B)),
    const TriagePulse('RSVP Dinner', 'Tomorrow at 7 PM', TriageKind.rsvp, Color(0xFF104D36), ['CAN\'T MAKE IT', 'IM IN']),
    const TriagePulse('Reply Jake', '2 unread', TriageKind.reply, Color(0xFF263B6E)),
    const TriagePulse('Call Sarah', 'Missed Audio', TriageKind.call, Color(0xFF9E7B1A)),
    const TriagePulse('Sign Lease', 'Due Today', TriageKind.none, Color(0xFF2D2D2D)),
  ];

  @override
  void initState() {
    super.initState();
    _verticalController = PageController(viewportFraction: 1.0); // Invisible scroll physics layer
  }

  @override
  void dispose() {
    _verticalController.dispose();
    super.dispose();
  }

  Widget _buildMockPlansBackground() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      padding: const EdgeInsets.only(top: 100, left: 16, right: 16),
      itemCount: 10,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.flight_takeoff, color: Colors.white.withValues(alpha: 0.2), size: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAtmosphereTint() {
    final activeColor = _pulses[_currentIndex].ambientColor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      color: activeColor.withValues(alpha: 0.35),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(color: Colors.black.withValues(alpha: 0.4)),
      ),
    );
  }

  Widget _buildActionPills(TriagePulse pulse) {
    if (pulse.kind == TriageKind.rsvp) {
      final opts = pulse.payload as List<String>;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildPill(opts[0], false),
          _buildPill(opts[1], true),
        ],
      );
    } else if (pulse.kind == TriageKind.pay) {
      return _buildPill('PAY APPLE PAY', true);
    } else if (pulse.kind == TriageKind.call) {
      return _buildPill('START AUDIO', true);
    } else if (pulse.kind == TriageKind.vote) {
      return _buildPill('VOTE DATES', true);
    } else if (pulse.kind == TriageKind.reply) {
      return _buildPill('DRAFT REPLY', true);
    } else {
      return _buildPill('ACKNOWLEDGE', false);
    }
  }

  Widget _buildPill(String label, bool isPrimary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: isPrimary ? Colors.white : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: HelloText.label.copyWith(
          color: isPrimary ? Colors.black : Colors.white,
          fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMorphCard(_ZItem item) {
    final bool isActive = item.distance < 0.5;

    // Y-Axis Compression Math (Apple Wallet style stack)
    double translationY;
    if (item.offset == 0) {
      translationY = 0;
    } else {
      // Base jump pushes the inactive items out from behind the active 460px card 
      // Then stack them tightly with a 50px gap so 4-5 titles are easily visible
      final double sign = item.offset.sign;
      final double stretch = item.offset.abs();
      translationY = sign * (250 + (stretch * 50)); 
    }

    final double scale = (1 - (item.distance * 0.05)).clamp(0.8, 1.0);
    final double blurSigma = (item.distance * 1.5).clamp(0.0, 3.0); // Little blur
    final double opacity = isActive ? 1.0 : (1 - (item.distance * 0.25)).clamp(0.2, 1.0);

    final transform = Matrix4.identity()
      ..translate(0.0, translationY, 0.0)
      ..scale(scale);

    Widget content;

    if (isActive) {
      // 1. ACTIVE: Tall Vertical Squircle directly honoring instruction
      content = Container(
        width: MediaQuery.of(context).size.width - 48,
        height: 480, // TALL VERTICAL SQUIRCLE
        decoration: BoxDecoration(
           color: item.pulse.ambientColor.withValues(alpha: 0.8),
           borderRadius: BorderRadius.circular(48),
           border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
           boxShadow: [
             BoxShadow(color: item.pulse.ambientColor.withValues(alpha: 0.4), blurRadius: 40, offset: const Offset(0, 15))
           ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(48),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Title
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.pulse.title, style: HelloText.display.copyWith(fontSize: 32, color: Colors.white)),
                      const SizedBox(height: 8),
                      Text(item.pulse.subtitle, style: HelloText.title.copyWith(color: Colors.white.withValues(alpha: 0.7))),
                    ],
                  ),
                  
                  // Rich Icon / Graphic
                  Center(
                    child: Icon(
                      item.pulse.kind == TriageKind.pay ? Icons.apple 
                      : item.pulse.kind == TriageKind.call ? Icons.phone 
                      : Icons.dashboard_customize_outlined,
                      color: Colors.white.withValues(alpha: 0.2),
                      size: 80,
                    ),
                  ),

                  // ANY ACTION IN USER THUMB REACH (Strictly confined to bottom of card)
                  _buildActionPills(item.pulse),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      // 2. INACTIVE: "User should see titles" + little blur
      content = SizedBox(
        width: MediaQuery.of(context).size.width - 48,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              item.pulse.title.toUpperCase(),
              style: HelloText.title.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w400,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (blurSigma > 0.1) {
      content = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: content,
      );
    }

    return Transform(
      alignment: Alignment.center,
      transform: transform,
      child: Opacity(
        opacity: opacity,
        child: content,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: _buildMockPlansBackground()),
        Positioned.fill(child: _buildAtmosphereTint()),

        // Core Render Engine: Z-Stack (Guarantees Active Card is ALWAYS on top)
        Positioned(
          bottom: 120, // Above Plasma Handle
          left: 0,
          right: 0,
          height: 520, // Huge canvas slot
          child: AnimatedBuilder(
            animation: _verticalController,
            builder: (context, _) {
              double page = _currentIndex.toDouble();
              if (_verticalController.position.haveDimensions) {
                page = _verticalController.page!;
              }

              List<_ZItem> items = [];
              for (int i = 0; i < _pulses.length; i++) {
                final double offset = i - page;
                final double distance = offset.abs();
                items.add(_ZItem(index: i, offset: offset, distance: distance, pulse: _pulses[i]));
              }

              // Crucial: Sort by distance descending so the closest item (distance 0) paints LAST (on top)
              items.sort((a, b) => b.distance.compareTo(a.distance));

              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: items.map((item) => _buildMorphCard(item)).toList(),
              );
            },
          ),
        ),

        // Invisible scroll physics layer
        Positioned(
          bottom: 120, left: 0, right: 0, height: 520,
          child: PageView.builder(
            scrollDirection: Axis.vertical,
            controller: _verticalController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (idx) => setState(() => _currentIndex = idx),
            itemCount: _pulses.length,
            itemBuilder: (context, index) => const SizedBox.expand(),
          ),
        ),

        // Plasma Handle Constraint Lock
        Positioned(
          bottom: 0, left: 0, right: 0, height: 96,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            ),
            child: Text('[ Liquid Plasma Handle Zone ]', style: HelloText.caption.copyWith(color: Colors.white.withValues(alpha: 0.3))),
          ),
        ),
      ],
    );
  }
}
