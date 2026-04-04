import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../theme.dart';

/// Glassmorphic Chat Bubble with avatars, haptic scale, smart corner radii,
/// and swipe-to-reply spring physics.
///
/// Glassmorphism: Asymmetric backdrop blur (outbound 20σ, inbound 8σ).
/// No-Bold: Text at w400, sender name at w300.
/// Smart Corners: Consecutive same-sender messages reduce inner radius to 4.
/// Haptic Scale: Long-press scales to 0.98 with mediumImpact feedback.
/// Swipe Physics: Horizontal drag → SpringSimulation snap-back.

class ChatBubble extends StatefulWidget {
  final String text;
  final bool isOutbound;
  final MessageStatus status;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final Widget? mediaChild;
  final String? senderId;
  final VoidCallback? onReply;

  const ChatBubble({
    super.key,
    required this.text,
    required this.isOutbound,
    this.status = MessageStatus.sent,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.mediaChild,
    this.senderId,
    this.onReply,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dragController;
  double _dragOffset = 0;
  bool _replyTriggered = false;
  String? _reaction; // Selected emoji reaction
  bool _showReactionPicker = false;

  static const double _replyThreshold = 60.0;
  static const double _dragResistance = 0.35;

  static const _reactionEmojis = ['❤️', '😂', '👍', '😮', '🔥'];

  // Map raw user IDs to display names
  static const _senderNames = <String, String>{
    'user_0': 'Sarah',
    'user_1': 'Alex',
    'user_2': 'Maya',
    'user_3': 'Jordan',
    'user_4': 'Chris',
    'user_x': 'Kim',
    'priya': 'Priya',
    'dad': 'Dad',
    'emma': 'Emma',
    'alex': 'Alex',
    'liam': 'Liam',
    'noah': 'Noah',
    'sofia': 'Sofia',
    'maya': 'Maya',
  };

  String _displayName(String? id) => _senderNames[id?.toLowerCase()] ?? id ?? '?';

  double _pressScale = 1.0;

  // Spring for snap-back: high stiffness, moderate damping
  static final SpringDescription _snapSpring = SpringDescription(
    mass: 1.0,
    stiffness: 600.0,
    damping: 28.0,
  );

  @override
  void initState() {
    super.initState();
    _dragController = AnimationController.unbounded(vsync: this);
    _dragController.addListener(() {
      setState(() => _dragOffset = _dragController.value);
    });
  }

  @override
  void dispose() {
    _dragController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    // Only allow left drag (negative delta) for reply
    final newOffset = (_dragOffset + details.delta.dx * _dragResistance)
        .clamp(-120.0, 0.0);
    _dragController.value = newOffset;

    // Check threshold
    if (!_replyTriggered && newOffset.abs() >= _replyThreshold) {
      _replyTriggered = true;
      HapticFeedback.heavyImpact();
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_replyTriggered) {
      widget.onReply?.call();
    }
    _replyTriggered = false;

    // Spring snap-back to 0
    final simulation = SpringSimulation(_snapSpring, _dragOffset, 0, 0);
    _dragController.animateWith(simulation);
  }

  // Smart corner radii based on grouping
  BorderRadius _buildCornerRadii() {
    const outer = Radius.circular(20.0);
    const inner = Radius.circular(4.0);

    if (widget.isOutbound) {
      return BorderRadius.only(
        topLeft: outer,
        topRight: widget.isFirstInGroup ? outer : inner,
        bottomLeft: outer,
        bottomRight: widget.isLastInGroup ? inner : inner,
      );
    } else {
      return BorderRadius.only(
        topLeft: widget.isFirstInGroup ? outer : inner,
        topRight: outer,
        bottomLeft: widget.isLastInGroup ? inner : inner,
        bottomRight: outer,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Asymmetric glassmorphism
    final bubbleOpacity = widget.isOutbound ? 0.6 : 0.85;
    final blurSigma = widget.isOutbound ? 20.0 : 8.0;

    // Tighter vertical spacing for grouped messages
    final topMargin = widget.isFirstInGroup ? 8.0 : 2.0;
    final bottomMargin = widget.isLastInGroup ? 8.0 : 2.0;

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        setState(() {
          _pressScale = 0.98;
          _showReactionPicker = !_showReactionPicker;
        });
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _pressScale = 1.0);
        });
      },
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Reply indicator (appears behind bubble on drag)
          if (_dragOffset < -10)
            Positioned(
              right: widget.isOutbound ? 0 : null,
              left: widget.isOutbound ? null : 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: Opacity(
                  opacity: (_dragOffset.abs() / _replyThreshold).clamp(0.0, 1.0),
                  child: Icon(
                    Icons.reply_rounded,
                    size: 20,
                    color: HelloColors.inkPrimary.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),

          // The bubble + reactions
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: Align(
              alignment: widget.isOutbound
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Transform.scale(
                scale: _pressScale,
                child: Column(
                  crossAxisAlignment: widget.isOutbound
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    // Sender name for incoming group messages
                    if (!widget.isOutbound && widget.isFirstInGroup && widget.senderId != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 20, bottom: 3),
                        child: Text(
                          _displayName(widget.senderId),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w300,
                            color: HelloColors.inkTertiary,
                          ),
                        ),
                      ),

                    // Glass bubble (no inline avatars — iMessage style)
                    Flexible(
                          child: Padding(
                            padding: EdgeInsets.only(
                              top: topMargin,
                              left: widget.isOutbound ? 48 : 16,
                              right: widget.isOutbound ? 16 : 48,
                            ),
                            child: ClipRRect(
                              borderRadius: _buildCornerRadii(),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.68,
                                  ),
                                  padding: widget.mediaChild != null
                                      ? EdgeInsets.zero
                                      : const EdgeInsets.fromLTRB(12, 8, 12, 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: bubbleOpacity),
                                    borderRadius: _buildCornerRadii(),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: widget.mediaChild != null
                                      ? ClipRRect(
                                          borderRadius: _buildCornerRadii(),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              widget.mediaChild!,
                                              if (widget.text.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                                                  child: _buildTextContent(),
                                                ),
                                            ],
                                          ),
                                        )
                                      : _buildTextContent(),
                                ),
                              ),
                            ),
                          ),
                        ),
                    // Reaction display (selected emoji floats below bubble)
                    if (_reaction != null)
                      Padding(
                        padding: EdgeInsets.only(
                          left: widget.isOutbound ? 0 : 16,
                          right: widget.isOutbound ? 16 : 0,
                        ),
                        child: Transform.translate(
                          offset: const Offset(0, -6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Text(_reaction!, style: const TextStyle(fontSize: 16)),
                          ),
                        ),
                      ),

                    // Reaction picker (floating emoji row on long press)
                    if (_showReactionPicker)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: _reactionEmojis.map((emoji) =>
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  setState(() {
                                    _reaction = emoji;
                                    _showReactionPicker = false;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                                ),
                              ),
                            ).toList(),
                          ),
                        ),
                      ),

                    SizedBox(height: bottomMargin),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextContent() {
    // Clean text only — no timestamp inside bubble (iMessage style)
    return Text(
      widget.text,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: HelloColors.inkPrimary.withValues(alpha: 0.9),
        height: 1.35,
      ),
    );
  }
}
