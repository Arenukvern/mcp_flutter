import 'package:mcp_toolkit/mcp_toolkit.dart';

Set<MCPCallEntry> getCustomEntries() => {OnDemoEntry()};

extension type OnDemoEntry._(MCPCallEntry entry) implements MCPCallEntry {
  factory OnDemoEntry() {
    final entry = MCPCallEntry.tool(
      definition: MCPToolDefinition(
        name: 'demo_action',
        description: 'Demo extension type entry',
        inputSchema: ObjectSchema(properties: const {}),
      ),
      handler: (final request) => MCPCallResult(
        message: 'demo',
        parameters: const {'done': true},
      ),
    );
    return OnDemoEntry._(entry);
  }
}
