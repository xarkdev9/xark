import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../theme.dart';

/// Zero-Box Chat Bubble with smart corner radii, receipt morphing,
/// and swipe-to-reply spring physics.
///
/// Zero-Box: Flat backgrounds (#EF7C6E sent, #E8E3DD received). No shadows.
/// No-Bold: Text at w400, timestamp at w300.
/// Smart Corners: Consecutive same-sender messages reduce inner radius to 4.
/// Receipt Morph: AnimatedSwitcher(300ms) for fluid tick transitions.
/// Swipe Physics: Horizontal drag → SpringSimulation snap-back.

class ChatBubble extends StatefulWidget {
  final String text;
  final bool isOutbound;
  final MessageStatus status;
  final bool isFirstInGroup;  // First message from this sender in sequence
  final bool isLastInGroup;   // Last message from this sender in sequence
  final Widget? mediaChild;   // EncryptedImageView nests here
  final String? timestamp;
  final bool showReceipt;
  final VoidCallback? onReply;

  const ChatBubble({
    super.key,
    required this.text,
    required this.isOutbound,
    this.status = MessageStatus.sent,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.mediaChild,
    this.timestamp,
    this.showReceipt = false,
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

  static const double _replyThreshold = 60.0;
  static const double _dragResistance = 0.35;

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

  Widget _buildReceiptIcon() {
    if (!widget.isOutbound) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.6, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: _receiptIcon(),
    );
  }

  Widget _receiptIcon() {
    switch (widget.status) {
      case MessageStatus.sending:
        return Icon(
          Icons.access_time,
          key: const ValueKey('sending'),
          size: 13,
          color: HelloColors.inkTertiary.withValues(alpha: 0.5),
        );
      case MessageStatus.sent:
        return Icon(
          Icons.check,
          key: const ValueKey('sent'),
          size: 13,
          color: HelloColors.inkTertiary.withValues(alpha: 0.5),
        );
      case MessageStatus.delivered:
        return Icon(
          Icons.done_all,
          key: const ValueKey('delivered'),
          size: 13,
          color: HelloColors.inkTertiary.withValues(alpha: 0.5),
        );
      case MessageStatus.read:
        return const Icon(
          Icons.done_all,
          key: ValueKey('read'),
          size: 13,
          color: Color(0xFFD4536B), // Rose accent for read
        );
      case MessageStatus.failed:
        return Icon(
          Icons.error_outline,
          key: const ValueKey('failed'),
          size: 13,
          color: HelloColors.errorOrange.withValues(alpha: 0.8),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Bubble colors matching web CSS variables (globals.css)
    const sentColor = Color(0xFFF0F0F0);     // --hello-bubble-sent
    const receivedColor = Color(0xFFFFFFFF);  // --hello-bubble-received
    final bgColor = widget.isOutbound ? sentColor : receivedColor;

    // Tighter vertical spacing for grouped messages
    final topMargin = widget.isFirstInGroup ? 8.0 : 2.0;
    final bottomMargin = widget.isLastInGroup ? 8.0 : 2.0;

    return GestureDetector(
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

          // The bubble + timestamp below
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: Align(
              alignment: widget.isOutbound
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: widget.isOutbound
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.68,
                  ),
                  margin: EdgeInsets.only(
                    top: topMargin,
                    bottom: 0,
                    left: 16,
                    right: 16,
                  ),
                  padding: widget.mediaChild != null
                      ? EdgeInsets.zero
                      : const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: _buildCornerRadii(),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.06),
                      width: 0.5,
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
                // Timestamp + receipt BELOW the bubble (iMessage style)
                _buildTimestampRow(),
                SizedBox(height: bottomMargin),
              ],
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

  /// Timestamp + receipt shown BELOW the bubble, not inside
  Widget _buildTimestampRow() {
    if (widget.timestamp == null && !widget.showReceipt) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(
        top: 2,
        left: widget.isOutbound ? 0 : 20,
        right: widget.isOutbound ? 20 : 0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: widget.isOutbound
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (widget.timestamp != null)
            Text(
              widget.timestamp!,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w300,
                color: HelloColors.inkTertiary.withValues(alpha: 0.5),
              ),
            ),
          if (widget.showReceipt && widget.isOutbound) ...[
            const SizedBox(width: 3),
            _buildReceiptIcon(),
          ],
        ],
      ),
    );
  }
}
