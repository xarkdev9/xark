import 'package:flutter/material.dart';

import 'decision_board/decision_board_page.dart';

/// Home route — delegates to the decision board (Netflix-style decision
/// rails + Apple Liquid Glass plan-world tiles).
class HomeLayout extends StatelessWidget {
  const HomeLayout({super.key});

  @override
  Widget build(BuildContext context) => const DecisionBoardPage();
}
