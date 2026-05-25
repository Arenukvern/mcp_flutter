import 'dart:convert';

import 'agent_result.dart';

/// Helpers for agent-stable JSON payloads (ecsly-style envelopes).
extension AgentResultEnvelope on AgentResult {
  static AgentResult envelope({
    required final String kind,
    required final Map<String, Object?> snapshot,
    final String message = 'ok',
    final int schemaVersion = 1,
    final Map<String, Object?>? extra,
  }) {
    return AgentResult.success(
      message: message,
      data: {
        'schema_version': schemaVersion,
        'kind': kind,
        'tool_name': kind,
        'snapshot': snapshot,
        'snapshot_json': jsonEncode(snapshot),
        if (extra != null) ...extra,
      },
    );
  }

  static AgentResult resourceEnvelope({
    required final String resourceName,
    required final Map<String, Object?> snapshot,
    final String mimeType = 'application/json',
    final int schemaVersion = 1,
  }) {
    final uri = resourceUriForName(resourceName);
    final text = jsonEncode(snapshot);
    final resource = <String, Object?>{
      'uri': uri,
      'mimeType': mimeType,
      'text': text,
    };
    return AgentResult.success(
      message: '$resourceName snapshot.',
      data: {
        'schema_version': schemaVersion,
        'kind': resourceName,
        'resource_name': resourceName,
        'resource_uri': uri,
        'mimeType': mimeType,
        'snapshot': snapshot,
        'snapshot_json': text,
        'resource': resource,
        'contents': <Map<String, Object?>>[resource],
      },
    );
  }

  /// `visual://localhost/a/b` from `a_b` name segments.
  static String resourceUriForName(final String name) {
    if (name.isEmpty) {
      return 'visual://localhost/unknown';
    }
    return 'visual://localhost/${name.split('_').join('/')}';
  }
}
