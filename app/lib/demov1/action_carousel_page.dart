import 'package:flutter/material.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'action_card_widget.dart';
import 'action_card_provider.dart';
import 'consensus_listener.dart';
import 'theme.dart';

class ActionCarouselPage extends ConsumerStatefulWidget {
  const ActionCarouselPage({super.key});

  @override
  ConsumerState<ActionCarouselPage> createState() => _ActionCarouselPageState();
}

class _ActionCarouselPageState extends ConsumerState<ActionCarouselPage> {
  late PageController _controller;

  @override
  void initState() {
    super.initState();
    // Netflix spatial mechanics: peek next/previous card
    _controller = PageController(viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only observing the 'default_space' actions payload
    final asyncMessages = ref.watch(actionCardProvider('default_space'));
    final lockedId = ref.watch(globalLockProvider);

    return Scaffold(
      backgroundColor: HelloColors.voidBg,
      body: asyncMessages.when(
        loading: () => const SizedBox.shrink(),
        error: (err, st) => const SizedBox.shrink(),
        data: (messages) {
          if (messages.isEmpty) return const SizedBox.shrink();

          return PageView.builder(
            controller: _controller,
            pageSnapping: true,
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              final isSubOptimalCard = lockedId != null && lockedId != message.id;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 32.0),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.fastOutSlowIn,
                  opacity: isSubOptimalCard ? 0.3 : 1.0,
                  child: ActionCardWidget(
                    item: DecisionItem(
                      id: message.id,
                      groupId: message.groupId,
                      title: message.text ?? 'Untitled',
                      state: 'active',
                      weightedScore: 0.0,
                      agreementScore: message.reactions.length * 0.1,
                      isLocked: false,
                      photoUrl: message.media?.downloadUrl,
                    ),
                    onReact: () {},
                    onPinCommit: () {},
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
