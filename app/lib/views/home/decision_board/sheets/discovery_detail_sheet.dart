import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../theme.dart';
import '../../../../utils/haptics.dart';
import '../plasma/plasma.dart';

/// Opens a discovery detail sheet using the same showGeneralDialog pattern
/// as dm_sheet.dart and decision_sheet.dart.
Future<void> openDiscoveryDetailSheet(
  BuildContext context, {
  required String title,
  String? imageUrl,
  String? description,
  String? location,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'DiscoveryDetailSheet',
    barrierColor: Colors.black.withValues(alpha: 0.28),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, __, ___) {
      return Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: HelloGlass.whisperSigma,
                sigmaY: HelloGlass.whisperSigma,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _DiscoveryDetailSheet(
              title: title,
              imageUrl: imageUrl,
              description: description,
              location: location,
            ),
          ),
        ],
      );
    },
    transitionBuilder: (_, animation, __, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
  );
}

class _DiscoveryDetailSheet extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final String? description;
  final String? location;

  const _DiscoveryDetailSheet({
    required this.title,
    this.imageUrl,
    this.description,
    this.location,
  });

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.92;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: HelloGlass.curtainSigma,
          sigmaY: HelloGlass.curtainSigma,
        ),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: HelloColors.voidBg.withValues(alpha: 0.94),
            border: Border(
              top: BorderSide(
                color: Colors.black.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                // Close button row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'DISCOVER',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.5,
                            color: HelloColors.inkTertiary,
                          ),
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: HelloColors.recessed,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: HelloColors.inkSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Scrollable body
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      // Hero image
                      if (imageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AspectRatio(
                            aspectRatio: 16 / 10,
                            child: Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: HelloColors.recessed,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.image_outlined,
                                  size: 40,
                                  color: HelloColors.inkTertiary,
                                ),
                              ),
                              loadingBuilder: (_, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  color: HelloColors.recessed,
                                  alignment: Alignment.center,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: HelloColors.inkTertiary,
                                  ),
                                );
                              },
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 180,
                          decoration: BoxDecoration(
                            color: HelloColors.recessed,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.image_outlined,
                            size: 48,
                            color: HelloColors.inkTertiary,
                          ),
                        ),
                      const SizedBox(height: 20),
                      // Title
                      Text(title, style: HelloText.title),
                      // Location
                      if (location != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.place_outlined,
                              size: 14,
                              color: HelloColors.inkSecondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                location!,
                                style: HelloText.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      // Description
                      if (description != null) ...[
                        const SizedBox(height: 16),
                        Text(description!, style: HelloText.body),
                      ],
                      // @hello says section
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: HelloColors.recessed,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '@hello says',
                              style: HelloText.label.copyWith(
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'AI summary will appear here',
                              style: HelloText.caption.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Add to Group CTA
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HelloHaptic.tap();
                          Navigator.of(context).pop();
                        },
                        child: PlasmaFill(
                          borderRadius: BorderRadius.circular(14),
                          height: 52,
                          child: const Center(
                            child: Text(
                              'Add to Group',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
