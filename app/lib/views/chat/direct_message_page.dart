import 'package:flutter/material.dart';
import '../../theme.dart';

class DirectMessagePage extends StatelessWidget {
  const DirectMessagePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HelloColors.voidBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              child: Text('Messages', style: HelloText.title),
            ),
            const Spacer(),
            // Sent Bubble (Glassmorphic No-Box Bubble)
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF51443E), // Taupe sent color
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Text('Are we still on for 8?', style: HelloText.body),
              ),
            ),
            const SizedBox(height: 120), // Space for keyboard/composer
          ],
        ),
      ),
    );
  }
}
