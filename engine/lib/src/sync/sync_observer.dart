/// Observer interface for sync-layer diagnostic events.
///
/// All methods have no-op defaults so callers can override only
/// the callbacks they care about.
///
/// **Never log plaintext, keys, or user content** — only event names,
/// IDs, counts, and durations.
mixin SyncObserver {
  /// Called after the outbox has been fully drained.
  void onOutboxDrained(int messagesSent, int messagesFailed) {}

  /// Called after a gap-fill sync completes.
  void onSyncCompleted(int messagesPulled, Duration elapsed) {}
}
