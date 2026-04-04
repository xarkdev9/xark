import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../animations/spring_curves.dart';
import '../theme.dart';

/// Liquid Chat Composer — premium E2EE input with AI morph.
///
/// Zero-Box: No borders. Ambient glow via BoxShadow(blurRadius:40, spread:0).
/// No-Bold: Input text w400, hint w300.
/// Liquid Physics: AnimatedContainer color morph on @hello detection.
/// AI Morph: Accent glow (#D4536B) when @hello/@xark detected + haptic.

class LiquidChatComposer extends StatefulWidget {
  final ValueChanged<String> onSend;
  final String aiTrigger;

  const LiquidChatComposer({
    super.key,
    required this.onSend,
    this.aiTrigger = '@hello',
  });

  @override
  State<LiquidChatComposer> createState() => _LiquidChatComposerState();
}

class _LiquidChatComposerState extends State<LiquidChatComposer>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isAIMode = false;
  bool _hasText = false;

  // Max lines before internal scroll
  static const int _maxExpandLines = 6;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    final lower = text.toLowerCase();
    final aiDetected = lower.contains(widget.aiTrigger.toLowerCase()) ||
        lower.contains('@xark');

    if (aiDetected != _isAIMode) {
      setState(() => _isAIMode = aiDetected);
      if (aiDetected) {
        HapticFeedback.lightImpact();
      }
    }

    final hasText = text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.selectionClick();
    widget.onSend(text);
    _controller.clear();
    setState(() {
      _isAIMode = false;
      _hasText = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: SpringCurve.gentle,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: _isAIMode
              ? HelloColors.accent.withOpacity(0.06)
              : HelloColors.inkPrimary.withOpacity(0.03),
          // Liquid glow — ambient shadow, no hard border
          boxShadow: [
            BoxShadow(
              color: _isAIMode
                  ? HelloColors.accent.withOpacity(0.15)
                  : HelloColors.inkPrimary.withOpacity(0.04),
              blurRadius: 40,
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Attachment button
                  GestureDetector(
                    onTap: () => HapticFeedback.selectionClick(),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          Icons.add_rounded,
                          size: 22,
                          color: _isAIMode
                              ? HelloColors.accent.withOpacity(0.6)
                              : HelloColors.inkPrimary.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Text input — expands vertically, no border
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 36,
                        maxHeight: 36.0 * _maxExpandLines, // ~6 lines max
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        maxLines: null, // Unlimited expansion
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w400, // No-Bold
                          color: HelloColors.inkPrimary.withOpacity(0.85),
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 8),
                          hintText: _isAIMode
                              ? 'ask ${widget.aiTrigger}...'
                              : 'message...',
                          hintStyle: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w300, // No-Bold: secondary
                            color: _isAIMode
                                ? HelloColors.accent.withOpacity(0.4)
                                : HelloColors.inkPrimary.withOpacity(0.25),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send / @hello button — morphs between states
                  GestureDetector(
                    onTap: _hasText
                        ? _handleSend
                        : () {
                            // Idle tap → insert @hello trigger
                            _controller.text = '${widget.aiTrigger} ';
                            _controller.selection = TextSelection.fromPosition(
                              TextPosition(offset: _controller.text.length),
                            );
                            _focusNode.requestFocus();
                          },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _hasText
                            ? Text(
                                'send',
                                key: const ValueKey('send'),
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.06 * 14,
                                  color: HelloColors.accent,
                                ),
                              )
                            : _HelloOrb(key: const ValueKey('hello')),
                      ),
                    ),
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

/// Breathing Liquid Fire orb — the AI presence indicator
class _HelloOrb extends StatefulWidget {
  const _HelloOrb({super.key});

  @override
  State<_HelloOrb> createState() => _HelloOrbState();
}

class _HelloOrbState extends State<_HelloOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final scale = 0.9 + (t * 0.2); // 0.9 → 1.1
        final glowAlpha = 0.15 + (t * 0.25); // 0.15 → 0.4

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: HelloColors.liquidFireStandard,
              boxShadow: [
                BoxShadow(
                  color: HelloColors.accent.withValues(alpha: glowAlpha),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              'h',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
        );
      },
    );
  }
}
