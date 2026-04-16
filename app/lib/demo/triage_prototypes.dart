import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hello_app/theme.dart';
import 'package:hello_app/views/home/decision_board/plasma/plasma_clock.dart';
import 'package:hello_app/views/home/decision_board/plasma/plasma_tint.dart';

/// Wrapper page for the Triage Prototypes
class TriageDemoPage extends StatelessWidget {
  const TriageDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlasmaClock(
      child: Scaffold(
        backgroundColor: HelloColors.voidBg,
        body: CylinderArcTriageDemo(),
      ),
    );
  }
}

/// The Cylinder Arc + Focal Lens Prototype
/// Wraps elements in 3D polar coordinates and applies optical camera blur to the Z-depth
class CylinderArcTriageDemo extends StatefulWidget {
  const CylinderArcTriageDemo({super.key});

  @override
  State<CylinderArcTriageDemo> createState() => _CylinderArcTriageDemoState();
}

class _CylinderArcTriageDemoState extends State<CylinderArcTriageDemo> {
  late PageController _pageController;
  int _currentIndex = 0;

  final List<String> _items = [
    'Vote Tokyo',
    'Pay Ram \$45',
    'RSVP Dinner',
    'Sign Lease',
    'Book Flights',
    'Review Pitch',
    'Send Invoice',
    'Call Sarah',
    'Renew Passport',
    'Check Visa',
    'Buy Skis',
    'Pick up Cake',
    'Pack Bags',
    'Call Uber',
    'Check-in Flight',
  ];

  @override
  void initState() {
    super.initState();
    // A tight vertical viewport fraction naturally bunches the text vertically
    _pageController = PageController(viewportFraction: 0.20);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 40.0),
            child: Text(
              '${_items.length - _currentIndex} Actions Remaining',
              style: HelloText.label.copyWith(letterSpacing: 2.0),
            ),
          ),
        ),
        Expanded(
          child: PageView.builder(
            scrollDirection: Axis.vertical,
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemCount: _items.length,
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

                  // 1. CYLINDER ARC (3D Rotation)
                  // Using pageOffset directly so items above tilt one way, and below tilt the other.
                  // This creates a physical 3D wheel effect.
                  final double rotationAngle = pageOffset * 0.4;

                  // 2. FOCAL LENS (Optical Blur)
                  // Clamping at 12px to strictly ensure we never hit the 30px WebGL crash limit
                  final double blurSigma = (distance * 3.5).clamp(0.0, 12.0);

                  // 3. PHYSICAL ATMOSPHERE (Scale & Opacity)
                  // Peripheral items physically shrink and drift into the blackness
                  final double scale = (1 - (distance * 0.15)).clamp(0.6, 1.0);
                  final double opacity = (1 - (distance * 0.4)).clamp(0.0, 1.0);

                  // The 3D Wheel Transform
                  final Matrix4 transform = Matrix4.identity()
                    ..setEntry(3, 2, 0.0015) // Deep Perspective multiplier
                    ..rotateX(rotationAngle)
                    ..scale(scale);

                  Widget textLayer = Text(
                    _items[index],
                    style: HelloText.display.copyWith(
                      // Central item turns pure solid ink before receiving plasma.
                      // Peripheral items turn gray as they fade.
                      color: isCenter ? HelloColors.inkPrimary : HelloColors.inkTertiary,
                    ),
                    textAlign: TextAlign.center,
                  );

                  // The primary center action gets the fluid plasma brand fire
                  if (isCenter) {
                    textLayer = PlasmaTint(child: textLayer);
                  }

                  // Apply the camera blur dynamically
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
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 40.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.keyboard_arrow_up, color: HelloColors.inkTertiary, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Scroll to explore Z-Axis',
                  style: HelloText.label.copyWith(color: HelloColors.inkTertiary),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.keyboard_arrow_down, color: HelloColors.inkTertiary, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
