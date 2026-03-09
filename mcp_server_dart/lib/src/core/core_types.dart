// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:dart_mcp/server.dart';

/// Logging callback used by the shared core module.
typedef CoreLogger =
    void Function(LoggingLevel level, String message, {String logger});

/// Runtime configuration shared by MCP wrapper and CLI.
final class CoreRuntimeConfiguration {
  const CoreRuntimeConfiguration({
    required this.vmHost,
    required this.vmPort,
    required this.resourcesSupported,
    required this.imagesSupported,
    required this.dumpsSupported,
    required this.dynamicRegistrySupported,
    required this.saveImagesToFiles,
    this.flutterProjectDir,
    this.flutterDevice,
    this.stateRootDir,
  });

  final String vmHost;
  final int vmPort;
  final bool resourcesSupported;
  final bool imagesSupported;
  final bool dumpsSupported;
  final bool dynamicRegistrySupported;
  final bool saveImagesToFiles;
  final String? flutterProjectDir;
  final String? flutterDevice;
  final String? stateRootDir;
}
