// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

/// @docImport '../console/widgets/expandable_variable.dart';
library;

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/diagnostics/diagnostics_node.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/diagnostics/generic_instance_reference.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/diagnostics/helpers.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/diagnostics/inspector_service.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/memory/heap_object.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/primitives/trees.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/primitives/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

// TODO(jacobr): gracefully handle cases where the isolate has closed and
// InstanceRef objects have become sentinels.
class DartObjectNode extends TreeNode<DartObjectNode> {
  DartObjectNode._({
    this.name,
    this.text,
    this.ref,
    final int? offset,
    final int? childCount,
    this.artificialName = false,
    this.artificialValue = false,
    this.isRerootable = false,
  }) : _offset = offset,
       _childCount = childCount {
    indentChildren = ref?.diagnostic?.style != DiagnosticsTreeStyle.flat;
  }

  /// Creates a variable from a value that must be an VM service type or a
  /// primitive type.
  ///
  /// [value] should typically be an [InstanceRef] but can also be a [Sentinel]
  /// [ObjRef] or primitive type such as num or String.
  ///
  /// [artificialName] and [artificialValue] is used by [ExpandableVariable] to
  /// determine styling of `Text(name)` and `Text(displayValue)` respectively.
  /// Artificial names and values are rendered using `subtleFixedFontStyle` to
  /// put less emphasis on the name (e.g., for the root node of a JSON tree).
  factory DartObjectNode.fromValue({
    required final Object? value,
    required final IsolateRef? isolateRef,
    String? name,
    final bool artificialName = false,
    final bool artificialValue = false,
    final RemoteDiagnosticsNode? diagnostic,
    final HeapObject? heapSelection,
  }) {
    name = name ?? '';

    String? text;
    final heapClass = heapSelection?.className;
    if (heapClass == null) {
      text = null;
    } else {
      text = heapClass.className;
      final size = prettyPrintRetainedSize(heapSelection?.retainedSize);
      if (size != null) {
        text = '$text, retained size $size';
      }
    }

    return DartObjectNode._(
      name: name,
      text: text,
      ref: GenericInstanceRef(
        isolateRef: isolateRef,
        diagnostic: diagnostic,
        value: value,
        heapSelection: heapSelection,
      ),
      artificialName: artificialName,
      artificialValue: artificialValue,
    );
  }

  /// Creates a variable from a `String` which displays [value] with quotation
  /// marks.
  factory DartObjectNode.fromString({
    required final String? value,
    required final IsolateRef? isolateRef,
    String? name,
  }) {
    name = name ?? '';
    return DartObjectNode._(
      name: name,
      ref: GenericInstanceRef(
        isolateRef: isolateRef,
        value: value != null ? "'$value'" : null,
      ),
    );
  }

  /// Creates a list node from a list of values that must be VM service objects
  /// or primitives.
  ///
  /// [list] should be a list of VM service objects or primitives.
  ///
  /// [displayNameBuilder] is used to transform a list element that will be the
  /// child node's `value`.
  ///
  /// [childBuilder] is used to generate nodes for each child.
  ///
  /// [artificialChildValues] determines styling of `Text(displayValue)` for
  /// child nodes. Artificial values are rendered using `subtleFixedFontStyle`
  /// to put less emphasis on the value.
  factory DartObjectNode.fromList({
    required final String? type,
    required final List<Object?>? list,
    required final IsolateRef? isolateRef,
    String? name,
    final Object? Function(Object?)? displayNameBuilder,
    final List<DartObjectNode> Function(Object?)? childBuilder,
    final bool artificialChildValues = true,
  }) {
    name = name ?? '';
    return DartObjectNode._(
      name: name,
      ref: GenericInstanceRef(
        isolateRef: isolateRef,
        value: '$type (${_itemCount(list?.length ?? 0)})',
      ),
      artificialValue: true,
      childCount: list?.length ?? 0,
    )..addAllChildren([
      if (list != null)
        for (int i = 0; i < list.length; ++i)
          DartObjectNode.fromValue(
            name: '[$i]',
            value: displayNameBuilder?.call(list[i]) ?? list[i],
            isolateRef: isolateRef,
            artificialName: true,
            artificialValue: artificialChildValues,
          )..addAllChildren([
            if (childBuilder != null) ...childBuilder(list[i]),
          ]),
    ]);
  }

  factory DartObjectNode.create(
    final BoundVariable variable,
    final IsolateRef? isolateRef,
  ) {
    final value = variable.value;
    return DartObjectNode._(
      name: variable.name,
      ref: GenericInstanceRef(isolateRef: isolateRef, value: value),
    );
  }

  factory DartObjectNode.text(final String text) =>
      DartObjectNode._(text: text, artificialName: true);

  factory DartObjectNode.grouping(
    final GenericInstanceRef? ref, {
    required final int offset,
    required final int count,
  }) => DartObjectNode._(
    ref: ref,
    text: '[$offset - ${offset + count - 1}]',
    offset: offset,
    childCount: count,
  );

  factory DartObjectNode.references(
    final String text,
    final ObjectReferences ref, {
    final bool isRerootable = false,
  }) => DartObjectNode._(
    text: text,
    ref: ref,
    childCount: ref.childCount,
    isRerootable: isRerootable,
  );

  static const maxChildrenInGrouping = 100;

  final String? text;
  final String? name;

  /// [artificialName] is used by [ExpandableVariable] to determine styling of
  /// `Text(name)`. Artificial names are rendered using `subtleFixedFontStyle`
  /// to put less emphasis on the name (e.g., for the root node of a JSON tree).
  final bool artificialName;

