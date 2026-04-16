import 'package:flutter/material.dart';
import '../../../../theme.dart';

class ShimmerCard extends StatefulWidget {
  const ShimmerCard({super.key, this.height = 180.0});
  final double height;

  @override
  State<ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<ShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.04, end: 0.10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) => Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: HelloColors.inkPrimary.withValues(alpha: _opacity.value),
          borderRadius: BorderRadius.circular(42),
        ),
      ),
    );
  }
}
