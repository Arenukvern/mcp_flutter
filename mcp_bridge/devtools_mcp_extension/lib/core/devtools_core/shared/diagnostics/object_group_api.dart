// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/diagnostics/primitives/instance_ref.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

abstract class InspectorObjectGroupApi<T extends DiagnosticableTree>
    implements Disposable {
  bool get canSetSelectionInspector => false;

  Future<bool> setSelectionInspector(
    final InspectorInstanceRef selection,
    final bool uiAlreadyUpdated,
  ) => throw UnimplementedError();

  Future<Map<String, InstanceRef>?> getEnumPropertyValues(
    final InspectorInstanceRef ref,
  );

  Future<Map<String, InstanceRef>?> getDartObjectProperties(
    final InspectorInstanceRef inspectorInstanceRef,
    final List<String> propertyNames,
  );

  Future<List<T>> getChildren(
    final InspectorInstanceRef instanceRef,
    final bool summaryTree,
    final T? parent,
  );

  bool isLocalClass(final T node);

  Future<InstanceRef?> toObservatoryInstanceRef(
    final InspectorInstanceRef inspectorInstanceRef,
  );

  Future<List<T>> getProperties(final InspectorInstanceRef instanceRef);
}
