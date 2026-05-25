import 'package:agentkit_core/agentkit_core.dart';
import 'package:agentkit_schema/agentkit_schema.dart';

import 'mcp_models.dart';

/// Bridges legacy [MCPCallEntry] to [AgentCallEntry] for AgentRegistry flows.
extension MCPCallEntryAgentBridge on MCPCallEntry {
  /// Converts this MCP service-extension entry to an [AgentCallEntry].
  ///
  /// Pass [inputSchema] when the MCP [ObjectSchema] should map to agentkit
  /// validation (defaults to an empty object schema).
  AgentCallEntry toAgentCallEntry({
    required final String namespace,
    final InputSchema? inputSchema,
  }) {
    final methodName = key;
    if (hasTool) {
      final definition = value.toolDefinition!;
      return AgentCallEntry.tool(
        namespace: namespace,
        name: definition.name,
        description: definition.description,
        inputSchema: inputSchema ??
            const {
              'type': 'object',
              'properties': <String, Object?>{},
            },
        methodName: methodName,
        handler: (final args) async {
          final request = args.map(
            (final key, final value) =>
                MapEntry(key, value?.toString() ?? ''),
          );
          final result = await value.handler(request);
          final message = result['message'] as String? ?? '';
          final data = Map<String, Object?>.from(result)..remove('message');
          return AgentResult.success(message: message, data: data);
        },
      );
    }

    final definition = value.resourceDefinition!;
    return AgentCallEntry.resource(
      namespace: namespace,
      name: definition.name,
      description: definition.description,
      methodName: methodName,
      mimeType: definition['mimeType'] as String? ?? 'application/json',
      handler: (final args) async {
        final request = args.map(
          (final key, final value) => MapEntry(key, value?.toString() ?? ''),
        );
        final result = await value.handler(request);
        final message = result['message'] as String? ?? '';
        final data = Map<String, Object?>.from(result)..remove('message');
        return AgentResult.success(message: message, data: data);
      },
    );
  }
}
