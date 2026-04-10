import 'package:flutter/material.dart';
import '../widgets/chat_feed.dart';
import '../widgets/inline_poll_widget.dart';

class MessageFeedPage extends StatelessWidget {
  final String spaceId;
  const MessageFeedPage({super.key, required this.spaceId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: ChatFeed(spaceId: spaceId)),
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: InlinePollWidget(),
        ),
      ],
    );
  }
}
