import 'package:flutter/material.dart';
import 'package:xsoulspace_foundation/xsoulspace_foundation.dart';

/// {@template ordered_list}
/// Generic ordered collection maintaining insertion order
/// {@endtemplate}
class MutableOrderedList<V> with Iterable<V> {
  final _items = <V>[];

  @override
  Iterator<V> get iterator => _items.iterator;

  /// Adds item with validation
  @mustCallSuper
  void add(final V value) {
    _items.add(value);
  }

  @mustCallSuper
  void remove(final V value) {
    _items.remove(value);
  }

  @mustCallSuper
  void clear() {
    _items.clear();
  }
}

/// {@template immutable_ordered_list}
/// Immutable ordered collection maintaining insertion order
/// {@endtemplate}
class ImmutableOrderedList<V> with Iterable<V> {
  ImmutableOrderedList([this._items = const []]);
  List<V> _items;

  @override
  Iterator<V> get iterator => _items.iterator;

  /// Assigns all items from a map
  void assignAll(final List<V> items) {
    _items = items.unmodifiable;
  }

  /// Adds item with validation
  @mustCallSuper
  void add(final V value) {
    _items = [..._items, value].unmodifiable;
  }

  /// Adds item with validation if it doesn't already exist
  @mustCallSuper
  bool addUnique(final V value) {
    if (_items.contains(value)) return false;
    add(value);
    return true;
  }

  @mustCallSuper
  void remove(final V value) {
    _items = _items.where((final item) => item != value).toList().unmodifiable;
  }

  @mustCallSuper
  void clear() {
    _items = <V>[].unmodifiable;
  }
}
