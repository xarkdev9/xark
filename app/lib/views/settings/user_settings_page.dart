import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../utils/haptics.dart';
import '../home/decision_board/avatar_utils.dart';
import '../os/feedback_sheet.dart';

class UserSettingsPage extends StatefulWidget {
  const UserSettingsPage({Key? key}) : super(key: key);

  @override
  State<UserSettingsPage> createState() => _UserSettingsPageState();
}

class _UserSettingsPageState extends State<UserSettingsPage> {
  final List<String> _devices = ['iPhone 15 Pro • Current', 'MacBook Air M2 • 2d ago', 'iPad Air • 4w ago'];

  void _revokeDevice(int index) {
    setState(() {
      _devices.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HelloColors.voidBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back, color: HelloColors.inkPrimary),
                  ),
                  const SizedBox(width: 16),
                  Text('Profile & Vault', style: HelloText.display.copyWith(fontSize: 28)),
                ],
              ),
            ),
            
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  // 1. Name & Avatar Editor
                  Row(
                    children: [
                      HologramAvatar(avatarPath: getAvatarImagePath('Ram'), size: 64),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              style: TextStyle(fontFamily: 'Inter', fontSize: 24, color: HelloColors.inkPrimary, fontWeight: FontWeight.w400),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Your Name',
                                hintStyle: TextStyle(color: HelloColors.inkSecondary),
                              ),
                              controller: TextEditingController(text: 'Ram'),
                            ),
                            Text('Edit Avatar', style: TextStyle(color: HelloColors.accent, fontSize: 13, fontFamily: 'Inter')),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 48),

                  // 2. QR Viewfinder (Sesame Protocol)
                  Text('CROSS-DEVICE LINKING', style: TextStyle(color: HelloColors.inkSecondary, letterSpacing: 1.2, fontSize: 11)),
                  const SizedBox(height: 16),
                  Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: HelloColors.inkPrimary.withAlpha(10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: HelloColors.inkPrimary.withAlpha(20)),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner, color: HelloColors.inkPrimary, size: 48),
                          const SizedBox(height: 12),
                          Text('SESAME VIEWFINDER ACTIVE', style: TextStyle(fontFamily: 'Inter', fontSize: 11, letterSpacing: 1.2, color: HelloColors.inkPrimary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // 3. Device Management
                  Text('ACTIVE SESSIONS', style: TextStyle(color: HelloColors.inkSecondary, letterSpacing: 1.2, fontSize: 11)),
                  const SizedBox(height: 16),
                  ..._devices.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final device = entry.value;
                    return Dismissible(
                      key: Key(device),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) {
                        HelloHaptic.warning();
                        _revokeDevice(idx);
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        color: Colors.red.shade900,
                        child: Text('REVOKE KEY', style: TextStyle(color: HelloColors.inkPrimary, letterSpacing: 1.2, fontSize: 11)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(device, style: TextStyle(fontFamily: 'Inter', fontSize: 16, color: HelloColors.inkPrimary)),
                            Icon(Icons.key, color: HelloColors.inkSecondary, size: 16),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 48),

                  // 4. Feedback Surface Binding
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (_) => const FeedbackSheet(),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: HelloColors.accent.withAlpha(50)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Submit Feedback',
                          style: TextStyle(fontFamily: 'Inter', color: HelloColors.accent, fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 64),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

