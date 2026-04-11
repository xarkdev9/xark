import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/focus_provider.dart';
import '../../../providers/tabs_provider.dart';
import '../../../theme.dart';
import 'tab_chip.dart';
import 'tab_popover.dart';

/// The bottom glass pill. Layout (left → right):
///   [TabChip]   Search text field   mic/send   [+]
///
/// Mic morphs into a send arrow when text is present. `+` is the
/// compose button tinted by the focus trip's accent color.
class BottomBar extends ConsumerStatefulWidget {
  final void Function(int index) onTabSelected;
  final VoidCallback onSearchSubmit;
  final VoidCallback onComposeTap;

  const BottomBar({
    super.key,
    required this.onTabSelected,
    required this.onSearchSubmit,
    required this.onComposeTap,
  });

  @override
  ConsumerState<BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends ConsumerState<BottomBar> {
  final GlobalKey _chipKey = GlobalKey();
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(_handleTextChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChange() {
    final next = _controller.text.isNotEmpty;
    if (next != _hasText) {
      setState(() => _hasText = next);
    }
  }

  Future<void> _openPopover() async {
    final activeIndex = ref.read(activeTabIndexProvider);
    final selected = await showTabPopover(
      context,
      anchorKey: _chipKey,
      activeIndex: activeIndex,
    );
    if (selected != null && selected != activeIndex) {
      widget.onTabSelected(selected);
    }
  }

  void _handleSend() {
    widget.onSearchSubmit();
    _controller.clear();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(activeTabProvider);
    final focus = ref.watch(focusTripProvider);
    final composeAccent = focus?.accentColor ?? HelloColors.accent;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: Colors.white.withValues(alpha: 0.92),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.08),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  KeyedSubtree(
                    key: _chipKey,
                    child: TabChip(onTap: _openPopover),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLines: 1,
                      cursorColor: HelloColors.inkPrimary,
                      cursorWidth: 1,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: HelloColors.inkPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: tab.searchHint,
                        hintStyle: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w300,
                          color: HelloColors.inkTertiary,
                        ),
                        isDense: true,
                        isCollapsed: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: animation,
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    child: _hasText
                        ? _CircleButton(
                            key: const ValueKey<String>('send'),
                            icon: Icons.arrow_upward_rounded,
                            onTap: _handleSend,
                            background: composeAccent,
                            iconColor: const Color(0xFFF0EFF4),
                          )
                        : _CircleButton(
                            key: const ValueKey<String>('mic'),
                            icon: Icons.mic_none_rounded,
                            onTap: () {},
                            background: HelloColors.recessed,
                            iconColor: HelloColors.inkSecondary,
                          ),
                  ),
                  const SizedBox(width: 8),
                  _CircleButton(
                    icon: Icons.add,
                    onTap: widget.onComposeTap,
                    background: HelloColors.recessed,
                    iconColor: composeAccent,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color background;
  final Color iconColor;

  const _CircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.background,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }
}
