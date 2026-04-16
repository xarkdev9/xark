import 'package:flutter/material.dart';
import '../../theme.dart';
import 'chat_view.dart';
import '../../widgets/action_card_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../../main.dart'; // engineProvider
import '../../providers/decrypted_item_payload.dart';
import '../../providers/plans_provider.dart';

class SpaceLayout extends StatefulWidget {
  final String spaceId;
  final String spaceTitle;
  const SpaceLayout({super.key, required this.spaceId, required this.spaceTitle});

  @override
  State<SpaceLayout> createState() => _SpaceLayoutState();
}

class _SpaceLayoutState extends State<SpaceLayout> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutExpo,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HelloColors.voidBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Navigation Rail (Zero-Box Typographic)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: HelloColors.inkSecondary, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _onTabTapped(0),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _currentIndex == 0 ? 1.0 : 0.4,
                      child: const Text('Chat', style: HelloTypography.spaceTitle),
                    ),
                  ),
                  const SizedBox(width: 24),
                  GestureDetector(
                    onTap: () => _onTabTapped(1),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _currentIndex == 1 ? 1.0 : 0.4,
                      child: const Text('Possibilities', style: HelloTypography.spaceTitle),
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentIndex = idx),
                physics: const ClampingScrollPhysics(),
                children: [
                  // Overriding the ChatView behavior to embed without double AppBars
                  ProviderScope(
                    overrides: [
                      // Space context provision depending on architecture, assuming 'default_space' mock fallback
                      // For now ChatView internally calls providers that default to 'default_space' if needed
                    ],
                    child: ClipRRect(
                      child: ChatView(spaceId: widget.spaceId),
                    ),
                  ),
                  _PossibilityHorizon(spaceId: widget.spaceId),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

// Decision Board Tab content
class _PossibilityHorizon extends ConsumerWidget {
  final String spaceId;
  const _PossibilityHorizon({required this.spaceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(engineProvider);
    final engineDecisions = engine as ChatEngineDecisions;
    
    final plansAsync = ref.watch(decryptedPlansProvider(spaceId));

    return plansAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: HelloColors.accent)),
      error: (e, st) => Center(child: Text('Error: $e', style: HelloTypography.hint)),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text("No items to discuss yet.", style: HelloTypography.hint));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: ActionCardWidget(
                item: item,
                onReact: () => engineDecisions.reactToItem(item.id, 'works_for_me'),
                onPinCommit: () {
                  engineDecisions.lockItem(item.id, CommitmentProof(type: 'mock', value: 'booked', submittedBy: 'me'));
                },
              ),
            );
          },
        );
      },
    );
  }
}
