import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../theme.dart';

Future<void> openAttachmentSheet(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'AttachmentSheet',
    barrierColor: Colors.black.withValues(alpha: 0.28),
    transitionDuration: Duration(milliseconds: 320),
    pageBuilder: (_, _, _) {
      return Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: SizedBox.expand(),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _AttachmentSheet(),
          ),
        ],
      );
    },
    transitionBuilder: (_, animation, _, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0, 0.06),
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

class _AttachmentSheet extends StatelessWidget {
  _AttachmentSheet();

  static final _attachments = [
    ('Camera', Icons.photo_camera_rounded, 0xFF8B5CF6),
    ('Photos', Icons.photo_library_rounded, 0xFFFF9B6E),
    ('Location', Icons.location_on_rounded, 0xFF10B981),
    ('Document', Icons.insert_drive_file_rounded, 0xFF4A90E2),
    ('Voice', Icons.mic_rounded, 0xFFFF385C),
    ('Contact', Icons.person_rounded, 0xFF14B8A6),
  ];

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.5;
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
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
              SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 18),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ATTACH',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 1.8,
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
              SizedBox(height: 24),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.95,
                    children: [
                      for (final (label, icon, colorHex) in _attachments)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            decoration: BoxDecoration(
                              color: HelloColors.recessed,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.04),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Color(colorHex).withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    icon,
                                    size: 22,
                                    color: Color(colorHex),
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: HelloColors.inkPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
