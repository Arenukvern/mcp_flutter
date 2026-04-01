import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_live_edit_toolkit/src/services/live_edit_session/lru_selection_cache.dart';

void main() {
  group('LruSelectionCache', () {
    test('put and get returns value', () {
      final cache = LruSelectionCache<int>();
      cache.put('a', 1);
      expect(cache.get('a'), 1);
    });

    test('get on missing key returns null', () {
      final cache = LruSelectionCache<int>();
      expect(cache.get('missing'), isNull);
    });

    test('evicts LRU entry at capacity', () {
      final cache = LruSelectionCache<int>(capacity: 3);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3);
      // 'a' is LRU — adding 'd' should evict 'a'
      cache.put('d', 4);
      expect(cache.get('a'), isNull);
      expect(cache.get('b'), 2);
      expect(cache.get('c'), 3);
      expect(cache.get('d'), 4);
    });

    test('get promotes accessed entry (prevents LRU eviction)', () {
      final cache = LruSelectionCache<int>(capacity: 3);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3);
      // Promote 'a' to MRU
      cache.get('a');
      // Adding 'd' should now evict 'b' (the new LRU)
      cache.put('d', 4);
      expect(cache.get('a'), 1);
      expect(cache.get('b'), isNull);
      expect(cache.get('c'), 3);
      expect(cache.get('d'), 4);
    });

    test('isMounted callback evicts stale entry and returns null', () {
      final cache = LruSelectionCache<String>();
      cache.put('x', 'stale');
      final result = cache.get('x', isMounted: (v) => v != 'stale');
      expect(result, isNull);
      // Entry was removed
      expect(cache.get('x'), isNull);
    });

    test('isMounted=true keeps entry', () {
      final cache = LruSelectionCache<String>();
      cache.put('y', 'live');
      expect(cache.get('y', isMounted: (_) => true), 'live');
    });

    test('clear removes all entries', () {
      final cache = LruSelectionCache<int>(capacity: 5);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.clear();
      expect(cache.length, 0);
      expect(cache.get('a'), isNull);
    });

    test('remove deletes single entry', () {
      final cache = LruSelectionCache<int>();
      cache.put('a', 1);
      cache.put('b', 2);
      cache.remove('a');
      expect(cache.get('a'), isNull);
      expect(cache.get('b'), 2);
    });

    test('put overwrites existing key', () {
      final cache = LruSelectionCache<int>();
      cache.put('a', 1);
      cache.put('a', 99);
      expect(cache.get('a'), 99);
      expect(cache.length, 1);
    });

    test('length tracks entries', () {
      final cache = LruSelectionCache<int>(capacity: 10);
      expect(cache.length, 0);
      cache.put('a', 1);
      cache.put('b', 2);
      expect(cache.length, 2);
      cache.remove('a');
      expect(cache.length, 1);
    });
  });
}
