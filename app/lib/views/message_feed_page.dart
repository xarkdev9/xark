import 'package:flutter/material.dart';
import '../widgets/chat_feed.dart';
import '../widgets/inline_poll_widget.dart';

class MessageFeedPage extends StatelessWidget {
  const MessageFeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: ChatFeed()),
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: InlinePollWidget(),
        ),
      ],
    );
  }
}
