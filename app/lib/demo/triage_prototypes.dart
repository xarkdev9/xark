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

class TriageOption {
  final String title;
  final String subtitle;
  final Color ambientColor;
  const TriageOption({required this.title, required this.subtitle, required this.ambientColor});
}

class TriagePulse {
  final String title;
  final String subtitle;
  final TriageKind kind;
  final Color ambientColor;
  final List<TriageOption> options;
  final dynamic payload;
  const TriagePulse(this.title, this.subtitle, this.kind, this.ambientColor, {this.options = const [], this.payload});
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
    TriagePulse('Vote Tokyo', '3 options available', TriageKind.vote, const Color(0xFF5E2B66), options: [
      TriageOption(title: 'Option A: Nov 14', subtitle: 'Cherry Blossoms • \$400', ambientColor: Colors.purple.shade700),
      TriageOption(title: 'Option B: Dec 2', subtitle: 'Winter Festival • \$450', ambientColor: Colors.pink.shade800),
      TriageOption(title: 'Option C: Jan 10', subtitle: 'New Years • \$500', ambientColor: Colors.indigo.shade900),
    ]),
    const TriagePulse('Pay Ram', '\$45.00', TriageKind.pay, Color(0xFFD94B2B)),
    const TriagePulse('RSVP Dinner', 'Tomorrow at 7 PM', TriageKind.rsvp, Color(0xFF104D36), payload: ['CAN\'T MAKE IT', 'IM IN']),
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

  // ... (TriageOption definitions are inserted above the state class) ...

  Widget _buildMorphCard(_ZItem item) {
    double translationY;
    if (item.offset == 0) {
      translationY = 0; 
    } else if (item.offset > 0) {
      translationY = -(item.offset * 64); 
    } else {
      translationY = item.distance * 520;
    }

    final double scale = (1 - (item.distance * 0.04)).clamp(0.85, 1.0);
    final double opacity = item.distance < 0.2 ? 1.0 : (1 - (item.distance * 0.15)).clamp(0.4, 1.0);

    final transform = Matrix4.identity()
      ..translate(0.0, translationY, 0.0)
      ..scale(scale);

    // Unified Outer Shell (Never breaks, prevents vertical 'hairline' bleeding)
    Widget content = Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: MediaQuery.of(context).size.width - 72,
        height: 380,
        decoration: BoxDecoration(
           color: item.pulse.ambientColor.withValues(alpha: 0.95), 
           borderRadius: BorderRadius.circular(44),
           border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
           boxShadow: [
             BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, -15))
           ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(44),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // STATIC TOP HEADER (Always Contextually Locked)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.2)),
                        alignment: Alignment.center,
                        child: Text(item.pulse.title.isNotEmpty ? item.pulse.title[0] : 'U', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.pulse.title, 
                              style: HelloText.title.copyWith(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w600, height: 1.2), 
                              maxLines: 2, 
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Opacity(
                              opacity: 0.75,
                              child: Text(
                                item.pulse.subtitle, 
                                style: HelloText.caption.copyWith(color: Colors.white, fontSize: 13), 
                                maxLines: 1, 
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  // INTERNAL DYNAMIC PAYLOAD
                  Expanded(
                    child: Opacity(
                      opacity: (1 - (item.distance * 1.5)).clamp(0.0, 1.0),
                      child: item.pulse.options.isNotEmpty
                          // MULTI-OPTION NESTED RAIL (Card inside Card)
                          ? LayoutBuilder(
                              builder: (context, constraints) {
                                return PageView.builder(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  // Slight peek visibility of next option to indicate scrollability natively
                                  controller: PageController(viewportFraction: 0.88),
                                  padEnds: false, // Start flush left
                                  itemCount: item.pulse.options.length,
                                  itemBuilder: (context, idx) {
                                    final opt = item.pulse.options[idx];
                                    return Container(
                                      margin: EdgeInsets.only(right: 12, top: 20, bottom: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(32),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            children: [
                                              Text(opt.title, style: HelloText.title.copyWith(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
                                              const SizedBox(height: 4),
                                              Text(opt.subtitle, style: HelloText.caption.copyWith(color: Colors.white70)),
                                            ],
                                          ),
                                          _buildPill('VOTE', true),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              }
                            )
                          // SINGLE SINGLE-ACTION CONTENT
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Spacer(),
                                Center(
                                  child: Icon(
                                    item.pulse.kind == TriageKind.pay ? Icons.apple 
                                    : item.pulse.kind == TriageKind.call ? Icons.phone 
                                    : Icons.dashboard_customize_outlined,
                                    color: Colors.white.withValues(alpha: 0.15),
                                    size: 96,
                                  ),
                                ),
                                const Spacer(),
                                _buildActionPills(item.pulse),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Progressive Physics Drop Zone filter
    Widget physicsBody = content;
    if (item.offset < 0) {
      // Discarding into the abyss. It must aggressively dissolve and blur to protect the visual hierarchy of the Plasma Handle.
      final double abyssDepth = item.offset.abs();
      final double plasmaFade = (1.0 - (abyssDepth * 2.5)).clamp(0.0, 1.0);
      final double plasmaBlur = (abyssDepth * 15.0).clamp(0.0, 15.0); // Safety limit cap at 15 to prevent WebGL Context Loss

      physicsBody = Opacity(
        opacity: plasmaFade,
        child: plasmaBlur > 0 ? ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: plasmaBlur, sigmaY: plasmaBlur),
          child: physicsBody,
        ) : physicsBody,
      );
    } else {
      // Standard queue render
      physicsBody = Opacity(
        opacity: opacity,
        child: physicsBody,
      );
    }

    return Transform(
      alignment: Alignment.center,
      transform: transform,
      child: physicsBody,
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
              if (_verticalController.hasClients && _verticalController.position.haveDimensions) {
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

        // Native PageView Physics for pure Apple 1:1 Butter Scroll
        Positioned(
          bottom: 120, left: 0, right: 0, height: 520,
          child: PageView.builder(
            scrollDirection: Axis.vertical,
            reverse: true, // Swiping DOWN pulls from the TOP stack
            controller: _verticalController,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), // Unlock 120hz velocity
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
