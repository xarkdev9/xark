import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';

Future<void> openDmSheet(BuildContext context, DmFeedItem item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DmSheet(item: item),
  );
}

class _DmSheet extends StatelessWidget {
  final DmFeedItem item;
  const _DmSheet({required this.item});

  String _displayName() {
    final id = item.conversation.id;
    if (id.isEmpty) return 'Unknown';
    return '${id[0].toUpperCase()}${id.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final name = _displayName();
    final messages = <_MockMessage>[
      _MockMessage(
        text: item.conversation.lastMessageText ?? 'hey',
        fromMe: false,
      ),
      const _MockMessage(
        text: 'Looks unreal. Which hotel are you leaning toward?',
        fromMe: true,
      ),
      const _MockMessage(
        text: 'Probably Alila. Price is painful though.',
        fromMe: false,
      ),
    ];

    return _SheetShell(
      eyebrow: 'DIRECT MESSAGE',
      title: name,
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        itemCount: messages.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _MessageBubble(msg: messages[i]),
      ),
      footer: _ReplyInput(hint: 'Reply to $name'),
    );
  }
}

class _MockMessage {
  final String text;
  final bool fromMe;
  const _MockMessage({required this.text, required this.fromMe});
}

class _MessageBubble extends StatelessWidget {
  final _MockMessage msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: msg.fromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: msg.fromMe
              ? HelloColors.accent.withValues(alpha: 0.22)
              : HelloColors.recessed,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          msg.text,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.35,
            color: HelloColors.inkPrimary,
          ),
        ),
      ),
    );
  }
}

class _ReplyInput extends StatelessWidget {
  final String hint;
  const _ReplyInput({required this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: HelloColors.recessed,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.centerLeft,
              child: Text(
                hint,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  color: HelloColors.inkTertiary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: HelloColors.accent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.arrow_upward_rounded,
              size: 18,
              color: Color(0xFFF0EFF4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetShell extends StatelessWidget {
  final String eyebrow;
  final String title;
  final Widget body;
  final Widget? footer;
  const _SheetShell({
    required this.eyebrow,
    required this.title,
    required this.body,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.92;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: HelloColors.voidBg.withValues(alpha: 0.72),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            eyebrow,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 1.5,
                              color: HelloColors.inkTertiary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 24,
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.3,
                              color: HelloColors.inkPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: HelloColors.recessed,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: HelloColors.inkSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: body),
              if (footer != null) footer!,
            ],
          ),
        ),
      ),
    );
  }
}
