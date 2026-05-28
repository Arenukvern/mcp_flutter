// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'agent_result.dart';

/// Copies `inputSchema` from a registerDynamics resource payload, or
/// [clientResourceReadInputSchema] when omitted.
InputSchema inputSchemaFromDynamicRegistrationMap(
  final Map<String, Object?> registration,
) {
  final raw = registration['inputSchema'];
  if (raw == null) {
    return clientResourceReadInputSchema();
  }
  if (raw is! Map) {
    throw ArgumentError('Resource registration inputSchema must be a Map');
  }
  return _deepCopySchemaMap(Map<Object?, Object?>.from(raw));
}

/// Default read-args schema for dynamic client resources (`fmt_client_resource`).
InputSchema clientResourceReadInputSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': <String>['uri'],
  'properties': <String, Object?>{
    'uri': <String, Object?>{
      'type': 'string',
      'description': 'Resource URI to read.',
    },
  },
};

/// Default read-args schema for dynamic client resource templates
/// (e.g. `visual://localhost/app/errors/{count}`).
InputSchema clientResourceTemplateReadInputSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': <String>['uri'],
  'properties': <String, Object?>{
    'uri': <String, Object?>{
      'type': 'string',
      'description': 'Concrete resource URI matching the template.',
    },
    'count': <String, Object?>{'type': 'integer'},
  },
};

InputSchema _deepCopySchemaMap(final Map<Object?, Object?> raw) => raw.map(
  (final key, final value) =>
      MapEntry(key.toString(), _normalizeSchemaValue(value)),
);

Object? _normalizeSchemaValue(final Object? value) {
  if (value is Map) {
    return _deepCopySchemaMap(Map<Object?, Object?>.from(value));
  }
  if (value is Iterable && value is! String) {
    return value
        .map<Object?>(
          (final item) => item is Map
              ? _deepCopySchemaMap(Map<Object?, Object?>.from(item))
              : item,
        )
        .toList();
  }
  return value;
}
