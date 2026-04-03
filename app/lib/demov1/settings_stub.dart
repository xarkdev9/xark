import 'package:flutter/material.dart';

/// Stub settings page for demo mode
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        title: const Text('Settings', style: TextStyle(
          fontFamily: 'Inter', fontWeight: FontWeight.w400, fontSize: 20,
        )),
      ),
      body: const Center(child: Text('Demo Mode — Settings Placeholder')),
    );
  }
}
