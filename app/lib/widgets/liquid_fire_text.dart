import 'package:flutter/material.dart';
import '../theme.dart'; // Adjust path as needed

/// A custom transform to slide the gradient exactly like CSS background-position
class _SlidingGradientTransform extends GradientTransform {
  final double shift;
  const _SlidingGradientTransform(this.shift);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    // Shifts the gradient horizontally based on the animation value
    return Matrix4.translationValues(bounds.width * shift, 0.0, 0.0);
  }
}

class LiquidFireText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const LiquidFireText({
    super.key,
    required this.text,
    required this.style,
  });

  @override
  State<LiquidFireText> createState() => _LiquidFireTextState();
}

class _LiquidFireTextState extends State<LiquidFireText> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 3s linear infinite animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(); 
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcIn, // Masks the gradient strictly to the text alpha
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: HelloColors.liquidFireStandard.colors,
              stops: HelloColors.liquidFireStandard.stops,
              tileMode: TileMode.repeated, // Crucial for infinite scrolling
              transform: _SlidingGradientTransform(-_controller.value),
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            style: widget.style,
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}
