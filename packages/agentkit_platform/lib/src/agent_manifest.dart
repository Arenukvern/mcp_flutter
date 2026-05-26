import 'dart:convert';

import 'package:agentkit_core/agentkit_core.dart';

/// Supported [agent_manifest.json] schema version.
const kAgentManifestSchemaVersion = 1;

/// One tool/intent row from [agent_manifest.json].
final class AgentManifestEntry {
  const AgentManifestEntry({
    required this.qualifiedName,
    required this.namespace,
    required this.name,
    required this.description,
    required this.kind,
    required this.inputSchema,
    this.resourceUri,
  });

  factory AgentManifestEntry.fromJson(final Map<String, Object?> json) {
    final namespace = '${json['namespace'] ?? ''}'.trim();
    final name = '${json['name'] ?? ''}'.trim();
    final qualifiedName =
        '${json['qualifiedName'] ?? ''}'.trim().isNotEmpty
            ? '${json['qualifiedName']}'.trim()
            : qualifyName(namespace: namespace, name: name);
    final kindName = '${json['kind'] ?? 'tool'}'.trim();
    return AgentManifestEntry(
      qualifiedName: qualifiedName,
      namespace: namespace,
      name: name,
      description: '${json['description'] ?? ''}'.trim(),
      kind: AgentIntentKind.values.byName(kindName),
      inputSchema: _readInputSchema(json['inputSchema']),
      resourceUri: json['resourceUri'] as String?,
    );
  }

  final String qualifiedName;
  final String namespace;
  final String name;
  final String description;
  final AgentIntentKind kind;
  final Map<String, Object?> inputSchema;
  final String? resourceUri;

  Map<String, Object?> toJson() => <String, Object?>{
    'qualifiedName': qualifiedName,
    'namespace': namespace,
    'name': name,
    'description': description,
    'kind': kind.name,
    if (resourceUri != null) 'resourceUri': resourceUri,
    'inputSchema': inputSchema,
  };

  AgentIntentDescriptor toDescriptor() => AgentIntentDescriptor(
    namespace: namespace,
    name: name,
    description: description,
    kind: kind,
    inputSchema: inputSchema,
    resourceUri: resourceUri,
  );
}

/// Parsed canonical [agent_manifest.json].
final class AgentManifest {
  const AgentManifest({
    required this.version,
    required this.platform,
    required this.entries,
  });

  factory AgentManifest.fromJson(final Map<String, Object?> json) {
    final version = json['version'];
    if (version is! num || version.toInt() != kAgentManifestSchemaVersion) {
      throw FormatException(
        'Unsupported agent_manifest.json version: $version '
        '(expected $kAgentManifestSchemaVersion)',
      );
    }

    final entries = <AgentManifestEntry>[];
    for (final row in _entryRows(json)) {
      entries.add(AgentManifestEntry.fromJson(row));
    }

    return AgentManifest(
      version: version.toInt(),
      platform: '${json['platform'] ?? 'unknown'}',
      entries: entries,
    );
  }

  factory AgentManifest.parse(final String source) =>
      AgentManifest.fromJson(jsonDecode(source) as Map<String, Object?>);

  final int version;
  final String platform;
  final List<AgentManifestEntry> entries;

  Iterable<AgentManifestEntry> get tools =>
      entries.where((final entry) => entry.kind == AgentIntentKind.tool);
}

Iterable<Map<String, Object?>> _entryRows(final Map<String, Object?> json) sync* {
  for (final key in <String>['tools', 'shortcuts', 'intents']) {
    final value = json[key];
    if (value is! List) {
      continue;
    }
    for (final row in value) {
      if (row is Map<String, Object?>) {
        yield row;
        continue;
      }
      if (row is Map) {
        yield row.cast<String, Object?>();
      }
    }
  }
}

Map<String, Object?> _readInputSchema(final Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, Object?>();
  }
  return const <String, Object?>{'type': 'object'};
}
