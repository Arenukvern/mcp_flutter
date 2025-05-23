// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:dap/dap.dart' as dap;
import 'package:devtools_mcp_extension/core/devtools_core/service/vm_service_wrapper.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/primitives/trees.dart';

class DapObjectNode extends TreeNode<DapObjectNode> {
  DapObjectNode({
    required this.variable,
    required final VmServiceWrapper service,
  }) : _service = service;

  final dap.Variable variable;
  final VmServiceWrapper _service;

  Future<void> fetchChildren() async {
    // If we have already fetched children for this variable,
    // then do nothing instead of re-fetching.
    if (this.children.isNotEmpty) return;

    // If `variablesReference` is > 0, then the variable is
    // structured, meaning it has children.
    final hasChildren = variable.variablesReference > 0;
    if (!hasChildren) return;

    final variablesResponse = await _service.dapVariablesRequest(
      dap.VariablesArguments(variablesReference: variable.variablesReference),
    );
    final children = variablesResponse?.variables ?? [];
    for (final child in children) {
      addChild(DapObjectNode(variable: child, service: _service));
    }
  }

  @override
  DapObjectNode shallowCopy() {
    throw UnimplementedError(
      'This method is not implemented. Implement if you '
      'need to call `shallowCopy` on an instance of this class.',
    );
  }
}
