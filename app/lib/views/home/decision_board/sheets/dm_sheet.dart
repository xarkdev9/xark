import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';
import '../chat_bubble.dart';
import '../message_input_bar.dart';
import 'attachment_sheet.dart';

Future<void> openDmSheet(BuildContext context, DmFeedItem item) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'DmSheet',
    barrierColor: Colors.black.withValues(alpha: 0.28),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, __, ___) {
      return Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: const SizedBox.expand(),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _DmSheet(item: item),
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
      title: name,
      avatarInitial: name.isNotEmpty ? name[0].toUpperCase() : '?',
      body: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        itemCount: messages.length,
        itemBuilder: (_, i) {
          final msg = messages[i];
          return ChatBubble(
            text: msg.text,
            isOutbound: msg.fromMe,
            isFirstInGroup: true,
            isLastInGroup: true,
          );
        },
      ),
      footer: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: MessageInputBar(
          hintText: 'Message $name',
          onPlusTap: () => openAttachmentSheet(context),
          onSend: (text) {
            if (text.isEmpty) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Sent: $text'),
                backgroundColor: HelloColors.recessed,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MockMessage {
  final String text;
  final bool fromMe;
  const _MockMessage({required this.text, required this.fromMe});
}

class _SheetShell extends StatelessWidget {
  final String title;
  final String? avatarInitial;
  final Widget body;
  final Widget? footer;
  const _SheetShell({
    required this.title,
    this.avatarInitial,
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
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (avatarInitial != null) ...[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: HelloColors.recessed,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.06),
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          avatarInitial!,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: HelloColors.inkSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 24,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.3,
                          color: HelloColors.inkPrimary,
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
              const SizedBox(height: 8),
              Expanded(child: body),
              if (footer != null) footer!,
            ],
          ),
          ),
        ),
      ),
    );
  }
}
