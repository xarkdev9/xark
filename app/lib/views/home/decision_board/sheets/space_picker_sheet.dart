import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../theme.dart';
import 'spatial_sheet_wrapper.dart';

Future<void> openSpacePickerSheet(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'SpacePickerSheet',
    barrierColor: Colors.black.withValues(alpha: 0.28),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, _, _) {
      return Stack(
        children: [
          Positioned.fill(
            child: const SizedBox.expand(),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: _SpacePickerSheet(),
          ),
        ],
      );
    },
    transitionBuilder: (_, animation, _, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );
    },
  );
}

class _SpacePickerSheet extends StatefulWidget {
  const _SpacePickerSheet();

  @override
  State<_SpacePickerSheet> createState() => _SpacePickerSheetState();
}

class _SpacePickerSheetState extends State<_SpacePickerSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _rubberTugController;
  late final Animation<double> _scaleAnimation;
  bool _isTugging = false;

  final List<String> _spaces = [
    'Alaska Trip 2027',
    'Bali Villa Crew',
    'Weekend Tahoe',
    'Friendsgiving',
  ];

  @override
  void initState() {
    super.initState();
    _rubberTugController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    // The "Rubber Tug" parameters: stretches down to 0.8, then violently springs into the Plans node
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 0.1).chain(CurveTween(curve: Curves.easeInBack)), weight: 70),
    ]).animate(_rubberTugController);

    _rubberTugController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Navigator.of(context).pop();
      }
    });
  }

  void _triggerRubberTugAndSend(String spaceName) {
    setState(() {
      _isTugging = true;
    });
    // Haptic feedback could be triggered here
    _rubberTugController.forward();
  }

  @override
  void dispose() {
    _rubberTugController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If tugging, override the whole sheet UI with the scaling animation
    if (_isTugging) {
      return AnimatedBuilder(
        animation: _rubberTugController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            // Slide toward Plans tab (approx offset mapping)
            child: Transform.translate(
              offset: Offset(
                0, 
                _rubberTugController.value * MediaQuery.of(context).size.height * 0.4
              ),
              child: Opacity(
                opacity: 1.0 - (_rubberTugController.value * 1.5).clamp(0.0, 1.0),
                child: _buildPickerContent(),
              ),
            ),
          );
        },
      );
    }
    
    return _buildPickerContent();
  }

  Widget _buildPickerContent() {
    return SpatialSheetWrapper(
      title: 'Choose Event',
      subtitle: 'Where should this poll go?',
      bodyBuilder: (scrollController) {
        return ListView.separated(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 120, 16, 100),
          itemCount: _spaces.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final space = _spaces[i];
            return GestureDetector(
              onTap: () => _triggerRubberTugAndSend(space),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.terrain_rounded, color: HelloColors.inkSecondary),
                        const SizedBox(width: 16),
                        Text(
                          space,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            color: HelloColors.inkPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),,
            );
          },
        );
      },
    );
  }
}
