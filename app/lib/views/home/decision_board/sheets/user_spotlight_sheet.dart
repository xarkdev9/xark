import 'package:flutter/material.dart';
import '../../../../theme.dart';

class UserSpotlightSheet extends StatefulWidget {
  const UserSpotlightSheet({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const UserSpotlightSheet(),
    );
  }

  @override
  State<UserSpotlightSheet> createState() => _UserSpotlightSheetState();
}

class _UserSpotlightSheetState extends State<UserSpotlightSheet> {
  final _inputController = TextEditingController();
  final _phantomController = TextEditingController(text: "@sarah should we book the Bali hotel?");
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _inputController.addListener(() {
      setState(() {
        _isTyping = _inputController.text.isNotEmpty;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    // Non-blocking overlay! We don't render thick boxes, just a cinematic floating field
    return Container(
      color: Colors.black.withAlpha(200),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset + 32, left: 16, right: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'USER SPOTLIGHT',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, letterSpacing: 1.0, color: HelloColors.accent),
            ),
            const SizedBox(height: 16),
            Stack(
              alignment: Alignment.centerLeft,
              children: [
                if (!_isTyping)
                  Text(
                    _phantomController.text,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      color: Colors.white.withAlpha(50),
                      letterSpacing: -0.5,
                    ),
                  ),
                TextField(
                  controller: _inputController,
                  autofocus: true,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 28,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) {
                    // Logic: route silently to plans view, push notification to user, DO NOT spam chat.
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Routes directly to Active Plan. Does not alert main chat.',
              style: TextStyle(color: HelloColors.inkSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
