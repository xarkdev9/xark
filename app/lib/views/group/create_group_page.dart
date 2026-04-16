import 'package:flutter/material.dart';
import '../../theme.dart';

class CreateGroupPage extends StatelessWidget {
  const CreateGroupPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HelloColors.voidBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create Group', style: HelloText.display),
              const SizedBox(height: 24),
              Text('Create a new spatial plane for your group.', style: HelloText.body),
              const SizedBox(height: 80),
              const Center(
                // Placeholder for dynamic QR/Link generation
                child: Icon(Icons.qr_code, size: 120, color: HelloColors.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
