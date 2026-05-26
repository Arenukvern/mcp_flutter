import 'dart:convert';

import 'package:agentkit_core/agentkit_core.dart';

import 'agent_manifest.dart';

/// Builds `agent_manifest.json` for web platform sync.
String generateWebAgentManifest(
  final Iterable<AgentIntentDescriptor> descriptors,
) {
  final tools = <Map<String, Object?>>[];
  for (final descriptor in descriptors) {
    tools.add(<String, Object?>{
      'qualifiedName': descriptor.qualifiedName,
      'namespace': descriptor.namespace,
      'name': descriptor.name,
      'description': descriptor.description,
      'kind': descriptor.kind.name,
      if (descriptor.kind == AgentIntentKind.resource)
        'resourceUri': descriptor.effectiveResourceUri,
      'inputSchema': descriptor.inputSchema,
    });
  }
  return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
    'version': kAgentManifestSchemaVersion,
    'platform': 'web',
    'tools': tools,
  });
}
