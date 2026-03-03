// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:flutter_inspector_mcp_server/src/base_server.dart';
import 'package:flutter_inspector_mcp_server/src/core/services/core_port_scanner.dart';

/// Compatibility wrapper around the shared core port scanner.
class PortScanner {
  const PortScanner({required this.server});

  final BaseMCPToolkitServer server;

  CorePortScanner get _core => CorePortScanner(
    logger: (final level, final message, {final logger = 'PortScanner'}) =>
        server.log(level, message, logger: logger),
  );

  Future<List<int>> scanForFlutterPorts() => _core.scanForFlutterPorts();

  Future<bool> isPortAccessible(final int port) => _core.isPortAccessible(port);

  List<int> get commonFlutterPorts => _core.commonFlutterPorts;
}
