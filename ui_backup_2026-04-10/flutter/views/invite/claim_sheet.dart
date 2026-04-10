import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';

// Step 4: Cross-Platform Mocking (The Deep Link Trigger)
class MockDeepLinkNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  
  void trigger(bool val) => state = val;
}
final deepLinkInterceptorProvider = NotifierProvider<MockDeepLinkNotifier, bool>(() {
  return MockDeepLinkNotifier();
});

class ClaimSheet extends ConsumerStatefulWidget {
  const ClaimSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (_) => const ClaimSheet(),
    );
  }

  @override
  ConsumerState<ClaimSheet> createState() => _ClaimSheetState();
}

class _ClaimSheetState extends ConsumerState<ClaimSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  bool _isJoined = false;

  @override
  void initState() {
    super.initState();
    // Step 3: Animation controller manages the 0.95 scale down and Spring Bounce
    _scaleController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 150),
        value: 1.0, 
        lowerBound: 0.85, 
        upperBound: 1.2,
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (_isJoined) return;
    HapticFeedback.lightImpact(); // Initiate cryptographic seal process
    _scaleController.animateTo(0.95, curve: Curves.easeOut);
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isJoined) return;
    _releaseBounce();
  }

  void _handleTapCancel() {
    if (_isJoined) return;
    _releaseBounce();
  }

  void _handleLongPress() {
    if (_isJoined) return;
    
    // Step 3: Trigger "Gold Burst" equivalent - Rose tint flash & heavy impact
    HapticFeedback.heavyImpact();
    setState(() {
      _isJoined = true;
    });
    
    // Reset trigger if mock
    ref.read(deepLinkInterceptorProvider.notifier).trigger(false);
    _releaseBounce();
    
    // Optional automatic dismiss after joining successfully 
    Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) Navigator.of(context).pop();
    });
  }

  void _releaseBounce() {
    final spring = SpringDescription(
      mass: 1.0,
      stiffness: 400.0,
      damping: 15.0,
    );
    final simulation = SpringSimulation(spring, _scaleController.value, 1.0, 0.0);
    _scaleController.animateWith(simulation);
  }

  @override
  Widget build(BuildContext context) {
    // Step 2: The Blur with sigma 20.0 and dark 50% opacity overlay
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 28, color: HelloColors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The Atmosphere Preview: Massive 120x120 rounded-rectangle (radius 18px)
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: HelloColors.inkSecondary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(18.0), // Exception authorized by doctrine specs for group avatars
                        ),
                        child: const Center(
                          child: Icon(Icons.group, size: 48, color: HelloColors.white),
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Group Name (HelloTypography.hero) and Member Count
                      Text(
                        "Project Horizon", // Mock
                        style: HelloTypography.hero.copyWith(
                          color: HelloColors.white,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "12 Members",
                        style: HelloTypography.hint.copyWith(
                          color: HelloColors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      
                      const SizedBox(height: 80),
                      
                      // Step 3: The Cryptographic Signature Block (Hold-to-Join)
                      GestureDetector(
                        onTapDown: _handleTapDown,
                        onTapUp: _handleTapUp,
                        onTapCancel: _handleTapCancel,
                        onLongPress: _handleLongPress,
                        behavior: HitTestBehavior.opaque, 
                        child: AnimatedBuilder(
                          animation: _scaleController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _scaleController.value,
                              child: child,
                            );
                          },
                          child: Container(
                            color: Colors.transparent, // Maintain Zero-Box
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 300),
                              style: HelloTypography.spaceTitle.copyWith(
                                // Flash Rose tint on lock-in using strict color codes
                                color: _isJoined ? const Color(0xFFD4536B) : HelloColors.white,
                              ),
                              child: Text(
                                _isJoined ? "Cryptographic Lock Sealed" : "Press and Hold to Cryptographically Sign",
                                textAlign: TextAlign.center,
                              ),
                            ),
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
      ),
    );
  }
}
