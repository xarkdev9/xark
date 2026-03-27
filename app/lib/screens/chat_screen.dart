import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/liquid_fire_text.dart';
import '../widgets/chat_feed.dart';
import '../widgets/chat_input.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HelloColors.voidBg,
      appBar: AppBar(
        backgroundColor: HelloColors.voidBg,
        elevation: 0,
        scrolledUnderElevation: 0, // Prevents Material 3 scroll color shifts
        title: const HelloAnimation(
          text: 'hello',
          style: HelloTypography.hero,
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: ChatFeed(),
          ),
          const ChatInput(),
        ],
      ),
    );
  }
}
