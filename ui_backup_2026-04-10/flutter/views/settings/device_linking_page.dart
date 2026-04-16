import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';

class DeviceLinkingPage extends ConsumerStatefulWidget {
  const DeviceLinkingPage({super.key});

  @override
  ConsumerState<DeviceLinkingPage> createState() => _DeviceLinkingPageState();
}

class _DeviceLinkingPageState extends ConsumerState<DeviceLinkingPage> with TickerProviderStateMixin {
  late AnimationController _cameraPanController;
  late AnimationController _handshakeController;
  late Animation<double> _gradientPosition;
  late Animation<Color?> _flashColor;
  
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    // Simulate optical feed dynamics
    _cameraPanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    
    _gradientPosition = Tween<double>(begin: -1.0, end: 1.0)
      .animate(CurvedAnimation(parent: _cameraPanController, curve: Curves.easeInOutSine));

    // Validated payload lock transformation
    _handshakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    
    // Step 3 Protocol: Flash Rose tint at 40% immediately upon lock mutating to completely solid 80% opacity
    _flashColor = ColorTween(
      begin: Colors.transparent,
      end: const Color(0xFFD4536B).withValues(alpha: 0.8),
    ).animate(CurvedAnimation(parent: _handshakeController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _cameraPanController.dispose();
    _handshakeController.dispose();
    super.dispose();
  }

  Future<void> _simulateHandshake() async {
    if (_isLocked) return;
    setState(() => _isLocked = true);
    
    // 1. Instantly freeze optical matrix
    _cameraPanController.stop();
    
    // 2. Fire structural haptic impact mapping successful crypto read
    HapticFeedback.heavyImpact();
    
    // 3. Initiate verification payload flash
    _handshakeController.forward();
    
    // 4. Throttle to simulate E2EE symmetric key transfer network delay
    await Future.delayed(const Duration(milliseconds: 1500));
    
    // 5. Deconstruct page context safely
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HelloColors.voidBg,
      body: Stack(
        children: [
          // 1. Active Camera Matrix Simulation Layer
          AnimatedBuilder(
            animation: _cameraPanController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(_gradientPosition.value, -1.0),
                    end: Alignment(-_gradientPosition.value, 1.0),
                    colors: const [
                      Color(0xFF14141A),
                      Color(0xFF2A2A38),
                      Color(0xFF0F0F14),
                    ],
                  ),
                ),
              );
            }
          ),
          
          // 2. Mathematical Optical Blur Inverse Mask (Eliminating borders via physical contrast bounds)
          Positioned.fill(
            child: ClipPath(
              clipper: _SesameMaskClipper(holeSize: 250, radius: 24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.1),
                ),
              ),
            ),
          ),
          
          // 3. True-Clear Optical Target
          Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _simulateHandshake,
              child: AnimatedBuilder(
                animation: _handshakeController,
                builder: (context, child) {
                  return Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      color: _flashColor.value,
                      borderRadius: BorderRadius.circular(24.0),
                    ),
                  );
                }
              ),
            ),
          ),
          
          // 4. Zero-Box Spatial Heads Up Display (HUD)
          Positioned(
            top: MediaQuery.of(context).padding.top + 24,
            left: 16,
            right: 16,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFFE8E8EC)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    if (!_isLocked) Navigator.pop(context);
                  },
                ),
                const SizedBox(width: 24),
                Text(
                  "Link Device",
                  style: HelloTypography.spaceTitle.copyWith(color: const Color(0xFFE8E8EC)), // Mapping to No-Bold title
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SesameMaskClipper extends CustomClipper<Path> {
  final double holeSize;
  final double radius;

  _SesameMaskClipper({required this.holeSize, required this.radius});

  @override
  Path getClip(Size size) {
    final path = Path()..fillType = PathFillType.evenOdd;
    
    path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    final holeRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: holeSize,
      height: holeSize,
    );
    
    path.addRRect(RRect.fromRectAndRadius(holeRect, Radius.circular(radius)));
    
    return path;
  }

  @override
  bool shouldReclip(_SesameMaskClipper oldClipper) => false;
}
