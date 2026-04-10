import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme.dart';

class InviteSurface extends StatefulWidget {
  const InviteSurface({super.key});

  @override
  State<InviteSurface> createState() => _InviteSurfaceState();
}

class _InviteSurfaceState extends State<InviteSurface> with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    // Step 1: Slow looping AnimatedOpacity (0.6 to 1.0 over 2000ms)
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _triggerAction() {
    // Step 1: Tapping fires HapticFeedback.selectionClick() locking mock interactions natively
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    // Step 1: Pure HelloColors.voidBg
    return Scaffold(
      backgroundColor: HelloColors.voidBg,
      body: SafeArea(
        child: Column(
          children: [
            // Standard Navigation Bar Left Arrow
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 24, color: HelloColors.inkPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ),
            
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The Cryptographic Keycard: Custom soft rounded QR dots
                    AnimatedBuilder(
                      animation: _opacityAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _opacityAnimation.value,
                          child: child,
                        );
                      },
                      child: Container(
                        width: 240,
                        height: 240,
                        padding: const EdgeInsets.all(16.0),
                        decoration: const BoxDecoration(
                          color: Colors.transparent, // Zero-Box
                        ),
                        child: CustomPaint(
                          painter: _MockQRPainter(color: const Color(0xFFD4536B)), // Rose tint active seed status
                        ),
                      ),
                    ),
                    const SizedBox(height: 64),
                    
                    // Typographic Actions
                    GestureDetector(
                      onTap: _triggerAction,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        "Copy Link",
                        style: HelloTypography.spaceTitle.copyWith(
                          color: HelloColors.inkPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    GestureDetector(
                      onTap: _triggerAction,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        "Share",
                        style: HelloTypography.spaceTitle.copyWith(
                          color: HelloColors.inkPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MockQRPainter extends CustomPainter {
  final Color color;
  _MockQRPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    // Create soft, 21x21 grid of dots representing cryptographic QR modules
    int gridSize = 21;
    double cellSize = size.width / gridSize;
    double dotRadius = cellSize * 0.45;

    final random = math.Random(42); // Seed to preserve UX continuity between rebuilds

    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        // Exclude standard locations for Finder patterns
        bool isFinderArea = (x < 7 && y < 7) || (x > gridSize - 8 && y < 7) || (x < 7 && y > gridSize - 8);
        
        if (isFinderArea) continue; // Drawn manually below

        // 40% fill purely abstracting the data modules
        if (random.nextDouble() > 0.4) {
           canvas.drawCircle(
             Offset(x * cellSize + cellSize / 2, y * cellSize + cellSize / 2),
             dotRadius,
             paint,
           );
        }
      }
    }
    
    // Draw Finder Cores manually for aesthetic symmetry 
    _drawFinderPattern(canvas, const Offset(0, 0), cellSize, paint);
    _drawFinderPattern(canvas, Offset((gridSize - 7) * cellSize, 0), cellSize, paint);
    _drawFinderPattern(canvas, Offset(0, (gridSize - 7) * cellSize), cellSize, paint);
  }

  void _drawFinderPattern(Canvas canvas, Offset topLeft, double cellSize, Paint paint) {
    // Outer rounded square
    final outerRect = Rect.fromLTWH(topLeft.dx + cellSize*0.5, topLeft.dy + cellSize*0.5, cellSize * 6, cellSize * 6);
    canvas.drawRRect(RRect.fromRectAndRadius(outerRect, Radius.circular(cellSize * 1.5)), 
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = cellSize * 1.2);
    // Inner core
    final innerRect = Rect.fromLTWH(topLeft.dx + cellSize * 2.5, topLeft.dy + cellSize * 2.5, cellSize * 2, cellSize * 2);
    canvas.drawRRect(RRect.fromRectAndRadius(innerRect, Radius.circular(cellSize * 0.8)), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
