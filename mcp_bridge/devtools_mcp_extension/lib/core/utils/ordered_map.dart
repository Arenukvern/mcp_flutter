import 'package:flutter/material.dart';
import 'package:xsoulspace_foundation/xsoulspace_foundation.dart';

typedef MutableOrderedMapToKeyFunction<K, V> = K Function(V);

/// {@template ordered_map}
/// Generic ordered collection maintaining insertion order
/// with key-based access
/// {@endtemplate}
class MutableOrderedMap<K, V> with Iterable<K> {
  MutableOrderedMap();
  final _items = <K, V>{};
  final _orderedKeys = <K>[];

  Iterable<V> get values => _items.values;

  Iterable<MapEntry<K, V>> get entries => _items.entries;

  @override
  Iterator<K> get iterator => _orderedKeys.iterator;

  /// Returns items in insertion order
  List<V> get orderedValues {
    final values = <V>[];
    for (final key in _orderedKeys) {
      final value = _items[key];
      if (value == null) continue;
      values.add(value);
    }
    return values;
  }

  bool containsKey(final K key) => _items.containsKey(key);

  /// Adds item with validation
  @mustCallSuper
  void upsert(final K key, final V value) {
    _items[key] = value;
    _orderedKeys.add(key);
  }

  V? operator [](final K key) => _items[key];

  @mustCallSuper
  void remove(final K key) {
    _items.remove(key);
    _orderedKeys.remove(key);
  }

  @mustCallSuper
  void clear() {
    _items.clear();
    _orderedKeys.clear();
  }
}

/// {@template immutable_ordered_map}
/// Immutable ordered collection maintaining insertion order
/// with key-based access
/// {@endtemplate}
class ImmutableOrderedMap<K, V> with Iterable<K> {
  ImmutableOrderedMap({required this.toKey});
  final MutableOrderedMapToKeyFunction<K, V> toKey;
  Map<K, V> _items = const {};
  List<K> _orderedKeys = const [];
  List<V>? _valuesListCache;

  @override
  Iterator<K> get iterator => _orderedKeys.iterator;

  List<K> get keys => _orderedKeys.unmodifiable;

  /// Returns items in insertion order
  List<V> get orderedValues {
    if (_valuesListCache != null) return _valuesListCache!;
    final values = <V>[];
    for (final key in _orderedKeys) {
      final value = _items[key];
      if (value == null) continue;
      values.add(value);
    }
    return _valuesListCache ??= values.unmodifiable;
  }

  V? operator [](final K key) => _items[key];
  void operator []=(final K key, final V value) => upsert(key, value);

  /// Assigns all items from a map
  void assignAll(final Map<K, V> map) {
    _items = map.unmodifiable;
    _orderedKeys = map.keys.toList().unmodifiable;
    _valuesListCache = null;
  }

  /// Assigns all items from a list
  void assignAllOrdered(final List<V> items) {
    final newKeys = <K>[];
    final map = <K, V>{};
    for (final item in items) {
      final key = toKey(item);
      map[key] = item;
      newKeys.add(key);
    }
    _items = map.unmodifiable;
    _orderedKeys = newKeys.unmodifiable;
    _valuesListCache = null;
  }

  /// Adds item with validation
  @mustCallSuper
  void upsert(final K key, final V value, {final bool putFirst = true}) {
    final items = {..._items, key: value}.unmodifiable;
    final putLast = !putFirst;
    final orderedKeys =
        [if (putFirst) key, ..._orderedKeys, if (putLast) key].unmodifiable;
    _items = items.unmodifiable;
    _orderedKeys = orderedKeys.unmodifiable;
    _valuesListCache = null;
  }

  @mustCallSuper
  void remove(final K key) {
    final items = {..._items}..remove(key);
    final orderedKeys = [..._orderedKeys]..remove(key);
    _items = items.unmodifiable;
    _orderedKeys = orderedKeys.unmodifiable;
    _valuesListCache = null;
  }

  @mustCallSuper
  void clear() {
    _items = <K, V>{}.unmodifiable;
    _orderedKeys = <K>[].unmodifiable;
    _valuesListCache = null;
  }
}
