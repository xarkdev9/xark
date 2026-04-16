import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../utils/haptics.dart';
import 'device_linking_page.dart';

class DeviceListingPage extends StatelessWidget {
  const DeviceListingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HelloColors.voidBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: HelloColors.inkPrimary),
        title: Text('DEVICES', style: TextStyle(fontFamily: 'Inter', fontSize: 13, letterSpacing: 1.0, color: HelloColors.inkSecondary)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            Text('Active Sessions', style: TextStyle(fontFamily: 'Inter', fontSize: 20, color: HelloColors.inkPrimary)),
            const SizedBox(height: 8),
            Text('These devices have active E2EE decryption keys.', style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: HelloColors.inkSecondary)),
            const SizedBox(height: 32),
            _buildDeviceItem('iPhone 15 Pro', 'This device', isCurrent: true),
            const SizedBox(height: 16),
            _buildDeviceItem('MacBook Pro M3', 'Last seen 2 hours ago', isCurrent: false),
            const SizedBox(height: 48),
            Center(
              child: OutlinedButton.icon(
                onPressed: () {
                  HelloHaptic.tap();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DeviceLinkingPage()),
                  );
                },
                icon: Icon(Icons.qr_code_scanner, color: HelloColors.inkPrimary),
                label: Text('LINK NEW DEVICE (SESAME)', style: TextStyle(color: HelloColors.inkPrimary, fontFamily: 'Inter', letterSpacing: 0.5)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceItem(String name, String status, {required bool isCurrent}) {
    return Dismissible(
      key: ValueKey(name),
      direction: isCurrent ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: HelloColors.accent, // Deep Rose
        child: Icon(Icons.delete_sweep, color: HelloColors.inkPrimary),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(isCurrent ? 15 : 5),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(isCurrent ? Icons.phone_iphone : Icons.laptop_mac, color: isCurrent ? HelloColors.accent : HelloColors.inkSecondary, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(fontFamily: 'Inter', fontSize: 16, color: isCurrent ? HelloColors.accent : HelloColors.inkPrimary)),
                  const SizedBox(height: 4),
                  Text(status, style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: HelloColors.inkSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
