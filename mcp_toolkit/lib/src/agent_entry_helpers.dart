import 'package:agentkit_core/agentkit_core.dart';
import 'package:agentkit_schema/agentkit_schema.dart';

import 'mcp_models.dart';

const _defaultToolkitNamespace = 'mcp';

const _emptyObjectSchema = <String, Object?>{
  'type': 'object',
  'properties': <String, Object?>{},
};

/// Builds an [AgentCallEntry] tool from legacy [MCPToolDefinition] + handler shape.
AgentCallEntry mcpToolkitTool({
  required final MCPToolDefinition definition,
  required final MCPCallHandler handler,
  final String namespace = _defaultToolkitNamespace,
}) => AgentCallEntry.tool(
    namespace: namespace,
    name: definition.name,
    description: definition.description,
    inputSchema: _emptyObjectSchema,
    methodName: definition.name,
    handler: (final args) async {
      final request = _argsToServiceExtensionMap(args);
      final result = await handler(request);
      return _mcpResultToAgentResult(result);
    },
  );

/// Builds an [AgentCallEntry] resource from legacy [MCPResourceDefinition] + handler.
AgentCallEntry mcpToolkitResource({
  required final MCPResourceDefinition definition,
  required final MCPCallHandler handler,
  final String namespace = _defaultToolkitNamespace,
}) => AgentCallEntry.resource(
    namespace: namespace,
    name: definition.name,
    description: definition.description,
    methodName: definition.name,
    mimeType: definition['mimeType'] as String? ?? 'application/json',
    handler: (final args) async {
      final request = _argsToServiceExtensionMap(args);
      final result = await handler(request);
      return _mcpResultToAgentResult(result);
    },
  );

ServiceExtensionRequestMap _argsToServiceExtensionMap(final AgentArguments args) =>
    args.map((final key, final value) => MapEntry(key, value?.toString() ?? ''));

AgentResult _mcpResultToAgentResult(final MCPCallResult result) {
  final message = result['message'] as String? ?? '';
  final data = Map<String, Object?>.from(result)..remove('message');
  return AgentResult.success(message: message, data: data);
}

/// Service-extension wire format for [AgentResult] (legacy MCPCallResult shape).
Map<String, dynamic> agentResultToServiceExtensionMap(final AgentResult result) => {
  'message': result.message,
  ...result.data,
};
