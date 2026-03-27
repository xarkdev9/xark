import 'dart:typed_data';

/// In-memory LRU cache for recently decrypted media blobs.
///
/// Uses a `LinkedHashMap` (Dart's default `Map` implementation) to
/// maintain insertion order. On access, entries are moved to the end
/// (most recently used). When the cache exceeds [maxItems], the
/// least recently used entry is evicted.
class MediaCache {
  /// Creates a [MediaCache] with the given capacity.
  MediaCache({this.maxItems = 20});

  /// Maximum number of entries before LRU eviction kicks in.
  final int maxItems;

  final _cache = <String, Uint8List>{};

  /// Returns cached bytes for [mediaId], or `null` if not cached.
  ///
  /// Accessing an entry moves it to the MRU position.
  Uint8List? get(String mediaId) {
    final data = _cache.remove(mediaId);
    if (data != null) {
      _cache[mediaId] = data;
    }
    return data;
  }

  /// Stores [data] under [mediaId], evicting the LRU entry if full.
  void put(String mediaId, Uint8List data) {
    _cache.remove(mediaId);
    _cache[mediaId] = data;
    while (_cache.length > maxItems) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// Removes a single entry.
  void remove(String mediaId) => _cache.remove(mediaId);

  /// Removes all cached entries.
  void clear() => _cache.clear();

  /// Number of entries currently cached.
  int get length => _cache.length;
}
