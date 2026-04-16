import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import 'tabs/chats_tab_view.dart';
import 'tabs/groups_tab_view.dart';
import 'tabs/memories_tab_view.dart';
import '../settings/settings_page.dart';
import '../../demov2/space_layout.dart';
import '../../main.dart';



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

  void _openNewChatComposer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: HelloColors.voidBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        String contactId = '';
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'New Connection',
                style: HelloTypography.spaceTitle,
              ),
              const SizedBox(height: 16),
              TextField(
                autofocus: true,
                style: HelloTypography.body,
                decoration: const InputDecoration(
                  hintText: 'Enter peer phone number or user ID',
                  hintStyle: HelloTypography.hint,
                  border: InputBorder.none,
                ),
                onChanged: (val) => contactId = val,
                onSubmitted: (val) => _startChat(ctx, val),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: HelloColors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: () => _startChat(ctx, contactId),
                child: const Text('Start Connecting (X3DH)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.normal)),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  void _startChat(BuildContext ctx, String peerId) async {
    if (peerId.trim().isEmpty) return;
    Navigator.pop(ctx); 
    try {
      final engine = ref.read(engineProvider);
      final spaceId = await engine.findOrCreateChat(peerId.trim());
      
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SpaceLayout(spaceId: spaceId, spaceTitle: peerId.trim()),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HelloColors.voidBg,
      body: SafeArea(
        child: Column(
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

            // iMessage-style Bottom Bar
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
                  Icon(
                    Icons.search_rounded,
                    size: 24,
                    color: HelloColors.inkPrimary.withValues(alpha: 0.35),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _openNewChatComposer,
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
