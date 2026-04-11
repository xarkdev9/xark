// Decision board — the hello app's home screen.
//
// A 3-card peek stack (Chats, Groups, Decisions) consuming live
// engine streams via Riverpod providers. State persists via
// AutomaticKeepAliveClientMixin + homeActiveCardIndexProvider.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/home_state_provider.dart';
import '../../../theme.dart';
import 'atmosphere.dart';
import 'cards/chats_card.dart';
import 'cards/decisions_card.dart';
import 'cards/groups_card.dart';
import 'peek_stack.dart';

/// The home screen: a 3-card peek stack (Chats, Groups, Decisions)
/// consuming live engine streams via Riverpod providers.
class DecisionBoardPage extends ConsumerStatefulWidget {
  const DecisionBoardPage({super.key});

  @override
  ConsumerState<DecisionBoardPage> createState() =>
      _DecisionBoardPageState();
}

class _DecisionBoardPageState extends ConsumerState<DecisionBoardPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  void _openChatList() {
    // v1: stub — detail screens will be wired in a follow-up spec.
    debugPrint('[DecisionBoardPage] open full chat list');
  }

  void _openGroupList() {
    debugPrint('[DecisionBoardPage] open full group list');
  }

  void _openDecisionList() {
    debugPrint('[DecisionBoardPage] open full decision list');
  }

  void _openConversation(String id) {
    debugPrint('[DecisionBoardPage] open conversation $id');
  }

  void _openDecision(String id) {
    debugPrint('[DecisionBoardPage] open decision $id');
  }

  void _startChat() {
    debugPrint('[DecisionBoardPage] start chat');
  }

  void _createGroup() {
    debugPrint('[DecisionBoardPage] create group');
  }

  void _startDecision() {
    debugPrint('[DecisionBoardPage] start decision');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final initialIndex = ref.watch(homeActiveCardIndexProvider);

    return Scaffold(
      backgroundColor: HelloColors.voidBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: AmbientMesh()),
          SafeArea(
            child: PeekStackPageView(
              initialIndex: initialIndex,
              onIndexChanged: (idx) {
                ref.read(homeActiveCardIndexProvider.notifier).state = idx;
              },
              children: [
                ChatsCard(
                  onHeaderTap: _openChatList,
                  onRowTap: _openConversation,
                  onEmptyCtaTap: _startChat,
                ),
                GroupsCard(
                  onHeaderTap: _openGroupList,
                  onRowTap: _openConversation,
                  onEmptyCtaTap: _createGroup,
                ),
                DecisionsCard(
                  onHeaderTap: _openDecisionList,
                  onRowTap: _openDecision,
                  onEmptyCtaTap: _startDecision,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
