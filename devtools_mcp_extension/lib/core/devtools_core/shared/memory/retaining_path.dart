// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:collection/collection.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/memory/class_name.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/memory/simple_items.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/primitives/utils.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

// ignore: avoid-dynamic, defined in package:collection
bool Function(List<dynamic>? list1, List<dynamic>? list2) _listEquality =
    const ListEquality().equals;

@visibleForTesting
class DebugRetainingPathUsage {
  /// Path is expected to be constructed for each object.
  int constructed = 0;

  /// Only unique paths are stored.
  int stored = 0;

  /// Only displayed paths are stringified.
  int stringified = 0;
}

/// A retaining path from the root to an object.
///
/// This class is used to represent the shortest retaining path from the root to an object.
///
/// Equal paths are not stored twice in memory.
/// The path does not include the retained object itself.
///
/// The retaining path is represented as a list of classes, ignoring information
/// about concrete instances and fields.
/// To get more detailed information about the retaining path for a specific object,
/// use [`leak_tracker/formattedRetainingPath`](https://github.com/dart-lang/leak_tracker/blob/f5620600a5ce1c44f65ddaa02001e200b096e14c/pkgs/leak_tracker/lib/src/leak_tracking/helpers.dart#L58).
@immutable
class PathFromRoot {
  PathFromRoot._(
    this.path, {
    @visibleForTesting final bool debugOmitClassesInRetainingPath = false,
  }) : assert(() {
         debugUsage.constructed++;
         return true;
       }()),
       hashCode = path.isEmpty ? _hashOfEmptyPath : Object.hashAll(path),
       classes = debugOmitClassesInRetainingPath ? const {} : path.toSet();

  /// For objects directly referenced from root.
  const PathFromRoot._empty()
    : path = const [],
      classes = const {},
      hashCode = _hashOfEmptyPath;

  factory PathFromRoot.forObject(
    final HeapSnapshotGraph graph, {
    required final List<int> shortestRetainers,
    required final int index,
  }) {
    HeapClassName objectClass(final int index) {
      final classId = graph.objects[index].classId;
      return HeapClassName.fromHeapSnapshotClass(graph.classes[classId]);
    }

    var nextIndex = shortestRetainers[index];
    if (nextIndex == heapRootIndex) {
      return empty;
    }

    final path = <HeapClassName>[];

    while (nextIndex != heapRootIndex) {
      final className = objectClass(nextIndex);
      path.add(className);
      nextIndex = shortestRetainers[nextIndex];
    }

    return PathFromRoot.fromPath(path);
  }

  factory PathFromRoot.fromPath(
    final List<HeapClassName> path, {
    @visibleForTesting final debugOmitClassesInRetainingPath = false,
  }) {
    if (path.isEmpty) return empty;
    final existingInstance = instances.lookup(
      PathFromRoot._(
        path,
        debugOmitClassesInRetainingPath: debugOmitClassesInRetainingPath,
      ),
    );
    if (existingInstance != null) return existingInstance;

    final newInstance = PathFromRoot._(
      List.unmodifiable(path),
      debugOmitClassesInRetainingPath: debugOmitClassesInRetainingPath,
    );

    instances.add(newInstance);
    assert(() {
      debugUsage.stored++;
      assert(instances.length == debugUsage.stored);
      return true;
    }());
    return newInstance;
  }

  @visibleForTesting
  static void resetSingletons() {
    _instances = null;
    debugUsage = DebugRetainingPathUsage();
  }

  @visibleForTesting
  static Set<PathFromRoot> get instances => _instances ??= <PathFromRoot>{};
  static Set<PathFromRoot>? _instances;

  @visibleForTesting
  static DebugRetainingPathUsage debugUsage = DebugRetainingPathUsage();

  static PathFromRoot empty = const PathFromRoot._empty();

  static const _hashOfEmptyPath = 0;

  /// The retaining path.
  ///
  /// Does not include both the root and the object itself.
  /// Starts from the immediate retainer of the object.
  final List<HeapClassName> path;

  final Set<HeapClassName> classes;

  @override
  bool operator ==(final Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is PathFromRoot && _listEquality(other.path, path);
  }

  @override
  final int hashCode;

  String toShortString({
    final String? delimiter,
    final bool inverted = false,
  }) => _asString(
    data: path.map((final e) => e.className).toList(),
    delimiter: _delimiter(
      delimiter: delimiter,
      inverted: inverted,
      isLong: false,
    ),
    inverted: inverted,
  );

  String toLongString({
    final String? delimiter,
    final bool inverted = false,
    final bool hideStandard = false,
  }) {
    final List<String> data;
    bool justAddedEllipsis = false;
    if (hideStandard) {
      data = [];
      for (final item in path.asMap().entries) {
        if (item.key == 0 ||
            item.key == path.length - 1 ||
            !item.value.isCreatedByGoogle) {
          data.add(item.value.fullName);
          justAddedEllipsis = false;
        } else if (!justAddedEllipsis) {
          data.add('...');
          justAddedEllipsis = true;
        }
      }
    } else {
      data = classes.map((final e) => e.fullName).toList();
    }

    return _asString(
      data: data,
      delimiter: _delimiter(
        delimiter: delimiter,
        inverted: inverted,
        isLong: true,
      ),
      inverted: inverted,
    );
  }

  static String _delimiter({
    required final String? delimiter,
    required final bool inverted,
    required final bool isLong,
  }) {
    if (delimiter != null) return delimiter;
    if (isLong) {
      return inverted ? '\n→ ' : '\n← ';
    }
    return inverted ? ' → ' : ' ← ';
  }

  static String _asString({
    required List<String> data,
    required final String delimiter,
    required final bool inverted,
  }) {
    assert(() {
      debugUsage.stringified++;
      return true;
    }());
    // Trailing separator is here to show object is referenced by root.
    data = data.joinWith(
      delimiter,
      includeTrailing: true,
      includeLeading: data.isNotEmpty,
    );
    if (inverted) data = data.reversed.toList();
    final result = data.join().trim();
    return result;
  }
}
