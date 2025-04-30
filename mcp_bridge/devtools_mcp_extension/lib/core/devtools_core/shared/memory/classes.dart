// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:collection/collection.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/memory/class_filter.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/memory/class_name.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/memory/retaining_path.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

/// Statistical size-information about objects.
class ObjectSetStats {
  static ObjectSetStats? subtract({
    required ObjectSetStats? subtract,
    required ObjectSetStats? from,
  }) {
    from ??= _empty;
    subtract ??= _empty;

    final result =
        ObjectSetStats()
          ..instanceCount = from.instanceCount - subtract.instanceCount
          ..shallowSize = from.shallowSize - subtract.shallowSize
          ..retainedSize = from.retainedSize - subtract.retainedSize;

    if (result.isZero) return null;
    return result;
  }

  static final _empty = ObjectSetStats();

  int instanceCount = 0;
  int shallowSize = 0;
  int retainedSize = 0;

  /// True if the object set is empty.
  ///
  /// When count is zero, size still can be non-zero, because size
  /// of added and size of removed items may be different.
  bool get isZero =>
      shallowSize == 0 && retainedSize == 0 && instanceCount == 0;

  void countInstance(
    final HeapSnapshotGraph graph,
    final int index,
    final List<int>? retainedSizes, {
    required final bool excludeFromRetained,
  }) {
    if (!excludeFromRetained) {
      retainedSize += retainedSizes?[index] ?? 0;
    }
    shallowSize += graph.objects[index].shallowSize;
    instanceCount++;
  }

  void uncountInstance(
    final HeapSnapshotGraph graph,
    final int index,
    final List<int>? retainedSizes, {
    required final bool excludeFromRetained,
  }) {
    if (!excludeFromRetained) retainedSize -= retainedSizes?[index] ?? 0;
    shallowSize -= graph.objects[index].shallowSize;
    instanceCount--;
  }
}

/// Statistical and detailed size-information about objects.
class ObjectSet extends ObjectSetStats {
  /// Indexes of the objects in a heap snapshot.
  final indexes = <int>[];

  /// Indexes of objects that are excluded from the retained size
  /// calculation for this set.
  ///
  /// Subset of [indexes].
  ///
  /// See [countInstance].
  final excludedFromRetainedSize = <int>{};

  @override
  bool get isZero => indexes.isEmpty;

  @override
  void countInstance(
    final HeapSnapshotGraph graph,
    final int index,
    final List<int>? retainedSizes, {
    required final bool excludeFromRetained,
  }) {
    super.countInstance(
      graph,
      index,
      retainedSizes,
      excludeFromRetained: excludeFromRetained,
    );
    indexes.add(index);
    if (excludeFromRetained) excludedFromRetainedSize.add(index);
  }

  @override
  void uncountInstance(
    final HeapSnapshotGraph graph,
    final int index,
    final List<int>? retainedSizes, {
    required final bool excludeFromRetained,
  }) {
    throw AssertionError('uncountInstance is not valid for $ObjectSet');
  }
}

@immutable
/// List of classes with filtering support.
///
/// Is used to provide a list of classes to widgets.
class ClassDataList<T extends ClassData> {
  const ClassDataList(this._originalList)
    : _appliedFilter = null,
      _filtered = null;

  const ClassDataList._filtered({
    required final List<T> original,
    required final ClassFilter appliedFilter,
    required final List<T> filtered,
  }) : _originalList = original,
       _appliedFilter = appliedFilter,
       _filtered = filtered;

  /// The list of classes after filtering.
  List<T> get list => _filtered ?? _originalList;

  final List<T> _originalList;
  final ClassFilter? _appliedFilter;
  final List<T>? _filtered;

  Map<HeapClassName, T> asMap() => {
    for (final c in _originalList) c.className: c,
  };

  ClassDataList<T> filtered(
    final ClassFilter newFilter,
    final String? rootPackage,
  ) {
    final filtered = ClassFilter.filter(
      oldFilter: _appliedFilter,
      oldFiltered: _filtered,
      newFilter: newFilter,
      original: _originalList,
      extractClass: (final s) => s.className,
      rootPackage: rootPackage,
    );
    return ClassDataList._filtered(
      original: _originalList,
      appliedFilter: newFilter,
      filtered: filtered,
    );
  }

  T withMaxRetainedSize() => list.reduce(
    (final a, final b) =>
        a.objects.retainedSize > b.objects.retainedSize ? a : b,
  );

  /// Returns class data if [className] is presented in the [list].
  ClassData? byName(final HeapClassName? className) =>
      list.firstWhereOrNull((final c) => c.className == className);
}

/// A data for a class needed to display the class.
abstract class ClassData {
  ClassData({required this.className});

  ObjectSetStats get objects;
  Map<PathFromRoot, ObjectSetStats> get byPath;

  final HeapClassName className;

  bool contains(final PathFromRoot? path) {
    if (path == null) return false;
    return byPath.containsKey(path);
  }

  late final pathWithMaxRetainedSize = () {
    assert(byPath.isNotEmpty);
    return byPath.keys.reduce(
      (final a, final b) =>
          byPath[a]!.retainedSize > byPath[b]!.retainedSize ? a : b,
    );
  }();
}

/// A data for a single class, without diffing.
class SingleClassData extends ClassData {
  SingleClassData({required super.className});

  @override
  // ignore: avoid-explicit-type-declaration, required to override base class.
  final objects = ObjectSet();

  @override
  final byPath = <PathFromRoot, ObjectSetStats>{};

  void countInstance(
    final HeapSnapshotGraph graph, {
    required final int index,
    required final List<int>? retainers,
    required final List<int>? retainedSizes,
  }) {
    final path =
        retainers == null
            ? null
            : PathFromRoot.forObject(
              graph,
              shortestRetainers: retainers,
              index: index,
            );

    final excludeFromRetained =
        path != null &&
        retainedSizes != null &&
        path.classes.contains(className);

    objects.countInstance(
      graph,
      index,
      retainedSizes,
      excludeFromRetained: excludeFromRetained,
    );

    if (path != null) {
      byPath.putIfAbsent(path, ObjectSetStats.new);
      byPath[path]!.countInstance(
        graph,
        index,
        retainedSizes,
        excludeFromRetained: excludeFromRetained,
      );
    }
  }
}
