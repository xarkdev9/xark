import 'package:flutter/material.dart';
import '../../../../theme.dart';

class InviteSurface extends StatelessWidget {
  final String userName;

  const InviteSurface({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: HelloColors.voidBg,
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'INVITE TO HELLO',
            style: TextStyle(fontFamily: 'Inter', fontSize: 13, letterSpacing: 2.0, color: HelloColors.accent),
          ),
          const SizedBox(height: 48),
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: HelloColors.inkPrimary.withAlpha(10), // changed from white10
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(color: HelloColors.accent.withAlpha(50), width: 1),
            ),
            child: Center(
              child: Icon(Icons.qr_code_2, size: 100, color: HelloColors.inkPrimary), // changed from white
            ),
          ),
          const SizedBox(height: 48),
          Text(
            'Scan to join securely',
            style: TextStyle(fontFamily: 'Inter', fontSize: 18, color: HelloColors.inkPrimary, fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: 16),
          Text(
            '128-bit hex cryptographic invite node',
            style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: HelloColors.inkSecondary, fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }
}
