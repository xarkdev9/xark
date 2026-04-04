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

class _SpaceLayoutState extends ConsumerState<SpaceLayout>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _breatheController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breatheController.dispose();
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
            // ═══ iMessage HEADER — centered vertical: avatar → name → hint ═══
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
              child: Stack(
                children: [
                  // Back button (floating left)
                  Positioned(
                    left: 0, top: 0,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: HelloColors.inkSecondary, size: 20),
                      onPressed: () {
                        if (_currentIndex == 1) {
                          _onTabTapped(0);
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ),
                  // [+] on Plans tab (floating right)
                  if (_currentIndex == 1)
                    Positioned(
                      right: 8, top: 4,
                      child: GestureDetector(
                        onTap: _openAddSheet,
                        child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            gradient: HelloColors.liquidFireStandard,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(Icons.add, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ),
                  // Centered vertical: avatar → name → swipe hint
                  Center(
                    child: GestureDetector(
                      onTap: () => _onTabTapped(_currentIndex == 0 ? 1 : 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Avatar with Liquid Fire gradient ring
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: _currentIndex == 0
                                  ? HelloColors.liquidFireStandard
                                  : null,
                              color: _currentIndex == 1
                                  ? HelloColors.successGreen
                                  : null,
                            ),
                            padding: const EdgeInsets.all(2.5),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: HelloColors.voidBg,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(1.5),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: HelloColors.recessed,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  widget.spaceTitle.isNotEmpty
                                      ? widget.spaceTitle[0].toUpperCase()
                                      : '?',
                                  style: HelloTypography.body.copyWith(fontSize: 14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          // Name
                          Text(
                            widget.spaceTitle,
                            style: HelloTypography.body.copyWith(fontSize: 14),
                          ),
                          // Swipe hint — breathing context text
                          if (_currentIndex == 0) ...[
                            const SizedBox(height: 2),
                            AnimatedBuilder(
                              animation: _breatheController,
                              builder: (context, child) {
                                final t = _breatheController.value;
                                return Opacity(
                                  opacity: 0.3 + t * 0.15,
                                  child: const Text(
                                    'swipe to explore plans',
                                    style: TextStyle(
                                      fontFamily: 'Inter', fontSize: 11,
                                      fontWeight: FontWeight.w300,
                                      color: HelloColors.inkTertiary,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ] else ...[
                            const SizedBox(height: 2),
                            AnimatedBuilder(
                              animation: _breatheController,
                              builder: (context, child) {
                                final t = _breatheController.value;
                                return Opacity(
                                  opacity: 0.3 + t * 0.15,
                                  child: const Text(
                                    'swipe to chat',
                                    style: TextStyle(
                                      fontFamily: 'Inter', fontSize: 11,
                                      fontWeight: FontWeight.w300,
                                      color: HelloColors.inkTertiary,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Page content with ambient right-edge glow
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

                  // Ambient right-edge glow on Chat tab
                  if (_currentIndex == 0)
                    Positioned(
                      right: 0, top: 0, bottom: 0,
                      width: 20,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerRight,
                              end: Alignment.centerLeft,
                              colors: [
                                HelloColors.accent.withValues(alpha: 0.05),
                                Colors.transparent,
                              ],
                            ),
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
