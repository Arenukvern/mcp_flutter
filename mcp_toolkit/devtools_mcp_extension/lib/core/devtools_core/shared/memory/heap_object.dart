// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_mcp_extension/core/devtools_core/shared/memory/class_name.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/memory/heap_data.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/memory/simple_items.dart';
import 'package:flutter/foundation.dart';

/// Object in a heap snapshot.
@immutable
class HeapObject {
  const HeapObject(this.heap, {required this.index});

  final HeapData heap;

  /// Index of the object in [heap].
  ///
  /// If  null, it means the object exists in the live app, but is not
  /// located in the heap.
  final int? index;

  Iterable<int>? _refs(final RefDirection direction) {
    final theIndex = index;
    if (theIndex == null) return null;

    switch (direction) {
      case RefDirection.inbound:
        return heap.graph.objects[theIndex].referrers;
      case RefDirection.outbound:
        return heap.graph.objects[theIndex].references;
    }
  }

  List<HeapObject> references(final RefDirection direction) =>
      (_refs(direction) ?? []).map((final i) => HeapObject(heap, index: i)).toList();

  int? countOfReferences(final RefDirection? direction) =>
      direction == null ? null : _refs(direction)?.length;

  HeapObject withoutObject() {
    if (index == null) return this;
    return HeapObject(heap, index: null);
  }

  HeapClassName? get className {
    final theIndex = index;
    if (theIndex == null) return null;
    final theClass = heap.graph.classes[heap.graph.objects[theIndex].classId];
    return HeapClassName.fromHeapSnapshotClass(theClass);
  }

  int? get code =>
      index == null ? null : heap.graph.objects[index!].identityHashCode;

  int? get retainedSize => index == null ? null : heap.retainedSizes?[index!];
}

typedef HeapDataCallback = HeapData Function();
