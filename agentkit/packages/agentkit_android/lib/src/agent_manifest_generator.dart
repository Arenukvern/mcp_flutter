import 'dart:convert';

import 'package:agentkit_core/agentkit_core.dart';

/// Builds `agent_manifest.json` for Android App Actions / shortcuts (Phase 3).
String generateAndroidAgentManifest(
  final Iterable<AgentIntentDescriptor> descriptors,
) {
  final shortcuts = <Map<String, Object?>>[];
  for (final descriptor in descriptors) {
    shortcuts.add(<String, Object?>{
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
    'version': 1,
    'platform': 'android',
    'shortcuts': shortcuts,
  });
}
