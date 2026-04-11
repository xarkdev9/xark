import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';
import '../chat_bubble.dart';
import '../message_input_bar.dart';
import 'attachment_sheet.dart';

Future<void> openGroupSheet(BuildContext context, GroupFeedItem item) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'GroupSheet',
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
            child: _GroupSheet(item: item),
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

class _GroupSheet extends StatelessWidget {
  final GroupFeedItem item;
  const _GroupSheet({required this.item});

  String _displayName() {
    return item.conversation.id
        .split('_')
        .map((w) =>
            w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final name = _displayName();
    final memberCount = item.conversation.participantIds.length;
    final unread = item.conversation.unreadCount;

    // Mock thread — showing avatars + sender names + cluster behavior
    // across multiple senders (iMessage group chat pattern).
    final messages = const <_GroupMessage>[
      _GroupMessage(
        text: 'yesssss just booked the villa 🏝️',
        senderId: 'sarah',
        firstInGroup: true,
        lastInGroup: false,
      ),
      _GroupMessage(
        text: 'Alila Ubud, pool villa',
        senderId: 'sarah',
        firstInGroup: false,
        lastInGroup: true,
      ),
      _GroupMessage(
        text: 'NICE! what dates?',
        senderId: null,
        fromMe: true,
      ),
      _GroupMessage(
        text: 'OMG same dates we talked about?',
        senderId: 'alex',
        firstInGroup: true,
        lastInGroup: true,
      ),
      _GroupMessage(
        text: 'yep march 15-22',
        senderId: 'sarah',
        firstInGroup: true,
        lastInGroup: true,
      ),
      _GroupMessage(
        text: 'perfect, booking flights now',
        senderId: null,
        fromMe: true,
      ),
    ];

    return _GroupSheetShell(
      eyebrow: 'GROUP CHAT',
      title: name,
      subtitle: '$memberCount members · $unread unread',
      avatarInitial: name.isNotEmpty ? name[0].toUpperCase() : '?',
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: messages.length,
        itemBuilder: (_, i) {
          final msg = messages[i];
          return ChatBubble(
            text: msg.text,
            isOutbound: msg.fromMe,
            isFirstInGroup: msg.firstInGroup,
            isLastInGroup: msg.lastInGroup,
            senderId: msg.senderId,
          );
        },
      ),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: MessageInputBar(
          hintText: 'Message $name',
          onPlusTap: () => openAttachmentSheet(context),
          onSend: (text) {
            if (text.isEmpty) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Sent to $name: $text'),
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

class _GroupMessage {
  final String text;
  final String? senderId; // null = outbound (from me)
  final bool fromMe;
  final bool firstInGroup;
  final bool lastInGroup;
  const _GroupMessage({
    required this.text,
    this.senderId,
    this.fromMe = false,
    this.firstInGroup = true,
    this.lastInGroup = true,
  });
}

class _GroupSheetShell extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final String? avatarInitial;
  final Widget body;
  final Widget? footer;
  const _GroupSheetShell({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
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
                padding: const EdgeInsets.symmetric(horizontal: 20),
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
                          style: const TextStyle(
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
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w300,
                              color: HelloColors.inkSecondary,
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
      ),
    );
  }
}
