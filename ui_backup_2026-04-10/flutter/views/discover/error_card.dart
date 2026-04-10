import 'package:flutter/material.dart';
import '../../theme.dart';

/// Inline, non-blocking error card with auto-dismiss.
///
/// Shows a subtle red/orange tinted message with optional
/// "Report this" and "Retry" actions. Auto-dismisses after
/// [autoDismissAfter] (default 30s) with a fade animation.
class ErrorCard extends StatefulWidget {
  final String message;
  final String? errorType;
  final VoidCallback? onReport;
  final VoidCallback? onRetry;
  final Duration autoDismissAfter;

  const ErrorCard({
    super.key,
    required this.message,
    this.errorType,
    this.onReport,
    this.onRetry,
    this.autoDismissAfter = const Duration(seconds: 30),
  });

  @override
  State<ErrorCard> createState() => _ErrorCardState();
}

class _ErrorCardState extends State<ErrorCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0,
    );

    // Auto-dismiss after duration
    Future.delayed(widget.autoDismissAfter, () {
      if (mounted && !_dismissed) {
        _dismiss();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _dismiss() {
    _dismissed = true;
    _fadeController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeController,
      builder: (context, child) {
        if (_fadeController.value == 0.0) return const SizedBox.shrink();
        return Opacity(
          opacity: _fadeController.value,
          child: child,
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: HelloColors.errorOrange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: HelloColors.errorOrange.withValues(alpha: 0.2),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Error type label (if provided)
            if (widget.errorType != null) ...[
              Text(
                widget.errorType!,
                style: HelloTypography.hint.copyWith(
                  fontWeight: FontWeight.w300,
                  color: HelloColors.errorOrange.withValues(alpha: 0.7),
                  fontSize: 10.0,
                ),
              ),
              const SizedBox(height: 4.0),
            ],

            // Message
            Text(
              widget.message,
              style: HelloTypography.body.copyWith(
                fontSize: 14.0,
                fontWeight: FontWeight.w400,
                color: HelloColors.inkSecondary,
              ),
            ),

            const SizedBox(height: 8.0),

            // Actions row
            Row(
              children: [
                if (widget.onReport != null)
                  GestureDetector(
                    onTap: widget.onReport,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: Text(
                        'Report this',
                        style: HelloTypography.label.copyWith(
                          fontWeight: FontWeight.w400,
                          color: HelloColors.errorOrange,
                          decoration: TextDecoration.underline,
                          decorationColor: HelloColors.errorOrange,
                        ),
                      ),
                    ),
                  ),
                if (widget.onRetry != null)
                  GestureDetector(
                    onTap: widget.onRetry,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      'Retry',
                      style: HelloTypography.label.copyWith(
                        fontWeight: FontWeight.w400,
                        color: HelloColors.accent,
                        decoration: TextDecoration.underline,
                        decorationColor: HelloColors.accent,
                      ),
                    ),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: _dismiss,
                  behavior: HitTestBehavior.opaque,
                  child: const Icon(
                    Icons.close,
                    size: 14.0,
                    color: HelloColors.inkTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
