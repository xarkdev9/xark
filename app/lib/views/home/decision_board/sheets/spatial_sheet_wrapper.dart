import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../../theme.dart';
import '../avatar_utils.dart';

class SpatialSheetWrapper extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? avatarInitial;
  final Widget Function(ScrollController scrollController) bodyBuilder;
  final Widget? footer;

  const SpatialSheetWrapper({
    super.key,
    required this.title,
    this.subtitle,
    this.avatarInitial,
    required this.bodyBuilder,
    this.footer,
  });

  @override
  State<SpatialSheetWrapper> createState() => _SpatialSheetWrapperState();
}

class _SpatialSheetWrapperState extends State<SpatialSheetWrapper> {
  late final ScrollController _scrollController;
  bool _isScrolledTop = false;
  bool _isScrolledBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onScroll();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final max = _scrollController.position.maxScrollExtent;
    final nextTop = offset > 0;
    final nextBottom = offset < max - 0.5;
    if (nextTop != _isScrolledTop || nextBottom != _isScrolledBottom) {
      setState(() {
        _isScrolledTop = nextTop;
        _isScrolledBottom = nextBottom;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.92;
    // CRITICAL: Keyboard awareness
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Material(
        color: HelloColors.voidBg, 
        child: SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // LAYER 1: Body
              Positioned.fill(
                bottom: bottomInset,
                child: RepaintBoundary(
                  child: widget.bodyBuilder(_scrollController),
                ),
              ),

              // LAYER 2: Glass Header
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ClipRect(
                  child: Container(
                      color: HelloColors.voidBg.withValues(alpha: 0.65),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 10),
                          Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: HelloColors.inkTertiary.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (widget.avatarInitial != null) ...[
                                  HologramAvatar(
                                    avatarPath: getAvatarImagePath(widget.title),
                                    size: 44,
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        widget.title,
                                        style: TextStyle(
                                          fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.w400, letterSpacing: -0.3, color: HelloColors.inkPrimary, decoration: TextDecoration.none
                                        ),
                                      ),
                                      if (widget.subtitle != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          widget.subtitle!,
                                          style: TextStyle(
                                            fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w300, color: HelloColors.inkSecondary, decoration: TextDecoration.none
                                          ),
                                        ),
                                      ],
                                    ],
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
                                    child: Icon(Icons.close_rounded, size: 18, color: HelloColors.inkSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),,
              ),

              // LAYER 3: Glass Footer (padded by keyboard)
              if (widget.footer != null)
                Positioned(
                  bottom: bottomInset,
                  left: 0,
                  right: 0,
                  child: ClipRect(
                    child: Container(
                        color: HelloColors.voidBg.withValues(alpha: 0.65),
                        child: widget.footer!, 
                      ),
                    ),,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
