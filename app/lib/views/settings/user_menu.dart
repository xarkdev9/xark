import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../../utils/haptics.dart';
import 'device_listing.dart';

class UserMenu extends StatelessWidget {
  const UserMenu({Key? key}) : super(key: key);

  void _showDevices(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DeviceListingPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(200),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SETTINGS',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: 1.0, color: HelloColors.inkSecondary),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundImage: AssetImage('assets/images/ram_avatar.png'),
                    radius: 28,
                  ),
                  title: const Text('Ram', style: TextStyle(fontFamily: 'Inter', fontSize: 20, color: Colors.white)),
                  subtitle: Text('+1 (555) 123-4567', style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: HelloColors.inkSecondary)),
                  trailing: Icon(Icons.edit, color: HelloColors.inkSecondary, size: 20),
                  onTap: () {},
                ),
                const SizedBox(height: 32),
                const Divider(color: Colors.white12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.security, color: Colors.white),
                  title: const Text('Devices & E2EE Keys', style: TextStyle(fontFamily: 'Inter', fontSize: 16, color: Colors.white)),
                  trailing: Icon(Icons.chevron_right, color: HelloColors.inkSecondary),
                  onTap: () => _showDevices(context),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.palette_outlined, color: Colors.white),
                  title: const Text('Appearance (Plasma Engine)', style: TextStyle(fontFamily: 'Inter', fontSize: 16, color: Colors.white)),
                  trailing: Icon(Icons.chevron_right, color: HelloColors.inkSecondary),
                  onTap: () {
                    HelloHaptic.select();
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: HelloColors.surfaceDeep,
                      builder: (ctx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final mode in HelloThemeMode.values)
                              ListTile(
                                title: Text(
                                  mode.name[0].toUpperCase() + mode.name.substring(1),
                                  style: HelloText.body,
                                ),
                                trailing: HelloColors.currentThemeMode == mode
                                    ? Icon(Icons.check, color: HelloColors.accent)
                                    : null,
                                onTap: () {
                                  HelloColors.setThemeMode(mode);
                                  Navigator.pop(ctx);
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
