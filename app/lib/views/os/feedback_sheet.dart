import 'package:flutter/material.dart';
import '../../theme.dart';

class FeedbackSheet extends StatefulWidget {
  const FeedbackSheet({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const FeedbackSheet(),
    );
  }

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<FeedbackSheet> {
  int _state = 0; // 0: Editing, 1: Submitting, 2: Success
  final _controller = TextEditingController();

  void _submit() async {
    if (_controller.text.isEmpty) return;
    setState(() => _state = 1);
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() => _state = 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      margin: EdgeInsets.only(bottom: bottomInset, left: 12, right: 12),
      decoration: BoxDecoration(
        color: HelloColors.voidBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24), bottom: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_state == 0) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SEND FEEDBACK', style: TextStyle(fontFamily: 'Inter', fontSize: 13, letterSpacing: 1.0, color: HelloColors.inkSecondary)),
              IconButton(icon: Icon(Icons.close, color: HelloColors.inkPrimary), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 4,
            style: TextStyle(color: HelloColors.inkPrimary, fontSize: 16),
            decoration: const InputDecoration(
              hintText: 'What can we improve? Or tap shaking to send a bug report.',
              hintStyle: TextStyle(color: Colors.white54),
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: FloatingActionButton(
              onPressed: _submit,
              backgroundColor: HelloColors.accent,
              child: const Icon(Icons.send, color: Colors.white),
            ),
          ),
          const SizedBox(height: 24),
        ],
      );
    } else if (_state == 1) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: HelloColors.accent),
      );
    } else {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: HelloColors.accent, size: 48),
            const SizedBox(height: 16),
            Text('Received.', style: TextStyle(color: HelloColors.inkPrimary, fontSize: 20)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close', style: TextStyle(color: HelloColors.inkSecondary)),
            )
          ],
        ),
      );
    }
  }
}
