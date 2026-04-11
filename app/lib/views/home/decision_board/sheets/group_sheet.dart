import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../models/feed_item.dart';
import '../../../../theme.dart';
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

    return _GroupSheetShell(
      eyebrow: 'GROUP CHAT',
      title: name,
      subtitle: '$memberCount members · $unread unread',
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatChip(label: 'UNREAD', value: '$unread'),
                const SizedBox(width: 12),
                _StatChip(label: 'MEMBERS', value: '$memberCount'),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              item.conversation.lastMessageText ?? 'No activity yet',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w300,
                height: 1.5,
                color: HelloColors.inkSecondary,
              ),
            ),
          ],
        ),
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

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: HelloColors.recessed,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              fontWeight: FontWeight.w400,
              letterSpacing: 1.5,
              color: HelloColors.inkTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 22,
              fontWeight: FontWeight.w400,
              color: HelloColors.inkPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupSheetShell extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget body;
  final Widget? footer;
  const _GroupSheetShell({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
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
    );
  }
}
