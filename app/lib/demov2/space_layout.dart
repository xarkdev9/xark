import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../main.dart';
import 'chat_view.dart';
import 'plans_view.dart';
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
            // Top bar: < back | avatar + name (center) | Plans icon (right)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: HelloColors.inkSecondary, size: 20),
                    onPressed: () {
                      if (_currentIndex == 1) {
                        // If on Plans, go back to Chat first
                        _onTabTapped(0);
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      // Tap name to toggle — subtle discovery
                      _onTabTapped(_currentIndex == 0 ? 1 : 0);
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: HelloColors.recessed,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            widget.spaceTitle.isNotEmpty ? widget.spaceTitle[0].toUpperCase() : '?',
                            style: HelloTypography.body.copyWith(fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.spaceTitle,
                          style: HelloTypography.body.copyWith(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // [+] add button — small, liquid fire accent
                  if (_currentIndex == 1)
                    GestureDetector(
                      onTap: _openAddSheet,
                      child: Container(
                        width: 30,
                        height: 30,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: HelloColors.accent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: HelloColors.accent.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.add, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  // Plans/Chat toggle
                  GestureDetector(
                    onTap: () => _onTabTapped(_currentIndex == 0 ? 1 : 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _currentIndex == 1
                            ? HelloColors.accent.withValues(alpha: 0.12)
                            : HelloColors.recessed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _currentIndex == 1 ? Icons.chat_bubble_outline : Icons.view_agenda_outlined,
                            size: 16,
                            color: _currentIndex == 1 ? HelloColors.accent : HelloColors.inkTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _currentIndex == 1 ? 'Chat' : 'Plans',
                            style: HelloTypography.hint.copyWith(
                              fontSize: 12,
                              color: _currentIndex == 1 ? HelloColors.accent : HelloColors.inkTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                      ProviderScope(
                        overrides: const [],
                        child: ClipRRect(
                          child: ChatView(spaceId: widget.spaceId),
                        ),
                      ),
                      PlansView(groupId: widget.spaceId),
                    ],
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
