// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:collection/collection.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_mcp_extension/common_imports.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/memory/class_name.dart';
import 'package:vm_service/vm_service.dart';

bool isPrimitiveInstanceKind(final String? kind) =>
    kind == InstanceKind.kBool ||
    kind == InstanceKind.kDouble ||
    kind == InstanceKind.kInt ||
    kind == InstanceKind.kNull ||
    kind == InstanceKind.kString;

Future<ClassRef?> findClass(
  final String? isolateId,
  final HeapClassName className,
  final ServiceManager serviceManager,
) async {
  if (isolateId == null) return null;
  final service = serviceManager.service;
  if (service == null) return null;
  final classes = await service.getClassList(isolateId);
  return classes.classes?.firstWhere(className.matches);
}

/// Finds instance in isolate by class and identityHashCode.
Future<InstanceRef?> findInstance(
  final String? isolateId,
  final String? classId,
  final int? hashCode, {
  required final ServiceManager serviceManager,
  required final ValueNotifier<int> refLimit,
}) async {
  if (classId == null ||
      isolateId == null ||
      hashCode == null ||
      hashCode == 0) {
    return null;
  }

  final result = (await serviceManager.service!.getInstances(
    isolateId,
    classId,
    refLimit.value,
  )).instances?.firstWhereOrNull(
    (final instance) =>
        (instance is InstanceRef) && (instance.identityHashCode == hashCode),
  );

  if (result is InstanceRef) return result;
  return null;
}
