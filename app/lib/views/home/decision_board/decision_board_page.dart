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
import 'pages/chats_page.dart';
import 'pages/groups_page.dart';
import 'pages/home_page.dart';
import 'pages/plans_page.dart';
import 'tab_header.dart';
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
    _tabController.animation?.addListener(_onTabAnimationChanged);
  }

  @override
  void dispose() {
    _tabController.animation?.removeListener(_onTabAnimationChanged);
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

  void _onTabAnimationChanged() {
    if (!mounted) return;
    final value = _tabController.animation?.value ?? 0.0;
    ref.read(tabAnimationProvider.notifier).state = value;
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
              children: const [
                HomePage(),
                ChatsPage(),
                GroupsPage(),
                PlansPage(),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20,
            child: const TabHeader(),
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
