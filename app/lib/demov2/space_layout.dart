import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../main.dart';
import 'chat_view.dart';
import 'decision_board.dart';
import 'add_item_sheet.dart';

class SpaceLayout extends ConsumerStatefulWidget {
  final String spaceId;
  final String spaceTitle;
  const SpaceLayout({super.key, required this.spaceId, required this.spaceTitle});

  @override
  ConsumerState<SpaceLayout> createState() => _SpaceLayoutState();
}

class _SpaceLayoutState extends ConsumerState<SpaceLayout> {
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

  void _openAddSheet() {
    final engine = ref.read(engineProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: HelloColors.chrome,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => AddItemSheet(
        groupId: widget.spaceId,
        onSubmit: (title, category, photoUrl) {
          (engine as dynamic).addDecisionItem(
            widget.spaceId,
            title: title,
            category: category,
            photoUrl: photoUrl.isNotEmpty ? photoUrl : null,
          );
          setState(() {});
        },
      ),
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
            // Top Navigation Rail
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
                      child: const Text('Decide', style: HelloTypography.spaceTitle),
                    ),
                  ),
                  const SizedBox(width: 24),
                  GestureDetector(
                    onTap: () => _onTabTapped(1),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _currentIndex == 1 ? 1.0 : 0.4,
                      child: const Text('Chat', style: HelloTypography.spaceTitle),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.spaceTitle,
                    style: HelloTypography.hint.copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),

            // Page content
            Expanded(
              child: Stack(
                children: [
                  PageView(
                    controller: _pageController,
                    onPageChanged: (idx) => setState(() => _currentIndex = idx),
                    physics: const ClampingScrollPhysics(),
                    children: [
                      DecisionBoard(groupId: widget.spaceId),
                      ProviderScope(
                        overrides: const [],
                        child: ClipRRect(
                          child: ChatView(spaceId: widget.spaceId),
                        ),
                      ),
                    ],
                  ),

                  // FAB — only on Decide tab
                  if (_currentIndex == 0)
                    Positioned(
                      right: 20,
                      bottom: 24,
                      child: GestureDetector(
                        onTap: _openAddSheet,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: HelloColors.accent,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: HelloColors.accent.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.add, color: Colors.white, size: 24),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
