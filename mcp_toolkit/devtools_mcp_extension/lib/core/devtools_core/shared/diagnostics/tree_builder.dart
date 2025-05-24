// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:math';

import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_mcp_extension/common_imports.dart'
    hide SentinelException;
import 'package:devtools_mcp_extension/core/devtools_core/shared/diagnostics/dart_object_node.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/diagnostics/diagnostics_node.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/diagnostics/generic_instance_reference.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/diagnostics/helpers.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/diagnostics/inspector_service.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/diagnostics/references.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/diagnostics/variable_factory.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/memory/heap_object.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/primitives/utils.dart';
import 'package:logging/logging.dart';
import 'package:vm_service/vm_service.dart';

final _log = Logger('tree_builder');

Future<void> _addExpandableChildren(
  final DartObjectNode variable,
  final List<DartObjectNode> children, {
  required final ServiceManager serviceManager,
  required final InspectorService? inspectorService,
  required final ValueNotifier<int> refLimit,
  final bool expandAll = false,
}) async {
  final tasks = <Future>[];
  for (final child in children) {
    if (expandAll) {
      tasks.add(
        buildVariablesTree(
          child,
          expandAll: expandAll,
          serviceManager: serviceManager,
          inspectorService: inspectorService,
          refLimit: refLimit,
        ),
      );
    }
    variable.addChild(child);
  }
  if (tasks.isNotEmpty) {
    await tasks.wait;
  }
}

Future<void> _addDiagnosticsIfNeeded({
  required final RemoteDiagnosticsNode? diagnostic,
  required final IsolateRef? isolateRef,
  required final DartObjectNode variable,
  required final ServiceManager serviceManager,
  required final InspectorService? inspectorService,
  required final ValueNotifier<int> refLimit,
}) async {
  if (diagnostic == null) return;

  final service = diagnostic.objectGroupApi;
  Future<void> addPropertiesHelper(
    final List<RemoteDiagnosticsNode>? properties,
  ) async {
    if (properties == null || service == null || isolateRef == null) return;
    await _addExpandableChildren(
      variable,
      await createVariablesForDiagnostics(service, properties, isolateRef),
      expandAll: true,
      serviceManager: serviceManager,
      inspectorService: inspectorService,
      refLimit: refLimit,
    );
  }

  if (diagnostic.inlineProperties.isNotEmpty) {
    await addPropertiesHelper(diagnostic.inlineProperties);
  } else {
    assert(!service!.disposed);
    if (!service!.disposed) {
      await addPropertiesHelper(await diagnostic.getProperties(service));
    }
  }
}

Future<void> _addDiagnosticChildrenIfNeeded({
  required final DartObjectNode variable,
  required final RemoteDiagnosticsNode? diagnostic,
  required final IsolateRef? isolateRef,
  required final bool expandAll,
  required final ServiceManager serviceManager,
  required final InspectorService? inspectorService,
  required final ValueNotifier<int> refLimit,
}) async {
  if (diagnostic == null) return;

  // Always add children last after properties to avoid confusion.
  final service = diagnostic.objectGroupApi;
  final diagnosticChildren = await diagnostic.children;
  if (diagnosticChildren != null && diagnosticChildren.isNotEmpty) {
    final childrenNode = DartObjectNode.text(
      pluralize('child', diagnosticChildren.length, plural: 'children'),
    );
    variable.addChild(childrenNode);
    if (service != null && isolateRef != null) {
      await _addExpandableChildren(
        childrenNode,
        await createVariablesForDiagnostics(
          service,
          diagnosticChildren,
          isolateRef,
        ),
        expandAll: expandAll,
        serviceManager: serviceManager,
        inspectorService: inspectorService,
        refLimit: refLimit,
      );
    }
  }
}

void _setupGrouping(final DartObjectNode variable) {
  final numChildrenInGrouping =
      variable.childCount >= pow(DartObjectNode.maxChildrenInGrouping, 2)
          ? (roundToNearestPow10(variable.childCount) /
                  DartObjectNode.maxChildrenInGrouping)
              .floor()
          : DartObjectNode.maxChildrenInGrouping;

  var start = variable.offset;
  final end = start + variable.childCount;
  while (start < end) {
    final count = min(end - start, numChildrenInGrouping);
    variable.addChild(
      DartObjectNode.grouping(variable.ref, offset: start, count: count),
    );
    start += count;
  }
}

void _addInstanceSetItems(
  final DartObjectNode variable,
  final IsolateRef? isolateRef,
  final InstanceSet instanceSet,
) {
  final instances = instanceSet.instances ?? [];
  variable.addAllChildren(
    createVariablesForInstanceSet(
      variable.offset,
      variable.childCount,
      instances,
      isolateRef,
    ),
  );
}

