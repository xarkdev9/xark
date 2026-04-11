// Floating iMessage-style escape hatch. Shows every DM and group
// chat the user has, sorted by recent activity. Tapping any row
// dismisses the search sheet and opens the target chat sheet
// directly — zero drill-down to jump to any conversation.

import 'dart:ui';

import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/feed_item.dart';
import '../../../../providers/conversations_provider.dart';
import '../../../../theme.dart';
import 'dm_sheet.dart';
import 'group_sheet.dart';

Future<void> openSearchSheet(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'SearchSheet',
    barrierColor: Colors.black.withValues(alpha: 0.28),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, _, _) {
      return Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: const SizedBox.expand(),
            ),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: _SearchSheet(),
          ),
        ],
      );
    },
    transitionBuilder: (_, animation, _, child) {
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

class _SearchEntry {
  final Conversation conversation;
  final bool isGroup;
  const _SearchEntry({required this.conversation, required this.isGroup});

  DateTime get timestamp =>
      conversation.lastMessageTimestamp ?? conversation.updatedAt;
}

class _SearchSheet extends ConsumerWidget {
  const _SearchSheet();

  String _displayName(Conversation c, {required bool isGroup}) {
    final id = c.id;
    if (id.isEmpty) return 'Unknown';
    if (isGroup) {
      return id
          .split('_')
          .map((w) =>
              w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
    }
    return '${id[0].toUpperCase()}${id.substring(1)}';
  }

  String _eyebrow(_SearchEntry entry) {
    if (entry.isGroup) {
      return 'GROUP · ${entry.conversation.participantIds.length} MEMBERS';
    }
    return 'DIRECT';
  }

  void _jumpTo(BuildContext context, _SearchEntry entry) {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!navigator.context.mounted) return;
      if (entry.isGroup) {
        openGroupSheet(
          navigator.context,
          GroupFeedItem(entry.conversation),
        );
      } else {
        openDmSheet(
          navigator.context,
          DmFeedItem(entry.conversation),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dms = ref.watch(directMessagesProvider);
    final groups = ref.watch(groupChatsProvider);

    final entries = <_SearchEntry>[
      for (final c in dms) _SearchEntry(conversation: c, isGroup: false),
      for (final c in groups) _SearchEntry(conversation: c, isGroup: true),
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final height = MediaQuery.of(context).size.height * 0.86;

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
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: HelloColors.recessed,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: HelloColors.inkSecondary,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Search chats, groups, decisions…',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w300,
                                  color: HelloColors.inkTertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: HelloColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'JUMP TO',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1.8,
                      color: HelloColors.inkTertiary,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: entries.length,
                  itemBuilder: (rowContext, i) {
                    final entry = entries[i];
                    final name = _displayName(
                      entry.conversation,
                      isGroup: entry.isGroup,
                    );
                    final initial =
                        name.isNotEmpty ? name[0].toUpperCase() : '?';
                    final isUnread = entry.conversation.unreadCount > 0;

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _jumpTo(rowContext, entry),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: HelloColors.recessed,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  color: HelloColors.inkSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                      color: HelloColors.inkPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _eyebrow(entry),
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 1.2,
                                      color: HelloColors.inkTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isUnread)
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: HelloColors.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
