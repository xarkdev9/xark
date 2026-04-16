import 'package:flutter/material.dart';

import '../../../theme.dart';
import 'plasma/plasma.dart';

/// iMessage-style compose bar: circular `+` button on left, rounded
/// text field in the middle, and a right-side button that morphs
/// between a mic icon (empty) and a send arrow (text present).
///
/// The caller wraps this widget in whatever outer chrome (glass
/// pill, sheet footer, etc.). This widget owns its own
/// [TextEditingController] and [FocusNode].
class MessageInputBar extends StatefulWidget {
  final String hintText;
  final VoidCallback onPlusTap;
  final void Function(String) onSend;
  final VoidCallback? onMicTap;
  final bool autofocus;

  const MessageInputBar({
    super.key,
    required this.hintText,
    required this.onPlusTap,
    required this.onSend,
    this.onMicTap,
    this.autofocus = false,
  });

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
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

  void _handleSend() {
    final text = _controller.text;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _CircleButton(
          icon: Icons.add,
          onTap: widget.onPlusTap,
          background: HelloColors.recessed,
          iconColor: HelloColors.inkSecondary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: HelloColors.recessed,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
            alignment: Alignment.centerLeft,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: widget.autofocus,
              minLines: 1,
              maxLines: 4,
              cursorColor: HelloColors.inkPrimary,
              cursorWidth: 1,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: HelloColors.inkPrimary,
                height: 1.25,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w300,
                  color: HelloColors.inkTertiary,
                  height: 1.25,
                ),
                isDense: true,
                isCollapsed: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSend(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: _hasText
              ? _PlasmaCircleButton(
                  key: const ValueKey<String>('send'),
                  icon: Icons.arrow_upward_rounded,
                  onTap: _handleSend,
                  iconColor: const Color(0xFFF0EFF4),
                )
              : _CircleButton(
                  key: const ValueKey<String>('mic'),
                  icon: Icons.mic_none_rounded,
                  onTap: widget.onMicTap ?? () {},
                  background: HelloColors.recessed,
                  iconColor: HelloColors.inkSecondary,
                ),
        ),
      ],
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
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }
}

/// 32x32 circle button whose fill is animated plasma. Used for the
/// primary send arrow inside message sheets.
class _PlasmaCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;

  const _PlasmaCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: PlasmaFill(
        shape: BoxShape.circle,
        width: 32,
        height: 32,
        child: Center(child: Icon(icon, size: 18, color: iconColor)),
      ),
    );
  }
}
