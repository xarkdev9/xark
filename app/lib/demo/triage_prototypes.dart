import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hello_app/theme.dart';
import 'package:hello_app/views/home/decision_board/plasma/plasma_clock.dart';
import 'package:hello_app/views/home/decision_board/plasma/plasma_tint.dart';

class TriageDemoPage extends StatelessWidget {
  const TriageDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlasmaClock(
      child: Scaffold(
        backgroundColor: Colors.black, 
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

  final List<TriagePulse> _pulses = [
    const TriagePulse('Pay Ram \$45', TriageKind.pay, Color(0xFFD94B2B), 'Friday Dinner'),
    const TriagePulse('RSVP Dinner', TriageKind.rsvp, Color(0xFF104D36), 'Tomorrow at 7 PM'),
    const TriagePulse(
      'Reply Jake',
      TriageKind.reply,
      Color(0xFF263B6E), 
      '"Can we push the sync to 4 PM?... I have a conflict."',
    ),
    const TriagePulse(
      'Vote Tokyo',
      TriageKind.vote,
      Color(0xFF5E2B66), 
      ['Oct 12-19', 'Oct 15-22', 'Nov 1-8'],
    ),
    const TriagePulse('Call Sarah', TriageKind.call, Color(0xFF9E7B1A), 'Missed call 2h ago'),
    const TriagePulse('Sign Lease', TriageKind.none, Color(0xFF2D2D2D)), 
    const TriagePulse('Book Flights', TriageKind.none, Color(0xFF254B54)), 
    const TriagePulse('Check Visa', TriageKind.none, Color(0xFF3B2F36)), 
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.16); // Fit ~6 items
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildAtmosphere() {
    final activeColor = _pulses[_currentIndex].ambientColor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.4),
          radius: 1.2,
          colors: [
            activeColor.withValues(alpha: 0.9),
            activeColor.withValues(alpha: 0.4),
            Colors.black,
          ],
        ),
      ),
    );
  }

  Widget _buildThumbArcAction() {
    final pulse = _pulses[_currentIndex];

    Widget actionContent;
    switch (pulse.kind) {
      case TriageKind.rsvp:
        actionContent = const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NakedAction(label: 'CAN\'T MAKE IT'),
            _NakedAction(label: 'YES, I\'M IN', isPrimary: true),
          ],
        );
        break;
      case TriageKind.pay:
        actionContent = const _NakedAction(label: 'PAY APPLE PAY', isPrimary: true);
        break;
      case TriageKind.call:
        actionContent = const _NakedAction(label: 'START AUDIO', isPrimary: true);
        break;
      case TriageKind.reply:
        actionContent = const _NakedAction(label: 'DRAFT REPLY', isPrimary: true);
        break;
      case TriageKind.vote:
        final options = pulse.payload as List<String>;
        // Horizontal swiping raw text strings - highly thumb ergonomic below the wheel
        actionContent = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: options.map((opt) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: _NakedAction(label: opt.toUpperCase(), isPrimary: true),
            )).toList(),
          ),
        );
        break;
      case TriageKind.none:
        actionContent = const _NakedAction(label: 'ACKNOWLEDGE');
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: SizedBox(
        key: ValueKey(pulse.title),
        width: double.infinity,
        child: Center(child: actionContent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: _buildAtmosphere()),
        Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('1:42', style: HelloText.body.copyWith(
                      color: Colors.white, 
                      fontWeight: FontWeight.w300 
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
            Expanded(
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
                      final double blurSigma = (distance * 3.0).clamp(0.0, 15.0);
                      final double scale = (1 - (distance * 0.1)).clamp(0.5, 1.0);
                      final double opacity = (1 - (distance * 0.25)).clamp(0.0, 1.0);

                      final Matrix4 transform = Matrix4.identity()
                        ..setEntry(3, 2, 0.0015)
                        ..rotateX(rotationAngle)
                        ..scale(scale);

                      final pulse = _pulses[index];

                      // Core eye-line title
                      Widget titleLayer = Text(
                        pulse.title,
                        style: HelloText.display.copyWith(
                          color: isCenter ? Colors.white : Colors.white.withValues(alpha: 0.2),
                          fontWeight: isCenter ? FontWeight.w400 : FontWeight.w300,
                        ),
                        textAlign: TextAlign.center,
                      );

                      // Context text (e.g. Chat message, vote dates) strictly in the eye line!
                      Widget contextLayer = const SizedBox.shrink();
                      if (pulse.kind != TriageKind.vote && pulse.payload is String) {
                        contextLayer = Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Text(
                            pulse.payload as String,
                            style: HelloText.title.copyWith(
                              color: isCenter ? Colors.white.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.2),
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w300,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      Widget block = Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          titleLayer,
                          contextLayer,
                        ],
                      );

                      Widget focalLayer = block;
                      if (blurSigma > 0.1) {
                        focalLayer = ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                          child: block,
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
            // Strictly isolated Thumb Action Zone: 120 pixels fixed at bottom. Cannot overlap.
            SafeArea(
              top: false,
              child: SizedBox(
                height: 120, // Thumb strike zone ceiling.
                child: Center(
                  child: _buildThumbArcAction(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NakedAction extends StatelessWidget {
  final String label;
  final bool isPrimary;

  const _NakedAction({
    required this.label,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget textLayer = Text(
      label,
      style: HelloText.title.copyWith(
        color: isPrimary ? Colors.white : Colors.white.withValues(alpha: 0.5),
        fontWeight: FontWeight.w300,
        letterSpacing: 1.5,
        fontSize: 18, 
      ),
    );

    if (isPrimary) {
      textLayer = PlasmaTint(child: textLayer);
    }

    // Wrap in a large padding box so the actual thumb hit slop is massive but invisible
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
      child: textLayer,
    );
  }
}
