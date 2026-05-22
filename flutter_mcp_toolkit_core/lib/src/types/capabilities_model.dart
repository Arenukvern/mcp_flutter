// flutter_mcp_toolkit_core/lib/src/types/capabilities_model.dart
// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:meta/meta.dart';

@immutable
final class CapabilitiesModel {
  const CapabilitiesModel({
    required this.protocolVersion,
    required this.schemaVersion,
    required this.commands,
    required this.providers,
    required this.features,
    required this.limits,
  });

  final String protocolVersion;
  final String schemaVersion;
  final List<Map<String, Object?>> commands;
  final Map<String, Object?> providers;
  final Map<String, Object?> features;
  final Map<String, Object?> limits;

  Map<String, Object?> toJson() => {
    'protocolVersion': protocolVersion,
    'schemaVersion': schemaVersion,
    'commands': commands,
    'providers': providers,
    'features': features,
    'limits': limits,
  };
}
