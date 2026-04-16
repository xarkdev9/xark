import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme.dart';
import 'profile_edit.dart';
import 'device_list.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Zero-Box Doctrine: Pure color background, no borders on the Scaffold.
    return Scaffold(
      backgroundColor: HelloColors.voidBg,
      body: Stack(
        children: [
          // The Header: Massive blurred avatar acting as a top-fade background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.35,
            child: ShaderMask(
              shaderCallback: (rect) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, Colors.transparent],
                ).createShader(rect);
              },
              blendMode: BlendMode.dstIn,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: HelloColors.inkSecondary.withValues(alpha: 0.2), // Mock abstract avatar color
                  ),
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 40.0, sigmaY: 40.0),
                    child: Container(color: Colors.transparent),
                  ),
                ],
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top navigation bar for dismissing the sheet/page
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down, size: 32, color: HelloColors.inkPrimary),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      style: const ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Floating user display name
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    "Ram Chitturi", // Mocked
                    style: HelloTypography.hero,
                  ),
                ),
                
                const SizedBox(height: 64),
                
                // The Menu: Vertical column of typographic buttons
                // Zero-Box Rule: No ListTile, no trailing arrows, no dividers.
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    children: [
                      _buildMenuItem(context, "Edit Profile", onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const ProfileEditPage(),
                        ));
                      }),
                      const SizedBox(height: 32),
                      _buildMenuItem(context, "Linked Devices", onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const DeviceListPage(),
                        ));
                      }),
                      const SizedBox(height: 32),
                      _buildMenuItem(context, "Privacy", onTap: () {}),
                      const SizedBox(height: 32),
                      _buildMenuItem(context, "Appearance", onTap: () {}),
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, String title, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        title,
        style: HelloTypography.spaceTitle.copyWith(
          color: HelloColors.inkPrimary,
        ),
      ),
    );
  }
}
