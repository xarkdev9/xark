import '../../../../../models/feed_item.dart';

/// The kind of action the user can take in response to a PendingSender.
/// Determines which text-word set appears in the Expanded action region.
enum MessageKind {
  /// Yes/No/Maybe (time-proposals, simple confirms, acks)
  confirm,

  /// Love / Works / Pass (polls, decisions)
  decision,

  /// Pay now / Later
  settlement,

  /// Full reply text field (open DM)
  openText,
}

/// The "where" context shown in the label above a foreground avatar.
/// `dm` → literal label `Message · "{subject}"`;
/// `group` → `{groupName} · "{subject}"`.
enum SenderContextKind { dm, group }

/// A person (or group) with one pending item that needs the user's
/// attention. Produced by `freshestPendingSenderProvider` +
/// `pendingSendersQueueProvider`.
class PendingSender {
  /// Stable identifier; used by `HologramAvatar` registry, palette
  /// provider, and the animation lock snapshot.
  final String id;

  /// Display name. Routed through `getAvatarImagePath(name)` to find
  /// the transparent PNG.
  final String name;

  /// What kind of message this is — determines the action word set.
  final MessageKind messageKind;

  /// Context for the label: DM vs group.
  final SenderContextKind contextKind;

  /// Group name when `contextKind == group`. Empty string for DM.
  final String groupName;

  /// First ~36 chars of message / decision title / poll question.
  final String subject;

  /// When the source item was last updated (for recency sort).
  final DateTime sortKey;

  /// The underlying FeedItem — needed by the action handlers to
  /// route the tap to the correct engine call.
  final FeedItem source;

  const PendingSender({
    required this.id,
    required this.name,
    required this.messageKind,
    required this.contextKind,
    required this.groupName,
    required this.subject,
    required this.sortKey,
    required this.source,
  });

  /// Equality by id (stable identity across provider re-emits).
  @override
  bool operator ==(Object other) =>
      other is PendingSender && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Produce a PendingSender from a FeedItem, or null if the feed item
/// is not a "pending action" item for this user.
///
/// Logic:
/// - DmFeedItem with unread inbound → openText kind
/// - GroupFeedItem with unread inbound → confirm kind
/// - DecisionSmallFeedItem where reactions does NOT contain 'me' → decision kind
/// - DecisionHeroFeedItem where reactions does NOT contain 'me' → decision kind
/// - SettlementFeedItem where amount < 0 (user owes) → settlement kind
/// - Other kinds → null (not surfaced on Home)
PendingSender? pendingSenderFromFeedItem(FeedItem item) {
  switch (item) {
    case DmFeedItem(:final conversation):
      if (conversation.unreadCount <= 0) return null;
      return PendingSender(
        id: 'dm_${conversation.id}',
        name: _displayName(conversation.id),
        messageKind: MessageKind.openText,
        contextKind: SenderContextKind.dm,
        groupName: '',
        subject: _preview(conversation.lastMessageText ?? ''),
        sortKey: conversation.lastMessageTimestamp ?? conversation.updatedAt,
        source: item,
      );
    case GroupFeedItem(:final conversation):
      if (conversation.unreadCount <= 0) return null;
      return PendingSender(
        id: 'group_${conversation.id}',
        name: _displayName(conversation.id),
        messageKind: MessageKind.confirm,
        contextKind: SenderContextKind.group,
        groupName: _displayName(conversation.id),
        subject: _preview(conversation.lastMessageText ?? ''),
        sortKey: conversation.lastMessageTimestamp ?? conversation.updatedAt,
        source: item,
      );
    case DecisionSmallFeedItem(
        item: final innerItem,
        title: final t,
        updatedAt: final u,
      ):
      if (innerItem.reactions.containsKey('me')) return null;
      return PendingSender(
        id: 'decs_${innerItem.id}',
        name: _displayName(innerItem.proposedBy ?? ''),
        messageKind: MessageKind.decision,
        contextKind: SenderContextKind.group,
        groupName: _displayName(innerItem.groupId),
        subject: _preview(t),
        sortKey: u,
        source: item,
      );
    case DecisionHeroFeedItem(
        item: final innerItem,
        title: final t,
        updatedAt: final u,
      ):
      if (innerItem.reactions.containsKey('me')) return null;
      return PendingSender(
        id: 'dech_${innerItem.id}',
        name: _displayName(innerItem.proposedBy ?? ''),
        messageKind: MessageKind.decision,
        contextKind: SenderContextKind.group,
        groupName: _displayName(innerItem.groupId),
        subject: _preview(t),
        sortKey: u,
        source: item,
      );
    case SettlementFeedItem(:final settlement):
      if (settlement.amount >= 0) return null; // only pending when user owes
      return PendingSender(
        id: 'settle_${settlement.id}',
        name: settlement.counterpartyName,
        messageKind: MessageKind.settlement,
        contextKind: SenderContextKind.dm,
        groupName: '',
        subject: _preview('\$${settlement.amount.abs().toStringAsFixed(2)}'),
        sortKey: settlement.updatedAt,
        source: item,
      );
    default:
      return null; // trips, itinerary, memory, ai-nudge, focus-hero not surfaced
  }
}

/// `"ram_krishna"` → `"Ram Krishna"`; mimics dm_card/group_card
/// conventions.
String _displayName(String id) {
  if (id.isEmpty) return 'Unknown';
  return id
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// Trim to 36 characters with an ellipsis.
String _preview(String text) {
  final trimmed = text.trim();
  if (trimmed.length <= 36) return trimmed;
  return '${trimmed.substring(0, 36)}…';
}
