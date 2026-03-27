import 'package:flutter/material.dart';
import '../theme.dart'; // Adjust path as needed

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isOutbound; // true = Sent by user, false = Received

  const ChatBubble({
    super.key,
    required this.text,
    required this.isOutbound,
  });

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
        child: Text(
          text,
          style: HelloTypography.body.copyWith(color: textColor),
        ),
      ),
    );
  }
}
