/// LRU deduplication set for message IDs.
///
/// Maintains an insertion-ordered set of IDs, evicting the oldest entry
/// when the set exceeds [maxSize]. Used to prevent re-processing the
/// same message during real-time delivery and sync gap fills.
class DeduplicationSet {
  /// Creates a [DeduplicationSet] with a maximum capacity of [maxSize].
  DeduplicationSet({this.maxSize = 1000});

  /// Maximum number of IDs to retain before evicting the oldest.
  final int maxSize;

  // LinkedHashMap (Dart's default Map) maintains insertion order.
  final Map<String, bool> _seen = <String, bool>{};

  /// Attempts to add [id] to the set.
  ///
  /// Returns `true` if [id] was **not** previously seen (new message).
  /// Returns `false` if [id] was already present (duplicate).
  bool tryAdd(String id) {
    if (_seen.containsKey(id)) return false;
    _seen[id] = true;
    while (_seen.length > maxSize) {
      _seen.remove(_seen.keys.first);
    }
    return true;
  }

  /// Returns the number of IDs currently tracked.
  int get length => _seen.length;

  /// Returns whether [id] is currently in the set.
  bool contains(String id) => _seen.containsKey(id);

  /// Removes all tracked IDs.
  void clear() => _seen.clear();
}
