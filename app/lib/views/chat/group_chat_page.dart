import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../physics/portal_page_route.dart';
import '../plan/plan_dashboard_page.dart';

class GroupChatPage extends StatelessWidget {
  const GroupChatPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HelloColors.voidBg,
      body: Stack(
        children: [
          // Simulated Aurora Bridge Header wrapped in a Hero + GestureDetector
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  PortalPageRoute(page: const PlanDashboardPage()),
                );
              },
              child: Hero(
                tag: 'aurora_mesh',
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [HelloColors.voidBg, const Color(0xFF22C55E)], // calm aurora
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  child: ClipRRect(
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text('Swiss Trip', style: HelloText.title),
                ),
                Text('Tap the Aurora to enter the Void', style: HelloText.label),
                const Spacer(),
                // Composer
                Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: HelloColors.surfaceDeep,
                    borderRadius: BorderRadius.circular(9999), // Pill
                  ),
                  child: Row(
                    children: [
                      Text('ask @hello anything...', style: HelloText.body.copyWith(color: HelloColors.inkSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
