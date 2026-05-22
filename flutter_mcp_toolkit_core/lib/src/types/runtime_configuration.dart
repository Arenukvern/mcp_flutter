// flutter_mcp_toolkit_core/lib/src/types/runtime_configuration.dart
// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:meta/meta.dart';

/// Runtime configuration shared by MCP wrapper and CLI.
@immutable
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
    this.outputDir,
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
  final String? outputDir;
}
