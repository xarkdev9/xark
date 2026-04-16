// The home screen — a 3-tab scaffold (Home / Chats / Plans) with a
// horizontal TabBarView, a scaffold-level LiquidIntentLayer (thin
// plasma handle at idle, blooms to TextField + mic + +) wrapping the
// TabBarView, a floating user avatar / title header in the top-left,
// and a full-bleed ChromaticAtmosphere behind everything. Chats is
// the iMessage-style merged DMs + Groups list as of 2026-04-15.
//
// See: docs/superpowers/specs/2026-04-14-cosmos-home-design.md

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/tabs_provider.dart';
import '../../../theme.dart';
import 'chromatic_atmosphere.dart';
import 'consensus_watcher.dart';
import 'liquid_intent_handle.dart';
import 'pages/chats_page.dart';
import 'pages/home_page.dart';
import 'pages/plans_page.dart';
import 'tab_header.dart';

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
    _tabController = TabController(length: 3, vsync: this);
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ConsensusWatcher(
      child: Scaffold(
        backgroundColor: HelloColors.voidBg,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: ChromaticAtmosphere()),
            SafeArea(
              child: LiquidIntentLayer(
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    HomePage(),
                    ChatsPage(),
                    PlansPage(),
                  ],
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 20,
              child: const TabHeader(),
            ),
          ],
        ),
      ),
    );
  }
}
