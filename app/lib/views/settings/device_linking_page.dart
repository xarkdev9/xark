import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../theme.dart';
import '../../utils/haptics.dart';

class DeviceLinkingPage extends StatefulWidget {
  const DeviceLinkingPage({super.key});

  @override
  State<DeviceLinkingPage> createState() => _DeviceLinkingPageState();
}

class _DeviceLinkingPageState extends State<DeviceLinkingPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );
  bool _isScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanned) return;
    if (capture.barcodes.isEmpty) return;

    setState(() => _isScanned = true);
    HelloHaptic.celebrate();

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen camera
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
          ),
          // Viewfinder mask overlay
          Positioned.fill(
            child: ClipPath(
              clipper: _ViewfinderClipper(),
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.7),
              ),
            ),
          ),
          // Viewfinder border
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
            ),
          ),
          // Scanned success overlay
          if (_isScanned)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 64,
                    color: HelloColors.liveGreen,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Device linked',
                    style: HelloText.body.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          // Instruction text below viewfinder
          if (!_isScanned)
            Positioned(
              left: 40,
              right: 40,
              bottom: MediaQuery.of(context).size.height * 0.5 - 125 - 60,
              child: Text(
                'Point camera at the QR code on your other device',
                textAlign: TextAlign.center,
                style: HelloText.small.copyWith(color: Colors.white),
              ),
            ),
          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewfinderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final center = Offset(size.width / 2, size.height / 2);
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 250, height: 250),
      const Radius.circular(24),
    ));
    path.fillType = PathFillType.evenOdd;
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
