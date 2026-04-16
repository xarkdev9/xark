import 'package:flutter/material.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../../theme.dart';

/// Bottom sheet for error reporting / user feedback.
///
/// Shows pre-filled error context, a "What happened?" text field,
/// and a "Send Report" button. Success state auto-closes after 2s.
/// Offline state shows a saved-for-later message.
class FeedbackSheet extends StatefulWidget {
  final ErrorReport? errorReport;
  final void Function(String description)? onSubmit;

  const FeedbackSheet({
    super.key,
    this.errorReport,
    this.onSubmit,
  });

  /// Show as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    ErrorReport? errorReport,
    void Function(String description)? onSubmit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: HelloColors.chrome,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: FeedbackSheet(
          errorReport: errorReport,
          onSubmit: onSubmit,
        ),
      ),
    );
  }

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

enum _FeedbackState { editing, submitted, offline }

class _FeedbackSheetState extends State<FeedbackSheet> {
  final _descriptionController = TextEditingController();
  _FeedbackState _state = _FeedbackState.editing;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) return;

    widget.onSubmit?.call(description);
    setState(() => _state = _FeedbackState.submitted);

    // Auto-close after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36.0,
              height: 4.0,
              decoration: BoxDecoration(
                color: HelloColors.neutralGray.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
          ),

          const SizedBox(height: 20.0),

          if (_state == _FeedbackState.submitted) ...[
            _buildSuccess(),
          ] else if (_state == _FeedbackState.offline) ...[
            _buildOffline(),
          ] else ...[
            _buildEditingState(),
          ],
        ],
      ),
    );
  }

  Widget _buildEditingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Report an issue',
          style: HelloTypography.spaceTitle.copyWith(
            fontWeight: FontWeight.w400,
          ),
        ),

        const SizedBox(height: 16.0),

        // Pre-filled error context
        if (widget.errorReport != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: HelloColors.recessed,
              borderRadius: BorderRadius.circular(6.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _contextRow('Type', widget.errorReport!.errorType),
                const SizedBox(height: 4.0),
                _contextRow('Message', widget.errorReport!.errorMessage),
                const SizedBox(height: 4.0),
                _contextRow(
                  'Time',
                  _formatTime(widget.errorReport!.occurredAt),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16.0),
        ],

        // "What happened?" text field
        Text(
          'What happened?',
          style: HelloTypography.label.copyWith(
            fontWeight: FontWeight.w400,
            color: HelloColors.inkSecondary,
          ),
        ),
        const SizedBox(height: 8.0),
        Container(
          decoration: BoxDecoration(
            color: HelloColors.recessed,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: TextField(
            controller: _descriptionController,
            maxLines: 3,
            style: HelloTypography.body.copyWith(
              fontWeight: FontWeight.w400,
              fontSize: 15.0,
            ),
            decoration: InputDecoration(
              hintText: 'Describe what you were doing...',
              hintStyle: HelloTypography.hint.copyWith(
                fontWeight: FontWeight.w300,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(12.0),
            ),
          ),
        ),

        const SizedBox(height: 16.0),

        // Send Report button
        GestureDetector(
          onTap: _submit,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14.0),
            decoration: BoxDecoration(
              color: HelloColors.accent,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Center(
              child: Text(
                'Send Report',
                style: HelloTypography.body.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 40.0,
              color: HelloColors.successGreen,
            ),
            const SizedBox(height: 12.0),
            Text(
              "Got it. We'll look into this.",
              style: HelloTypography.body.copyWith(
                fontWeight: FontWeight.w400,
                color: HelloColors.inkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffline() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 40.0,
              color: HelloColors.inkTertiary,
            ),
            const SizedBox(height: 12.0),
            Text(
              "Report saved, will send when you're back online.",
              style: HelloTypography.body.copyWith(
                fontWeight: FontWeight.w400,
                color: HelloColors.inkSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _contextRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60.0,
          child: Text(
            label,
            style: HelloTypography.hint.copyWith(
              fontWeight: FontWeight.w300,
              fontSize: 11.0,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: HelloTypography.hint.copyWith(
              fontWeight: FontWeight.w300,
              fontSize: 11.0,
              color: HelloColors.inkSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $hour:$minute';
  }
}
