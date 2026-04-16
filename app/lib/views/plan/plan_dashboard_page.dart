import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme.dart';
import '../../providers/filtered_feed_providers.dart';
import '../home/decision_board/_card_factory.dart';
import '../home/decision_board/masonry_grid.dart';

class PlanDashboardPage extends ConsumerStatefulWidget {
  const PlanDashboardPage({super.key});

  @override
  ConsumerState<PlanDashboardPage> createState() => _PlanDashboardPageState();
}

class _PlanDashboardPageState extends ConsumerState<PlanDashboardPage> with SingleTickerProviderStateMixin {
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    // 800ms duration allows for the route transition to complete smoothly
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Delay the inner staggering so the outer PageRoute transition breathes first
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _staggerController.forward();
    });
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Let the Hero mesh bleed through
      body: Stack(
        children: [
          // The background Hero that catches the Aurora from the Chat
          Positioned.fill(
            child: Hero(
              tag: 'aurora_mesh',
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [HelloColors.surfaceDeep, const Color(0xFF0F2618)], // Deep expanded aura
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
                  sliver: MasonryFeedGrid(
                    itemCount: ref.watch(plansFeedProvider).length,
                    itemBuilder: (context, index) {
                      final item = ref.watch(plansFeedProvider)[index];
                      // Calculate staggered animation intervals per card
                      final double start = (index * 0.1).clamp(0.0, 1.0);
                      final double end = (start + 0.4).clamp(0.0, 1.0);
                      
                      final slideAnimation = Tween<Offset>(
                        begin: const Offset(0, 0.4), // Slide up from bottom slightly
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _staggerController,
                          curve: Interval(start, end, curve: Curves.easeOutExpo),
                        ),
                      );

                      final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
                        CurvedAnimation(
                          parent: _staggerController,
                          curve: Interval(start, end, curve: Curves.easeOut),
                        ),
                      );

                      return FadeTransition(
                        opacity: fadeAnimation,
                        child: SlideTransition(
                          position: slideAnimation,
                          child: RepaintBoundary(
                            child: buildFeedItemCard(context, item),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Back button to reverse the Portal
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          )
        ],
      ),
    );
  }
}
