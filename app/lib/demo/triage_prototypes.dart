import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hello_app/theme.dart';
import 'package:hello_app/views/home/decision_board/plasma/plasma_clock.dart';

class TriageDemoPage extends StatelessWidget {
  const TriageDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlasmaClock(
      // The background logic is now entirely handled by the prototype itself
      child: Scaffold(
        backgroundColor: Colors.black, // Base layer for the deep dark atmospheric gradients
        body: CylinderArcTriageDemo(),
      ),
    );
  }
}

enum TriageKind { rsvp, pay, reply, vote, call, none }

class TriagePulse {
  final String title;
  final TriageKind kind;
  final Color ambientColor;
  final dynamic payload;
  const TriagePulse(this.title, this.kind, this.ambientColor, [this.payload]);
}

class CylinderArcTriageDemo extends StatefulWidget {
  const CylinderArcTriageDemo({super.key});

  @override
  State<CylinderArcTriageDemo> createState() => _CylinderArcTriageDemoState();
}

class _CylinderArcTriageDemoState extends State<CylinderArcTriageDemo> {
  late PageController _pageController;
  int _currentIndex = 0;

  // The deep ambient hues extracted from the "soul" of each notification type
  final List<TriagePulse> _pulses = [
    const TriagePulse('Pay Ram \$45', TriageKind.pay, Color(0xFFD94B2B)), // Burnt Plasma Orange
    const TriagePulse('RSVP Dinner', TriageKind.rsvp, Color(0xFF104D36)), // Deep Pine Green
    const TriagePulse(
      'Reply Jake',
      TriageKind.reply,
      Color(0xFF263B6E), // Evening Indigo
      ['Can we push the sync to 4 PM?', 'I have a conflict.'],
    ),
    const TriagePulse(
      'Vote Tokyo',
      TriageKind.vote,
      Color(0xFF5E2B66), // Midnight Violet
      ['Oct 12 - 19', 'Oct 15 - 22', 'Nov 1 - 8'],
    ),
    const TriagePulse('Call Sarah', TriageKind.call, Color(0xFF9E7B1A)), // Dark Amber
    const TriagePulse('Sign Lease', TriageKind.none, Color(0xFF2D2D2D)), // Graphite
    const TriagePulse('Book Flights', TriageKind.none, Color(0xFF254B54)), // Slate Sea
    const TriagePulse('Check Visa', TriageKind.none, Color(0xFF3B2F36)), // Dusky Rose
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.25);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// The overarching atmospheric environment that reacts to scroll
  Widget _buildAtmosphere() {
    final activeColor = _pulses[_currentIndex].ambientColor;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        // The Apple Music mesh gradient simulation 
        gradient: RadialGradient(
          center: const Alignment(0, -0.4),
          radius: 1.2,
          colors: [
            activeColor.withValues(alpha: 0.9),
            activeColor.withValues(alpha: 0.4),
            Colors.black, // Sinks into the void at the bottom edge
          ],
        ),
      ),
    );
  }

  /// The Glass Platter Action Dock at the bottom
  Widget _buildGlassPlatter() {
    final pulse = _pulses[_currentIndex];

    Widget actionContent;
    switch (pulse.kind) {
      case TriageKind.rsvp:
        actionContent = const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NakedAction(label: 'Yes, I\'m in', icon: Icons.check, isPrimary: true),
            _NakedAction(label: 'Can\'t Make It', icon: Icons.close),
          ],
        );
        break;
      case TriageKind.pay:
        actionContent = const _NakedAction(label: 'Pay via Apple Pay', icon: Icons.apple, isPrimary: true);
        break;
      case TriageKind.call:
        actionContent = const _NakedAction(label: 'Start Audio', icon: Icons.phone, isPrimary: true);
        break;
      case TriageKind.reply:
        final msgs = pulse.payload as List<String>;
        actionContent = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Absolutely zero boxes. Raw typographic chat snippet.
            ...msgs.map((m) => Padding(
              padding: EdgeInsets.only(bottom: 6.0),
              child: Text('"$m"', style: HelloText.body.copyWith(
                color: Colors.white.withValues(alpha: 0.6), 
                fontStyle: FontStyle.italic
              )),
            )),
            const SizedBox(height: 8),
            const _NakedAction(label: 'Draft Reply', icon: Icons.reply, isPrimary: true),
          ],
        );
        break;
      case TriageKind.vote:
        final options = pulse.payload as List<String>;
        actionContent = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: options.map((opt) => Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                opt, 
                style: HelloText.title.copyWith(color: Colors.white.withValues(alpha: 0.8))
              ),
            )).toList(),
          ),
        );
        break;
      case TriageKind.none:
        actionContent = Text(
          'Acknowledge', 
          style: HelloText.body.copyWith(color: Colors.white.withValues(alpha: 0.4))
        );
        break;
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        // The signature frosted glass effect limiting the background bleed
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            height: 160,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1), // Translucent sheath
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15), // Microscopic rim light
                width: 0.5,
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: SizedBox(
                key: ValueKey(pulse.title),
                child: Center(child: actionContent),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. The Liquid Atmosphere Base
        Positioned.fill(child: _buildAtmosphere()),

        // 2. Zenith Status (Top Horizon)
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('1:42', style: HelloText.body.copyWith(
                    color: Colors.white, 
                    fontWeight: FontWeight.w300 // Keeping thin, no bold tracking
                  )),
                  const SizedBox(width: 12),
                  Text('Sat Apr 11', style: HelloText.body.copyWith(
                    color: Colors.white, 
                    fontWeight: FontWeight.w400
                  )),
                ],
              ),
            ),
          ),
        ),

        // 3. The Z-Axis Eye Line (Main Focus Engine)
        Positioned.fill(
          child: PageView.builder(
            scrollDirection: Axis.vertical,
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemCount: _pulses.length,
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double pageOffset = 0;
                  if (_pageController.position.haveDimensions) {
                    pageOffset = _pageController.page! - index;
                  } else {
                    pageOffset = (_currentIndex - index).toDouble();
                  }

                  final double distance = pageOffset.abs();
                  final bool isCenter = distance < 0.25;

                  final double rotationAngle = pageOffset * 0.4;
                  final double blurSigma = (distance * 4.0).clamp(0.0, 15.0);
                  final double scale = (1 - (distance * 0.15)).clamp(0.6, 1.0);
                  final double opacity = (1 - (distance * 0.4)).clamp(0.0, 1.0);

                  final Matrix4 transform = Matrix4.identity()
                    ..setEntry(3, 2, 0.0015)
                    ..rotateX(rotationAngle)
                    ..scale(scale);

                  Widget textLayer = Text(
                    _pulses[index].title,
                    style: HelloText.display.copyWith(
                      // Pure white hero text vs translucent peripheral text
                      color: isCenter ? Colors.white : Colors.white.withValues(alpha: 0.3),
                    ),
                    textAlign: TextAlign.center,
                  );

                  Widget focalLayer = textLayer;
                  if (blurSigma > 0.1) {
                    focalLayer = ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                      child: textLayer,
                    );
                  }

                  return Center(
                    child: Transform(
                      alignment: Alignment.center,
                      transform: transform,
                      child: Opacity(
                        opacity: opacity,
                        child: focalLayer,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // 4. Thumb Arc - The Glassmorphic Actions Capsule
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 24.0),
              child: _buildGlassPlatter(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Raw Typography + Icon action (True Zero Box)
class _NakedAction extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isPrimary;

  const _NakedAction({
    required this.label,
    this.icon,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(
            icon, 
            size: 24, 
            color: isPrimary ? Colors.white : Colors.white.withValues(alpha: 0.5)
          ),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: HelloText.title.copyWith(
            color: isPrimary ? Colors.white : Colors.white.withValues(alpha: 0.5),
            fontSize: 20, // slightly larger, thumb friendly
          ),
        ),
      ],
    );
  }
}
