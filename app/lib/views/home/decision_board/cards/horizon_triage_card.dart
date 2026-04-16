import 'package:flutter/material.dart';
import '../../../../../theme.dart';
import '../avatar_utils.dart';
import '_card_shell.dart';

class HorizonTriageCard extends StatelessWidget {
  final Key? key;
  final String name;
  final String avatarPath;
  
  const HorizonTriageCard({
    this.key,
    required this.name,
    required this.avatarPath,
  });

  @override
  Widget build(BuildContext context) {
    return CardShell(
      id: '0',
      padding: const EdgeInsets.all(28.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            children: [
              HologramAvatar(avatarPath: avatarPath, size: 56),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MORNING BRIEF', style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w400, letterSpacing: 1.2, color: HelloColors.inkTertiary)),
                    const SizedBox(height: 4),
                    Text('Good morning, $name.', style: TextStyle(fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.w400, letterSpacing: -0.5, color: HelloColors.inkPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          Text('YOUR ACTIVE HORIZON', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: 0.8, color: HelloColors.inkSecondary)),
          const SizedBox(height: 16),
          _buildActionItem(Icons.how_to_vote, 'Sarah and Alex ignited the Bali Hotel vote.', 'Your vote breaks the tie. Tap to resolve.'),
          const SizedBox(height: 12),
          _buildActionItem(Icons.flight_takeoff, 'Flights to Tokyo lock in 4 hours.', 'Missing passport scans for 2 members.'),
          const SizedBox(height: 12),
          _buildActionItem(Icons.attach_money, 'You owe Maya \$120 for Airbnb deposit.', 'Pending in College Crew space.'),
        ],
        ),
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: HelloColors.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w400, color: HelloColors.inkPrimary, height: 1.3)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w400, color: HelloColors.inkSecondary, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }
}