Future<void> _addInstanceRefItems({
  required final DartObjectNode variable,
  required final InstanceRef instanceRef,
  required final IsolateRef? isolateRef,
  required final ServiceManager serviceManager,
}) async {
  final ref = variable.ref;
  assert(ref is! ObjectReferences);

  final existingNames = <String>{};
  for (final child in variable.children) {
    final name = child.name;
    if (name != null && name.isNotEmpty) {
      existingNames.add(name);
      if (!isPrivateMember(name)) {
        // Assume private and public names with the same name reference the same
        // data so showing both is not useful.
        existingNames.add('_$name');
      }
    }
  }

  final result = await getObject(
    variable: variable,
    isolateRef: variable.ref!.isolateRef,
    value: instanceRef,
    serviceManager: serviceManager,
  );

  if (result is Instance) {
    _addChildrenToInstanceVariable(
      variable: variable,
      value: result,
      isolateRef: isolateRef,
      existingNames: existingNames,
      heapSelection: ref?.heapSelection?.withoutObject(),
    );
  }
}

/// Adds children to the variable.
void _addChildrenToInstanceVariable({
  required final DartObjectNode variable,
  required final Instance value,
  required final IsolateRef? isolateRef,
  required final HeapObject? heapSelection,
  final Set<String>? existingNames,
}) {
  switch (value.kind) {
    case InstanceKind.kMap:
      variable.addAllChildren(createVariablesForMap(value, isolateRef));
    case InstanceKind.kList:
      variable.addAllChildren(
        createVariablesForList(value, isolateRef, heapSelection),
      );
    case InstanceKind.kRecord:
      variable.addAllChildren(createVariablesForRecords(value, isolateRef));
    case InstanceKind.kUint8ClampedList:
    case InstanceKind.kUint8List:
    case InstanceKind.kUint16List:
    case InstanceKind.kUint32List:
    case InstanceKind.kUint64List:
    case InstanceKind.kInt8List:
    case InstanceKind.kInt16List:
    case InstanceKind.kInt32List:
    case InstanceKind.kInt64List:
    case InstanceKind.kFloat32List:
    case InstanceKind.kFloat64List:
    case InstanceKind.kInt32x4List:
    case InstanceKind.kFloat32x4List:
    case InstanceKind.kFloat64x2List:
      variable.addAllChildren(createVariablesForBytes(value, isolateRef));
    case InstanceKind.kRegExp:
      variable.addAllChildren(createVariablesForRegExp(value, isolateRef));
    case InstanceKind.kClosure:
      variable.addAllChildren(createVariablesForClosure(value, isolateRef));
    case InstanceKind.kReceivePort:
      variable.addAllChildren(createVariablesForReceivePort(value, isolateRef));
    case InstanceKind.kType:
      variable.addAllChildren(createVariablesForType(value, isolateRef));
    case InstanceKind.kTypeParameter:
      variable.addAllChildren(
        createVariablesForTypeParameters(value, isolateRef),
      );
    case InstanceKind.kFunctionType:
      variable.addAllChildren(
        createVariablesForFunctionType(value, isolateRef),
      );
    case InstanceKind.kWeakProperty:
      variable.addAllChildren(
        createVariablesForWeakProperty(value, isolateRef),
      );
    case InstanceKind.kStackTrace:
      variable.addAllChildren(createVariablesForStackTrace(value, isolateRef));
    case InstanceKind.kMirrorReference:
      variable.addAllChildren(
        createVariablesForMirrorReference(value, isolateRef),
      );
    case InstanceKind.kUserTag:
      variable.addAllChildren(createVariablesForUserTag(value, isolateRef));
    default:
      break;
  }

  if (variable.isSet) {
    variable.addAllChildren(createVariablesForSets(value, isolateRef));
  }

  if (value.fields != null && value.kind != InstanceKind.kRecord) {
    variable.addAllChildren(
      createVariablesForFields(value, isolateRef, existingNames: existingNames),
    );
  }
}

Future<void> _addValueItems({
  required final DartObjectNode variable,
  required final IsolateRef? isolateRef,
  required Object? value,
  required final ServiceManager serviceManager,
}) async {
  if (value is ObjRef) {
    value = await getObject(
      isolateRef: isolateRef,
      value: value,
      serviceManager: serviceManager,
    );
    switch (value.runtimeType) {
      case const (Func):
        final function = value! as Func;
        if (isolateRef == null) return;
        variable.addAllChildren(createVariablesForFunc(function, isolateRef));
      case const (Context):
        if (isolateRef == null) return;

        final context = value! as Context;
        variable.addAllChildren(createVariablesForContext(context, isolateRef));
    }
  } else if (value is! String && value is! num && value is! bool) {
    switch (value.runtimeType) {
      case const (Parameter):
        final parameter = value! as Parameter;
        variable.addAllChildren(
          createVariablesForParameter(parameter, isolateRef),
        );
    }
  }
}

