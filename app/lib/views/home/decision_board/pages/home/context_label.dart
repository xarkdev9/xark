import 'package:flutter/material.dart';

import '../../../../../theme.dart';
import 'cosmos_sender_model.dart';

/// The small text below the foreground avatar on Home.
///
/// For DMs: `Message · "{subject}"` — the word "Message" replaces a
/// group name as the context token. Principle 6 3-second rule
/// applies uniformly (no DM exception); the subject must always be
/// exposed so the user can triage priority without tapping.
///
/// For groups: `{group_name} · "{subject}"`.
///
/// Zero-box: no container, no fill, no border. Just type.
class ContextLabel extends StatelessWidget {
  final PendingSender sender;

  const ContextLabel({super.key, required this.sender});

  @override
  Widget build(BuildContext context) {
    final text = switch (sender.contextKind) {
      SenderContextKind.dm => 'Message · "${sender.subject}"',
      SenderContextKind.group =>
        '${sender.groupName} · "${sender.subject}"',
    };

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.80,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: HelloColors.inkSecondary,
          height: 1.2,
        ),
      ),
    );
  }
}
