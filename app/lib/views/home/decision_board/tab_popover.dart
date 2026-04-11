import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../providers/tabs_provider.dart';
import '../../../theme.dart';

/// Shows a glass popover above the given [anchorKey]'s render box
/// with 4 tab rows. Returns the selected tab index (0-3) or null if
/// dismissed without selection.
Future<int?> showTabPopover(
  BuildContext context, {
  required GlobalKey anchorKey,
  required int activeIndex,
}) async {
  final anchorContext = anchorKey.currentContext;
  if (anchorContext == null) return null;
  final renderBox = anchorContext.findRenderObject() as RenderBox?;
  if (renderBox == null) return null;

  final anchorOffset = renderBox.localToGlobal(Offset.zero);

  return showGeneralDialog<int?>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'TabPopover',
    barrierColor: Colors.black.withValues(alpha: 0.04),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, _, _) {
      return Stack(
        children: [
          Positioned(
            left: anchorOffset.dx,
            top: anchorOffset.dy - 216,
            width: 200,
            child: _TabPopoverCard(activeIndex: activeIndex),
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
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          alignment: Alignment.bottomLeft,
          child: child,
        ),
      );
    },
  );
}

class _TabPopoverCard extends StatelessWidget {
  final int activeIndex;
  const _TabPopoverCard({required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.06),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < HomeTab.values.length; i++)
                _TabRow(
                  tab: HomeTab.values[i],
                  isActive: i == activeIndex,
                  onTap: () => Navigator.of(context).pop(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabRow extends StatelessWidget {
  final HomeTab tab;
  final bool isActive;
  final VoidCallback onTap;
  const _TabRow({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: tab.signatureColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(
                tab.icon,
                size: 16,
                color: tab.signatureColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                tab.titleCase,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: HelloColors.inkPrimary,
                ),
              ),
            ),
            if (isActive)
              Icon(
                Icons.check_rounded,
                size: 16,
                color: tab.signatureColor,
              ),
          ],
        ),
      ),
    );
  }
}