Future<void> _addInspectorItems(
  final DartObjectNode variable,
  final IsolateRef? isolateRef, {
  required final InspectorService? inspectorService,
}) async {
  if (inspectorService != null) {
    final tasks = <Future>[];
    InspectorObjectGroupBase? group;
    Future<void> maybeUpdateRef(final DartObjectNode child) async {
      final childRef = child.ref;
      if (childRef == null) return;
      if (childRef.diagnostic == null) {
        // TODO(jacobr): also check whether the InstanceRef is an instance of
        // Diagnosticable and show the Diagnosticable properties in that case.
        final instanceRef = childRef.instanceRef;
        // This is an approximation of eval('instanceRef is DiagnosticsNode')
        // TODO(jacobr): cache the full class hierarchy so we can cheaply check
        // instanceRef is DiagnosticsNode without having to do an eval.
        if (instanceRef != null &&
            (instanceRef.classRef?.name == 'DiagnosticableTreeNode' ||
                instanceRef.classRef?.name == 'DiagnosticsProperty')) {
          // The user is expecting to see the object the DiagnosticsNode is
          // describing not the DiagnosticsNode itself.
          try {
            group ??= inspectorService.createObjectGroup('temp');
            final valueInstanceRef = await group!.evalOnRef(
              'object.value',
              childRef,
            );
            // TODO(jacobr): add the Diagnostics properties as well?
            child.ref = GenericInstanceRef(
              isolateRef: isolateRef,
              value: valueInstanceRef,
            );
          } catch (e) {
            if (e is! SentinelException) {
              _log.warning('Caught $e accessing the value of an object');
            }
          }
        }
      }
    }

    for (final child in variable.children) {
      tasks.add(maybeUpdateRef(child));
    }
    if (tasks.isNotEmpty) {
      await tasks.wait;
      unawaited(group?.dispose());
    }
  }
}

/// Builds the tree representation for a [DartObjectNode] object by querying
/// data, creating child [DartObjectNode] objects, and assigning parent-child
/// relationships.
///
/// We call this method as we expand variables in the variable tree, because
/// building the tree for all variable data at once is very expensive.
Future<void> buildVariablesTree(
  final DartObjectNode variable, {
  required final ServiceManager serviceManager,
  required final InspectorService? inspectorService,
  required final ValueNotifier<int> refLimit,
  final bool expandAll = false,
}) async {
  final ref = variable.ref;
  if (!variable.isExpandable || variable.treeInitializeStarted || ref == null) {
    return;
  }
  variable.treeInitializeStarted = true;

  final isolateRef = ref.isolateRef;
  final instanceRef = ref.instanceRef;
  final diagnostic = ref.diagnostic;
  final value = variable.value;

  await _addDiagnosticsIfNeeded(
    diagnostic: diagnostic,
    isolateRef: isolateRef,
    variable: variable,
    serviceManager: serviceManager,
    inspectorService: inspectorService,
    refLimit: refLimit,
  );

  try {
    if (ref is ObjectReferences) {
      await addChildReferences(
        variable: variable,
        refLimit: refLimit,
        serviceManager: serviceManager,
      );
    } else if (variable.childCount > DartObjectNode.maxChildrenInGrouping) {
      _setupGrouping(variable);
    } else if (instanceRef != null && serviceManager.service != null) {
      await _addInstanceRefItems(
        variable: variable,
        instanceRef: instanceRef,
        isolateRef: isolateRef,
        serviceManager: serviceManager,
      );
    } else if (value is InstanceSet) {
      _addInstanceSetItems(variable, isolateRef, value);
    } else if (value != null) {
      await _addValueItems(
        variable: variable,
        isolateRef: isolateRef,
        value: value,
        serviceManager: serviceManager,
      );
    }
  } on SentinelException {
    // Fail gracefully if calling `getObject` throws a SentinelException.
  } catch (ex, stack) {
    variable.addChild(DartObjectNode.text('error: $ex\n$stack'));
  }

  if (ref.heapSelection != null &&
      ref is! ObjectReferences &&
      !variable.isGroup) {
    addReferencesRoot(variable, ref);
  }

  await _addDiagnosticChildrenIfNeeded(
    variable: variable,
    diagnostic: diagnostic,
    isolateRef: isolateRef,
    expandAll: expandAll,
    serviceManager: serviceManager,
    inspectorService: inspectorService,
    refLimit: refLimit,
  );

  await _addInspectorItems(
    variable,
    isolateRef,
    inspectorService: inspectorService,
  );

  variable.treeInitializeComplete = true;
}
