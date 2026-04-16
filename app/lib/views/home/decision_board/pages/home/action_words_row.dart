import 'package:flutter/material.dart';

import '../../../../../theme.dart';
import '../../../../../utils/haptics.dart';
import 'action_word.dart';
import 'cosmos_sender_model.dart';

/// Renders the action words appropriate for the message kind.
///
/// Hit zones are `Expanded` columns — each child gets exactly
/// 1/N of the row width, edge-to-edge. No padding-based dead
/// zones, no Center wrapper (ActionWord's internal Container
/// claims the full slot).
///
/// For MessageKind.openText: renders a full-width reply TextField
/// instead of word-buttons.
class ActionWordsRow extends StatelessWidget {
  final MessageKind kind;
  final ValueChanged<String> onAction;
  final TextEditingController? replyController;
  final VoidCallback? onReplySubmit;

  const ActionWordsRow({
    super.key,
    required this.kind,
    required this.onAction,
    this.replyController,
    this.onReplySubmit,
  });

  @override
  Widget build(BuildContext context) {
    return switch (kind) {
      MessageKind.confirm => _buildRow([
          _ActionSpec('Yes', affirmative: true),
          _ActionSpec('No', affirmative: false),
          _ActionSpec('Maybe', affirmative: false),
        ]),
      MessageKind.decision => _buildRow([
          _ActionSpec('Love', affirmative: true),
          _ActionSpec('Works', affirmative: true),
          _ActionSpec('Pass', affirmative: false),
        ]),
      MessageKind.settlement => _buildRow([
          _ActionSpec('Pay now', affirmative: true),
          _ActionSpec('Later', affirmative: false),
        ]),
      MessageKind.openText => _buildReplyField(context),
    };
  }

  Widget _buildRow(List<_ActionSpec> specs) {
    return Row(
      children: [
        for (final spec in specs)
          Expanded(
            // No Center wrapper — ActionWord's internal Container
            // claims the full Expanded slot for the GestureDetector
            // hit zone. Wrapping in Center would shrink the hit
            // target to the text (v2-review Patch #5).
            child: ActionWord(
              word: spec.word,
              onTap: () {
                if (spec.affirmative) {
                  HelloHaptic.confirm();
                } else {
                  HelloHaptic.tap();
                }
                onAction(spec.word);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildReplyField(BuildContext context) {
    return TextField(
      controller: replyController,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w400,
        color: HelloColors.inkPrimary,
      ),
      decoration: InputDecoration(
        hintText: 'Reply…',
        hintStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w400,
          color: HelloColors.inkTertiary,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => onReplySubmit?.call(),
    );
  }
}

class _ActionSpec {
  final String word;
  final bool affirmative;
  const _ActionSpec(this.word, {required this.affirmative});
}
