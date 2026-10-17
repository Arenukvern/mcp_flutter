import 'dart:convert';

import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

import 'mcp_models.dart';

const _defaultToolkitNamespace = 'mcp';

/// Builds an [AgentCallEntry] tool from legacy [MCPToolDefinition] + handler shape.
AgentCallEntry mcpToolkitTool({
  required MCPToolDefinition definition,
  required MCPCallHandler handler,
  String namespace = _defaultToolkitNamespace,
}) => AgentCallEntry.tool(
  namespace: namespace,
  name: definition.name,
  description: definition.description,
  inputSchema: inputSchemaFromMcpToolDefinition(definition),
  methodName: definition.name,
  handler: (args) async {
    final request = _argsToServiceExtensionMap(args);
    final result = await handler(request);
    return _mcpResultToAgentResult(result);
  },
);

/// Builds an [AgentCallEntry] resource from legacy [MCPResourceDefinition] + handler.
AgentCallEntry mcpToolkitResource({
  required MCPResourceDefinition definition,
  required MCPCallHandler handler,
  String namespace = _defaultToolkitNamespace,
  InputSchema? inputSchema,
}) => AgentCallEntry.resource(
  namespace: namespace,
  name: definition.name,
  description: definition.description,
  methodName: definition.name,
  mimeType: definition['mimeType'] as String? ?? 'application/json',
  inputSchema: inputSchema ?? _resourceInputSchemaFromDefinition(definition),
  handler: (args) async {
    final request = _argsToServiceExtensionMap(args);
    final result = await handler(request);
    return _mcpResultToAgentResult(result);
  },
);

ServiceExtensionRequestMap _argsToServiceExtensionMap(
  AgentArguments args,
) => args.map(
  (key, value) => MapEntry(key, _wireArgForServiceExtension(value)),
);

String _wireArgForServiceExtension(Object? value) {
  if (value == null) {
    return '';
  }
  if (value is String) {
    return value;
  }
  if (value is num || value is bool) {
    return value.toString();
  }
  return jsonEncode(value);
}

AgentResult _mcpResultToAgentResult(MCPCallResult result) {
  final message = result['message'] as String? ?? '';
  final data = Map<String, Object?>.from(result)..remove('message');
  return AgentResult.success(message: message, data: data);
}

/// Service-extension wire format for [AgentResult] (legacy MCPCallResult shape).
Map<String, dynamic> agentResultToServiceExtensionMap(
  AgentResult result,
) => {'message': result.message, ...result.data};

InputSchema _resourceInputSchemaFromDefinition(
  MCPResourceDefinition definition,
) {
  final raw = definition['inputSchema'];
  if (raw == null) {
    return clientResourceReadInputSchema();
  }
  if (raw is! Map) {
    throw ArgumentError(
      'MCPResourceDefinition "${definition.name}" inputSchema must be a Map',
    );
  }
  return _deepCopyInputSchema(Map<Object?, Object?>.from(raw));
}

/// Copies [MCPToolDefinition.inputSchema] into intentcall [InputSchema] maps.
InputSchema inputSchemaFromMcpToolDefinition(
  MCPToolDefinition definition,
) {
  final raw = definition['inputSchema'];
  if (raw == null) {
    throw ArgumentError(
      'MCPToolDefinition "${definition.name}" is missing inputSchema',
    );
  }
  if (raw is! Map) {
    throw ArgumentError(
      'MCPToolDefinition "${definition.name}" inputSchema must be a Map',
    );
  }
  return _deepCopyInputSchema(Map<Object?, Object?>.from(raw));
}

Map<String, Object?> _deepCopyInputSchema(Map<Object?, Object?> raw) =>
    raw.map((key, value) {
      final normalized = _normalizeSchemaValue(value);
      return MapEntry(key.toString(), normalized);
    });

Object? _normalizeSchemaValue(Object? value) {
  if (value case final Map raw) {
    return _deepCopyInputSchema(Map<Object?, Object?>.from(raw));
  }
  if (value is Iterable && value is! String) {
    return value
        .map<Object?>(
          (item) => item is Map
              ? _deepCopyInputSchema(Map<Object?, Object?>.from(item))
              : item,
        )
        .toList();
  }
  return value;
}
