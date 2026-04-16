import 'package:flutter/material.dart';
import '../../theme.dart';

class ErrorCardOverlay {
  static void show(BuildContext context, String message, {bool isError = true}) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => _ErrorCardWidget(message: message, isError: isError),
    );

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 4), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }
}

class _ErrorCardWidget extends StatefulWidget {
  final String message;
  final bool isError;

  const _ErrorCardWidget({Key? key, required this.message, this.isError = true}) : super(key: key);

  @override
  State<_ErrorCardWidget> createState() => _ErrorCardWidgetState();
}

class _ErrorCardWidgetState extends State<_ErrorCardWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slideAnimation = Tween<double>(begin: -50, end: 16).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
    
    // Reverse animation before dismissal
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) _controller.reverse();
    });
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
        return Positioned(
          top: MediaQuery.of(context).padding.top + _slideAnimation.value,
          left: 16,
          right: 16,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: widget.isError ? HelloColors.accent : HelloColors.recessed,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 20, offset: const Offset(0, 10)),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(widget.isError ? Icons.error_outline : Icons.info_outline, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Colors.white, fontWeight: FontWeight.w400),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
