// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:dart_mcp/server.dart';

/// Interface for accessing VM service configuration.
typedef VMServiceConfigurationRecord =
    ({
      String vmHost,
      int vmPort,
      bool resourcesSupported,
      bool imagesSupported,
      bool dumpsSupported,
      bool dynamicRegistrySupported,
      String logLevel,
      String environment,
    });

abstract base class BaseMCPToolkitServer extends MCPServer
    with LoggingSupport, ToolsSupport, ResourcesSupport {
  BaseMCPToolkitServer.fromStreamChannel(
    super.channel, {
    required this.configuration,
    required super.implementation,
    required super.instructions,
    super.protocolLogSink,
  }) : super.fromStreamChannel();

  final VMServiceConfigurationRecord configuration;
}
