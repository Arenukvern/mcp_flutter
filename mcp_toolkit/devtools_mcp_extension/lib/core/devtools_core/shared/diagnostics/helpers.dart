// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/diagnostics/dart_object_node.dart';
import 'package:vm_service/vm_service.dart';

/// Gets object by object reference using offset and childCount from [variable]
/// for list items.
Future<Object?> getObject({
  required final IsolateRef? isolateRef,
  required final ObjRef value,
  required final ServiceManager serviceManager,
  final DartObjectNode? variable,
}) async {
  // Don't include the offset and count parameters if we are not fetching a
  // partial object. Offset and count parameters are only necessary to request
  // subranges of the following instance kinds:
  // https://api.flutter.dev/flutter/vm_service/VmServiceInterface/getObject.html
  if (variable == null || !variable.isPartialObject) {
    return serviceManager.service!.getObject(isolateRef!.id!, value.id!);
  }

  return serviceManager.service!.getObject(
    isolateRef!.id!,
    value.id!,
    offset: variable.offset,
    count: variable.childCount,
  );
}

bool isList(final ObjRef? ref) {
  if (ref is! InstanceRef) return false;
  final kind = ref.kind;
  if (kind == null) return false;
  return kind.endsWith('List') || kind == InstanceKind.kList;
}
