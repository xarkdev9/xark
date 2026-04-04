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
  late final AnimationController _dotsController;
  int _currentIndex = 0;
  bool _headerExpanded = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _dotsController.dispose();
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
            // ═══ MORPHING HEADER SURFACE ═══
            // Compact: < back | avatar + name + breathing dots
            // Expanded: actions appear below (plans, call, video)
            GestureDetector(
              onTap: () => setState(() => _headerExpanded = !_headerExpanded),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                child: Column(
                  children: [
                    // Main row: back + avatar + name + dots
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, color: HelloColors.inkSecondary, size: 20),
                          onPressed: () {
                            if (_headerExpanded) {
                              setState(() => _headerExpanded = false);
                            } else if (_currentIndex == 1) {
                              _onTabTapped(0);
                            } else {
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                        const Spacer(),
                        // Avatar with Liquid Fire ring (story-style)
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: _currentIndex == 0
                                ? HelloColors.liquidFireStandard
                                : null,
                            color: _currentIndex == 1 ? HelloColors.successGreen : null,
                          ),
                          padding: const EdgeInsets.all(2),
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
                                widget.spaceTitle.isNotEmpty ? widget.spaceTitle[0].toUpperCase() : '?',
                                style: HelloTypography.body.copyWith(fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Name
                        Text(
                          widget.spaceTitle,
                          style: HelloTypography.body.copyWith(fontSize: 16),
                        ),
                        // Breathing dots (ambient indicator — plans need attention)
                        if (_currentIndex == 0) ...[
                          const SizedBox(width: 8),
                          AnimatedBuilder(
                            animation: _dotsController,
                            builder: (context, child) {
                              final t = _dotsController.value;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(3, (i) {
                                  final delay = i * 0.15;
                                  final dotT = ((t + delay) % 1.0);
                                  final alpha = 0.2 + (dotT * 0.6);
                                  return Container(
                                    width: 5, height: 5,
                                    margin: const EdgeInsets.only(left: 3),
                                    decoration: BoxDecoration(
                                      color: HelloColors.accent.withValues(alpha: alpha),
                                      shape: BoxShape.circle,
                                    ),
                                  );
                                }),
                              );
                            },
                          ),
                        ],
                        const Spacer(),
                        // [+] only on Plans tab
                        if (_currentIndex == 1)
                          GestureDetector(
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
                      ],
                    ),

                    // Expanded actions (floating text, no pills)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      child: _headerExpanded
                          ? Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _HeaderAction(
                                    label: 'plans',
                                    color: HelloColors.accent,
                                    onTap: () {
                                      setState(() => _headerExpanded = false);
                                      _onTabTapped(_currentIndex == 0 ? 1 : 0);
                                    },
                                  ),
                                  const SizedBox(width: 32),
                                  _HeaderAction(
                                    label: 'call',
                                    color: HelloColors.inkTertiary,
                                    onTap: () => setState(() => _headerExpanded = false),
                                  ),
                                  const SizedBox(width: 32),
                                  _HeaderAction(
                                    label: 'video',
                                    color: HelloColors.inkTertiary,
                                    onTap: () => setState(() => _headerExpanded = false),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox(width: double.infinity, height: 0),
                    ),
                  ],
                ),
              ),
            ),

            // Page content with ambient gradient
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

                  // Ambient right-edge glow (Plans is waiting to the right)
                  if (_currentIndex == 0)
                    Positioned(
                      right: 0, top: 0, bottom: 0,
                      width: 24,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerRight,
                              end: Alignment.centerLeft,
                              colors: [
                                HelloColors.accent.withValues(alpha: 0.06),
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

/// Floating action text — no pill, no border, just text + tap
class _HeaderAction extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HeaderAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
