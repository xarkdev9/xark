import 'package:flutter/material.dart';
import '../../theme.dart';

class GroupMediaGalleryPage extends StatelessWidget {
  const GroupMediaGalleryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Pure black for immersive media
      body: Stack(
        children: [
          // Simulated full-bleed media gallery view
          Center(
            child: Text('Immersive Media', style: HelloText.body.copyWith(color: HelloColors.inkTertiary)),
          ),
          Positioned(
            bottom: 40,
            left: 24,
            child: Text('The Echo', style: HelloText.title),
          ),
        ],
      ),
    );
  }
}
