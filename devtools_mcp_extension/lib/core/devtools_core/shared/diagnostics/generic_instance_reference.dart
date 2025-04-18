// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

/// @docImport 'inspector_service.dart';
/// @docImport 'primitives/instance_ref.dart';
library;

import 'package:devtools_mcp_extension/core/devtools_core/shared/diagnostics/diagnostics_node.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/memory/heap_object.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/memory/simple_items.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/utils/vm_utils.dart';
import 'package:vm_service/vm_service.dart';

/// True, if [ref] contains static or live information about references and thus
/// makes the node expandable.
bool isRootForReferences(final GenericInstanceRef? ref) {
  if (ref == null) return false;
  if (ref is! ObjectReferences) {
    return ref.heapSelection != null;
  }

  if (ref.instanceRef?.length == 0 ||
      isPrimitiveInstanceKind(ref.instanceRef?.kind)) {
    return false;
  }

  return ref.refNodeType.isRoot;
}

/// A generic [InstanceRef] using either format used by the [InspectorService]
/// or Dart VM.
///
/// Either one or both of [value] and [diagnostic] may be provided. The
/// `valueRef` getter on the [diagnostic] should refer to the same object as
/// [instanceRef] although using the [InspectorInstanceRef] scheme.
/// A [RemoteDiagnosticsNode] is used rather than an [InspectorInstanceRef] as
/// the additional data provided by [RemoteDiagnosticsNode] is helpful to
/// correctly display the object and [RemoteDiagnosticsNode] includes a
/// reference to an [InspectorInstanceRef]. [value] must be a VM service type,
/// Sentinel, or primitive type.
class GenericInstanceRef {
  GenericInstanceRef({
    required this.isolateRef,
    this.value,
    this.diagnostic,
    this.heapSelection,
  });

  final Object? value;

  final HeapObject? heapSelection;

  InstanceRef? get instanceRef =>
      value is InstanceRef ? value as InstanceRef? : null;

  /// If both [diagnostic] and [instanceRef] are provided, `diagnostic.valueRef`
  /// must reference the same underlying object just using the
  /// [InspectorInstanceRef] scheme.
  final RemoteDiagnosticsNode? diagnostic;

  final IsolateRef? isolateRef;
}

class ObjectReferences extends GenericInstanceRef {
  ObjectReferences({
    required this.refNodeType,
    required IsolateRef super.isolateRef,
    required super.value,
    required super.heapSelection,
  }) {
    if (refNodeType.isLive) assert(value != null);
  }

  ObjectReferences.copyWith(
    final ObjectReferences ref, {
    final RefNodeType? refNodeType,
    final HeapObject? heapSelection,
  }) : refNodeType = refNodeType ?? ref.refNodeType,
       super(
         isolateRef: ref.isolateRef,
         value: ref.value,
         heapSelection: heapSelection ?? ref.heapSelection,
       );

  final RefNodeType refNodeType;

  @override
  HeapObject get heapSelection => super.heapSelection!;

  @override
  IsolateRef get isolateRef => super.isolateRef!;

  int? get childCount {
    final result = heapSelection.countOfReferences(refNodeType.direction);
    if (result != null) return result;

    final instance = value;
    if (instance is! InstanceRef) return null;

    return instance.length;
  }
}

enum RefNodeType {
  /// Root item for references.
  refRoot,

  /// Subitem of [refRoot] for static references.
  staticRefRoot,

  /// Subitem of [staticRefRoot] for inbound static references.
  staticInRefs(RefDirection.inbound),

  /// Subitem of [staticRefRoot] for outbound static references.
  staticOutRefs(RefDirection.outbound),

  /// Subitem of [refRoot] for live references.
  liveRefRoot,

  /// Subitem of [liveRefRoot] for inbound live references.
  liveInRefs(RefDirection.inbound),

  /// Subitem of [liveRefRoot] for outbound live references.
  liveOutRefs(RefDirection.outbound);

  const RefNodeType([this.direction]);

  final RefDirection? direction;

  bool get isRoot => const {refRoot, staticRefRoot, liveRefRoot}.contains(this);

  bool get isLive =>
      const {liveOutRefs, liveInRefs, liveRefRoot}.contains(this);
}
