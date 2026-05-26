import 'dart:convert';

import 'package:agentkit_core/agentkit_core.dart';

/// Builds `agent_manifest.json` for App Intents / Shortcuts codegen (Phase 3).
String generateAppleAgentManifest(
  final Iterable<AgentIntentDescriptor> descriptors,
) {
  final intents = <Map<String, Object?>>[];
  for (final descriptor in descriptors) {
    intents.add(<String, Object?>{
      'qualifiedName': descriptor.qualifiedName,
      'namespace': descriptor.namespace,
      'name': descriptor.name,
      'description': descriptor.description,
      'kind': descriptor.kind.name,
      if (descriptor.kind == AgentIntentKind.resource)
        'resourceUri': descriptor.effectiveResourceUri,
      if (descriptor.mimeType != null) 'mimeType': descriptor.mimeType,
      'inputSchema': descriptor.inputSchema,
    });
  }
  return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
    'version': 1,
    'platform': 'apple',
    'intents': intents,
  });
}
