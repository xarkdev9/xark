import 'package:flutter/material.dart';

String getAvatarImagePath(String name, {bool isGroup = false}) {
  final lower = name.toLowerCase();

  // Explicit manual overrides
  if (lower == 'ram') return 'assets/images/ram_avatar.png';
  if (lower == 'james') return 'assets/images/james_avatar.png';
  if (lower == 'sarah') return 'assets/images/sarah_avatar.png';
  if (lower == 'maya') return 'assets/images/maya_avatar.png';
  if (lower == 'family chat' || lower == 'family') return 'assets/images/cousins_group.png';
  if (lower == 'college crew') return 'assets/images/friends_group.png';
  if (lower == 'trip 2027' || lower == 'bali trip') return 'assets/images/travel_group.png';
  if (lower == 'ali') return 'assets/images/c1.png';
  if (lower == 'alex') return 'assets/images/wc1.png';

  // Deterministic auto-assignments for unknown profiles (Zero-Box)
  int hash = name.hashCode.abs();
  if (isGroup) {
    const groups = [
      'assets/images/cousins_group.png',
      'assets/images/friends_group.png',
      'assets/images/travel_group.png',
    ];
    return groups[hash % groups.length];
  } else {
    const singles = [
      'assets/images/ram_avatar.png',
      'assets/images/james_avatar.png',
      'assets/images/sarah_avatar.png',
      'assets/images/maya_avatar.png',
      'assets/images/c1.png',
      'assets/images/wc1.png',
    ];
    return singles[hash % singles.length];
  }
}

class HologramAvatar extends StatelessWidget {
  final String avatarPath;
  final double? size;
  
  const HologramAvatar({
    super.key, 
    required this.avatarPath, 
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Colors.white,
            Colors.white,
            Colors.transparent, // Architectural guillotine dissolve
          ],
          stops: [0.0, 0.5, 0.85, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: Image.asset(
        avatarPath,
        fit: BoxFit.contain,
        width: size,
        height: size,
        // Defensive: if the asset is missing (e.g. a new avatar
        // name added to getAvatarImagePath without a corresponding
        // PNG), render a constrained transparent box instead of
        // Flutter's unconstrained red error-text placeholder, which
        // would blow out its parent and trigger RenderFlex overflow.
        errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
      ),
    );
  }
}
