import 'package:flutter/material.dart';

import '../../../../theme.dart';

/// Plans detail view — shown inside group_page as the secondary
/// PageView page. Displays the group's active decisions, settlements,
/// and itinerary items in a scrollable list.
///
/// NOTE: This file was truncated during a recovery operation
/// (2026-04-15) and replaced with a minimal compiling stub.
/// The full implementation (~600 lines) needs to be restored
/// from a backup or rebuilt from the spec.
class PlansView extends StatelessWidget {
  final String groupId;
  const PlansView({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Plans — rebuilding',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: HelloColors.inkTertiary,
        ),
      ),
    );
  }
}
