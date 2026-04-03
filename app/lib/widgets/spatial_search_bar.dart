import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../animations/spring_curves.dart';
import '../theme.dart';

/// Spatial search bar — visionOS/iMessage feel.
///
/// Zero-Box: No OutlineInputBorder. ClipRRect + BackdropFilter.
/// No-Bold: Placeholder text at w300, search text at w400.
/// Liquid Physics: SpringSimulation scale-down on tap.

class SpatialSearchBar extends StatefulWidget {
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final String hint;

  const SpatialSearchBar({
    super.key,
    this.onChanged,
    this.onTap,
    this.hint = 'search...',
  });

  @override
  State<SpatialSearchBar> createState() => _SpatialSearchBarState();
}

class _SpatialSearchBarState extends State<SpatialSearchBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;
  final _focusNode = FocusNode();
  final _textController = TextEditingController();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: SpringCurve.snappy,
      ),
    );
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _textController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
    if (_focusNode.hasFocus) {
      HapticFeedback.selectionClick();
      _scaleController.forward();
    } else {
      _scaleController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: (_) {
          _scaleController.forward();
          HapticFeedback.selectionClick();
        },
        onTapUp: (_) => _scaleController.reverse(),
        onTapCancel: () => _scaleController.reverse(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: SpringCurve.gentle,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _isFocused
                    ? HelloColors.inkPrimary.withOpacity(0.06)
                    : HelloColors.inkPrimary.withOpacity(0.03),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: HelloColors.inkPrimary.withOpacity(
                      _isFocused ? 0.5 : 0.3,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      onChanged: widget.onChanged,
                      onTap: widget.onTap,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w400, // No-Bold: max w400
                        color: HelloColors.inkPrimary.withOpacity(0.8),
                        letterSpacing: -0.2,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: widget.hint,
                        hintStyle: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w300, // No-Bold: secondary
                          color: HelloColors.inkPrimary.withOpacity(0.25),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                  if (_textController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _textController.clear();
                        widget.onChanged?.call('');
                        setState(() {});
                      },
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: HelloColors.inkPrimary.withOpacity(0.3),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
