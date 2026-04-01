import 'dart:collection';

/// LRU cache for tracked widget selections, bounded by [capacity].
///
/// On [get], the optional [isMounted] predicate can be used to evict stale
/// entries; the returned entry is promoted to the most-recently-used position.
/// On [put], if the cache is at capacity the least-recently-used entry is
/// removed first.
final class LruSelectionCache<T> {
  LruSelectionCache({this.capacity = 50});

  final int capacity;

  final LinkedHashMap<String, T> _map = LinkedHashMap<String, T>();

  T? get(final String key, {final bool Function(T)? isMounted}) {
    final entry = _map[key];
    if (entry == null) return null;
    if (isMounted != null && !isMounted(entry)) {
      _map.remove(key);
      return null;
    }
    // Promote to most-recently-used position.
    _map.remove(key);
    _map[key] = entry;
    return entry;
  }

  void put(final String key, final T value) {
    _map.remove(key);
    if (_map.length >= capacity) {
      _map.remove(_map.keys.first);
    }
    _map[key] = value;
  }

  void remove(final String key) => _map.remove(key);

  void clear() => _map.clear();

  int get length => _map.length;
}
