import 'package:flutter/material.dart';
import '../../../../theme.dart';

class XRMediaViewer extends StatelessWidget {
  final String imageUrl;

  const XRMediaViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Simulated parallax depth map effect wrapper
          InteractiveViewer(
            panEnabled: true,
            minScale: 1.0,
            maxScale: 3.0,
            child: imageUrl.startsWith('http')
                ? Image.network(imageUrl, fit: BoxFit.contain)
                : Image.asset(imageUrl, fit: BoxFit.contain),
          ),
          Positioned(
            bottom: 48,
            left: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('Spotted via Magic Drop', style: TextStyle(fontFamily: 'Inter', color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
