// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:flutter_inspector_mcp_server/src/shared_core/types/core_types.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/types/results.dart';

/// Host operations required by the live-edit command executor (core executor implements this).
abstract interface class LiveEditHostBindings {
  CoreRuntimeConfiguration get configuration;

  Future<CoreResult> hotReload({final bool force});

  Future<CoreResult> hotRestart();

  Future<CoreResult> runClientTool(
    final String toolName, {
    final Map<String, Object?> arguments = const <String, Object?>{},
  });

  Future<CoreResult> listClientToolsAndResources();

  Future<bool> waitForFlutterIsolateAfterRestart({
    final Duration timeout = const Duration(seconds: 10),
    final Duration pollInterval = const Duration(milliseconds: 250),
  });

  /// Evidence snapshot for resolve-draft (no view details, no errors).
  Future<CoreResult> captureUiSnapshotForLiveEdit();
}
