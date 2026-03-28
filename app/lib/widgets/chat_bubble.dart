import 'package:flutter/material.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart'; // Ensure models are available
import '../theme.dart'; // Adjust path as needed

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isOutbound; // true = Sent by user, false = Received
  final MessageStatus status;

  const ChatBubble({
    super.key,
    required this.text,
    required this.isOutbound,
    this.status = MessageStatus.sent,
  });

  Widget _buildStatusIcon() {
    if (!isOutbound) return const SizedBox.shrink();

    IconData iconData = Icons.access_time;
    Color iconColor = HelloColors.inkTertiary;

    switch (status) {
      case MessageStatus.sending:
        iconData = Icons.access_time;
        break;
      case MessageStatus.sent:
        iconData = Icons.check;
        break;
      case MessageStatus.delivered:
        iconData = Icons.done_all;
        break;
      case MessageStatus.read:
        iconData = Icons.done_all;
        iconColor = const Color(0xFFD4536B); // #D4536B rose tint
        break;
      case MessageStatus.failed:
        iconData = Icons.error_outline;
        iconColor = HelloColors.errorOrange;
        break;
    }

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(begin: HelloColors.inkTertiary, end: iconColor),
      duration: const Duration(milliseconds: 300),
      builder: (context, color, _) {
        return Icon(
          iconData,
          size: 12.0,
          color: color ?? iconColor,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Define the colors based on the design tokens
    final backgroundColor = isOutbound ? HelloColors.recessed : HelloColors.white;
    final textColor = isOutbound ? HelloColors.inkPrimary : HelloColors.inkPrimary;

    return Align(
      // Push outbound messages to the right, inbound to the left
      alignment: isOutbound ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          // Ensures the bubble doesn't span the entire screen width
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          // If the background is white, add a microscopic border to define it against the FAFAFA canvas
          border: !isOutbound ? Border.all(color: Colors.black.withValues(alpha: 0.04), width: 1) : null,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            // The asymmetric tail logic
            bottomLeft: Radius.circular(isOutbound ? 16 : 4),
            bottomRight: Radius.circular(isOutbound ? 4 : 16),
          ),
        ),
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            Text(
              text,
              style: HelloTypography.body.copyWith(color: textColor),
            ),
            if (isOutbound)
              Padding(
                padding: const EdgeInsets.only(left: 6.0, bottom: 2.0),
                child: _buildStatusIcon(),
              ),
          ],
        ),
      ),
    );
  }
}
