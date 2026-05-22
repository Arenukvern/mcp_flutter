// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:dart_mcp/server.dart';

// CoreRuntimeConfiguration re-exported from flutter_mcp_toolkit_core.
export 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart'
    show CoreRuntimeConfiguration;

/// Logging callback used by the shared core module.
typedef CoreLogger =
    void Function(LoggingLevel level, String message, {String logger});
