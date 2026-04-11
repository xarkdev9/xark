// The home screen — a 4-tab scaffold (HOME / CHATS / GROUPS / PLANS)
// with a horizontal TabBarView, a single bottom BottomBar glass pill
// containing the mode chip + search field + mic/send + compose,
// and a floating user avatar in the top-left.
//
// See: docs/superpowers/specs/2026-04-11-mode-chip-home-design.md

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/tabs_provider.dart';
import '../../../theme.dart';
import 'atmosphere.dart';
import 'bottom_bar.dart';
import 'floating_avatar.dart';
import 'pages/chats_page.dart';
import 'pages/groups_page.dart';
import 'pages/home_page.dart';
import 'pages/plans_page.dart';
import 'sheets/new_chat_sheet.dart';
import 'sheets/search_sheet.dart';

class DecisionBoardPage extends ConsumerStatefulWidget {
  const DecisionBoardPage({super.key});

  @override
  ConsumerState<DecisionBoardPage> createState() =>
      _DecisionBoardPageState();
}

class _DecisionBoardPageState extends ConsumerState<DecisionBoardPage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final TabController _tabController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!mounted) return;
    final index = _tabController.index;
    final current = ref.read(activeTabIndexProvider);
    if (index != current) {
      ref.read(activeTabIndexProvider.notifier).state = index;
    }
  }

  void _switchToTab(int index) {
    if (!mounted) return;
    _tabController.animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: HelloColors.voidBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: AmbientMesh()),
          SafeArea(
            child: TabBarView(
              controller: _tabController,
              physics: const BouncingScrollPhysics(),
              children: const [
                HomePage(),
                ChatsPage(),
                GroupsPage(),
                PlansPage(),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 20,
            child: const FloatingAvatar(),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: BottomBar(
              onTabSelected: _switchToTab,
              onSearchSubmit: () => openSearchSheet(context),
              onComposeTap: () => openNewChatSheet(context),
            ),
          ),
        ],
      ),
    );
  }
}
