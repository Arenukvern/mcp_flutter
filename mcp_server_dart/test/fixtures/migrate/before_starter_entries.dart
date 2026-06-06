import 'package:mcp_toolkit/mcp_toolkit.dart';

Set<MCPCallEntry> buildStarterEntries() => {
  MCPCallEntry.tool(
    definition: MCPToolDefinition(
      name: 'ping_tool',
      description: 'Returns pong',
      inputSchema: ObjectSchema(properties: const {}),
    ),
    handler: (final request) =>
        MCPCallResult(message: 'pong', parameters: const {'ok': true}),
  ),
  MCPCallEntry.resource(
    definition: MCPResourceDefinition(
      name: 'app_status',
      description: 'App status resource',
      mimeType: 'application/json',
    ),
    handler: (final request) =>
        MCPCallResult(message: 'status', parameters: const {'ready': true}),
  ),
};
