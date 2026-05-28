import 'package:agentkit_core/agentkit_core.dart';
import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

Set<AgentCallEntry> buildStarterEntries() => {
  AgentCallEntry.tool(
    namespace: 'app',
    name: 'ping_tool',
    description: 'Returns pong',
    inputSchema: const {
      'type': 'object',
      'properties': <String, Object?>{},
    },
    handler: (final args) async {
      final request = args.map(
        (final key, final value) => MapEntry(key, value?.toString() ?? ''),
      );
      final _result = MCPCallResult(
            message: 'pong',
            parameters: const {'ok': true},
          );
      final message = _result['message'] as String? ?? '';
      final data = Map<String, Object?>.from(_result)..remove('message');
      return AgentResult.success(message: message, data: data);
    },
  ),
  AgentCallEntry.resource(
    namespace: 'app',
    name: 'app_status',
    description: 'App status resource',
    mimeType: 'application/json',
    handler: (final args) async {
      final request = args.map(
        (final key, final value) => MapEntry(key, value?.toString() ?? ''),
      );
      final _result = MCPCallResult(
            message: 'status',
            parameters: const {'ready': true},
          );
      final message = _result['message'] as String? ?? '';
      final data = Map<String, Object?>.from(_result)..remove('message');
      return AgentResult.success(message: message, data: data);
    },
  ),
};
