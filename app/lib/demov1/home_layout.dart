import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme.dart';
import 'chats_tab_view.dart';
import 'groups_tab_view.dart';
import 'memories_tab_view.dart';
import 'settings_stub.dart';
import 'claim_sheet_stub.dart';
import 'spatial_search_bar.dart';

class HomeLayout extends ConsumerStatefulWidget {
  const HomeLayout({super.key});

  @override
  ConsumerState<HomeLayout> createState() => _HomeLayoutState();
}

class _HomeLayoutState extends ConsumerState<HomeLayout> {
  late final PageController _pageController;

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
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutExpo,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(deepLinkInterceptorProvider, (previous, next) {
      if (next == true) {
        // ClaimSheet.show(context) — disabled in demo mode
      }
    });

    return Scaffold(
      backgroundColor: HelloColors.voidBg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            // Spatial Typographic Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, child) {
                        final page = _pageController.positions.isNotEmpty
                            ? _pageController.page ?? 0.0
                            : 0.0;
      
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _buildHeaderItem("Chats", 0, page),
                              const SizedBox(width: 24),
                              _buildHeaderItem("Groups", 1, page),
                              const SizedBox(width: 24),
                              _buildHeaderItem("Memories", 2, page),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          transitionDuration: const Duration(milliseconds: 400),
                          pageBuilder: (context, animation, secondaryAnimation) => 
                              const SettingsPage(),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, -1), // Slide from top
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutExpo,
                              )),
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                        ),
                      );
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: HelloColors.inkSecondary.withValues(alpha: 0.2), // Mock avatar background
                      ),
                      child: const Center(
                        child: Icon(Icons.person, color: HelloColors.inkPrimary), // Mock avatar icon
                      ),
                    ),
                  )
                ],
              ),
            ),
            
            // Spatial Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: SpatialSearchBar(
                onChanged: (query) {
                  // TODO: Wire to engine search when available
                },
              ),
            ),

            // View Body
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const ClampingScrollPhysics(),
                children: const [
                  ChatsTabView(),
                  GroupsTabView(),
                  MemoriesTabView(),
                ],
              ),
            ),

            // ─── iMessage-style Bottom Bar ─────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              decoration: BoxDecoration(
                color: HelloColors.voidBg,
                border: Border(
                  top: BorderSide(
                    color: HelloColors.inkPrimary.withValues(alpha: 0.06),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Search icon
                  GestureDetector(
                    onTap: () {
                      // Focus the search bar
                    },
                    child: Icon(
                      Icons.search_rounded,
                      size: 24,
                      color: HelloColors.inkPrimary.withValues(alpha: 0.35),
                    ),
                  ),
                  const Spacer(),
                  // New chat / compose icon (iMessage style)
                  GestureDetector(
                    onTap: () {
                      // TODO: Open new chat composer
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: HelloColors.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.edit_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          width: 60,
          height: 60,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
               ref.read(deepLinkInterceptorProvider.notifier).trigger(true);
            },
            child: const SizedBox(),
          ),
        ),
      ],
    ),
      ),
    );
  }

  Widget _buildHeaderItem(String title, int index, double currentPage) {
    final diff = (currentPage - index).abs();
    final double opacity = (1.0 - (0.7 * diff)).clamp(0.3, 1.0);
    final double scale = (1.0 - (0.15 * diff)).clamp(0.85, 1.0);

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity,
          child: Text(
            title,
            style: HelloTypography.spaceTitle,
          ),
        ),
      ),
    );
  }
}
