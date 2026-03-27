import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/liquid_fire_text.dart';
import '../widgets/chat_input.dart';
import '../views/message_feed_page.dart';
import '../views/action_carousel_page.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HelloColors.voidBg,
      appBar: AppBar(
        title: const LiquidFireText(
          text: 'hello',
          style: HelloTypography.hero,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              children: [
                const MessageFeedPage(),
                const ActionCarouselPage(),
              ],
            ),
          ),
          const ChatInput(),
        ],
      ),
    );
  }
}