  /// [artificialValue] is used by [ExpandableVariable] to determine styling of
  /// `Text(displayValue)`. Artificial names are rendered using
  /// `subtleFixedFontStyle` to put less emphasis on the value (e.g., for type
  /// names).
  final bool artificialValue;

  GenericInstanceRef? ref;

  /// The point to fetch the variable from (in the case of large variables that
  /// we fetch only parts of at a time).
  int get offset => _offset ?? 0;

  int? _offset;

  bool get isGroup => _offset != null;

  /// If true, the variable can be saved to console as a root.
  final bool isRerootable;

  int get childCount {
    if (_childCount != null) return _childCount!;

    final value = this.value;
    if (value is InstanceRef) {
      final instanceLength = value.length;
      if (instanceLength == null) return 0;
      return instanceLength - offset;
    }

    return 0;
  }

  int? _childCount;

  bool get isPartialObject {
    final value = this.value;
    // Only instance kinds can be partial:
    if (value is InstanceRef) {
      // Only instance kinds with a length property can be partial. See:
      // https://api.flutter.dev/flutter/vm_service/Instance/length.html
      final instanceLength = value.length;
      if (instanceLength == null) return false;
      return offset != 0 || childCount < instanceLength;
    }

    return false;
  }

  // TODO(elliette): Can remove this workaround once DWDS correctly returns
  // InstanceKind.kSet for the kind of `Sets`. See:
  // https://github.com/dart-lang/webdev/issues/2001
  bool get isSet {
    final value = this.value;
    if (value is InstanceRef) {
      final kind = value.kind ?? '';
      if (kind == InstanceKind.kSet) return true;
      final name = value.classRef?.name ?? '';
      if (name.contains('Set')) return true;
    }
    return false;
  }

  bool treeInitializeStarted = false;
  bool treeInitializeComplete = false;

  @override
  bool get isExpandable {
    final theRef = ref;
    final instanceRef = theRef?.instanceRef;

    if (isRootForReferences(ref)) return true;

    if (treeInitializeComplete || children.isNotEmpty || childCount > 0) {
      return children.isNotEmpty || childCount > 0;
    }
    final diagnostic = theRef?.diagnostic;
    if (diagnostic != null &&
        ((diagnostic.inlineProperties.isNotEmpty) || diagnostic.hasChildren)) {
      return true;
    }

    // TODO(jacobr): do something smarter to avoid expandable variable flicker.
    if (instanceRef != null) {
      if (instanceRef.kind == InstanceKind.kStackTrace) {
        return true;
      }
      return instanceRef.valueAsString == null;
    }
    final value = theRef?.value;
    return (value is! String?) && (value is! num?) && (value is! bool?);
  }

  Object? get value => ref?.value;

  // TODO(kenz): add custom display for lists with more than 100 elements
  String? get displayValue {
    if (text != null) {
      return text;
    }
    final value = this.value;

    String? valueStr;

    if (value == null) return null;

    if (value is InstanceRef) {
      final kind = value.kind;
      if (kind == InstanceKind.kStackTrace) {
        final depth = children.length;
        valueStr = 'StackTrace ($depth ${pluralize('frame', depth)})';
      } else if (kind == InstanceKind.kRecord) {
        // Note: `value.length` was added in vm_service >10.1.2, so we fall back
        // to `children.length` if it's not provide (this means we don't get
        // the count until the record is expanded):
        final count = value.length ?? children.length;
        valueStr =
            count == 0
                ? 'Record'
                : 'Record ($count ${pluralize('field', count)})';
      } else if (value.valueAsString == null) {
        valueStr = value.classRef?.name ?? '';
      } else {
        valueStr = value.valueAsString ?? '';
        if (value.valueAsStringIsTruncated == true) {
          valueStr += '...';
        }
        if (kind == InstanceKind.kString) {
          // TODO(devoncarew): Handle multi-line strings.
          valueStr = "'$valueStr'";
        }
      }
      // List, Map, Uint8List, Uint16List, etc...
      if (isList(value) ||
          kind == InstanceKind.kMap ||
          kind == InstanceKind.kSet) {
        // TODO(elliette): Determine the signature from type parameters, see:
        // https://api.flutter.dev/flutter/vm_service/ClassRef/typeParameters.html
        // DWDS provides us with a readable format including type parameters in
        // the classRef name, for the vm_service we fall back to just using the
        // kind:
        final name = _isPrivateName(valueStr) ? kind : valueStr;
        final itemLength = value.length;
        if (itemLength == null) return valueStr;
        return '$name (${_itemCount(itemLength)})';
      }
    } else if (value is Sentinel) {
      valueStr = value.valueAsString;
    } else if (value is TypeArgumentsRef) {
      valueStr = value.name;
    } else if (value is ObjRef) {
      valueStr = _stripReferenceToken(value.type);
    } else {
      valueStr = value.toString();
    }

    return valueStr;
  }

  bool _isPrivateName(final String name) => name.startsWith('_');

  static String _itemCount(final int count) =>
      '${nf.format(count)} ${pluralize('item', count)}';

  static String _stripReferenceToken(final String type) {
    if (type.startsWith('@')) {
      return '_${type.substring(1)}';
    }
    return '_$type';
  }

  @override
  String toString() {
    if (text != null) return text!;

    final instanceRef = ref!.instanceRef;
    final value =
        instanceRef is InstanceRef ? instanceRef.valueAsString : instanceRef;
    return '$name - $value';
  }


  bool? _isInspectable;

  @override
  DartObjectNode shallowCopy() {
    throw UnimplementedError(
      'This method is not implemented. Implement if you '
      'need to call `shallowCopy` on an instance of this class.',
    );
  }
}
