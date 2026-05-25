import 'dart:async';

import 'package:agentkit_core/agentkit_core.dart';
import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/host.dart';
import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';
import 'package:test/test.dart';

final class _RegistryProbeCapability implements Capability {
  @override
  String get id => 'probe';

  @override
  String get description => 'probe';

  @override
  String get version => '0.0.0';

  @override
  Future<void> register(final CapabilityContext context) async {
    context.registerTool(
      ToolRegistration(
        name: 'ping',
        description: 'ping',
        inputSchema: const {'type': 'object'},
        handler: (_) async => CallToolResult(
          content: [TextContent(text: 'legacy')],
        ),
      ),
    );
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  test('MCP publish invokes AgentRegistry not handler directly', () async {
    final published =
        <String, FutureOr<CallToolResult> Function(CallToolRequest)>{};
    final host = McpHost(
      dispatchBridge: DartMcpDispatchBridge(
        publish: (final tool, final impl) {
          published[tool.name] = impl;
        },
        unpublish: (_) {},
      ),
    );
    await host.registerCapability(_RegistryProbeCapability());

    final mcpResult = await published['probe_ping']!(
      CallToolRequest(name: 'probe_ping', arguments: const {}),
    );
    expect(mcpResult.content.first, isA<TextContent>());
    expect((mcpResult.content.first as TextContent).text, 'legacy');

    final direct = await host.agentRegistry.invoke('probe_ping', const {});
    expect(direct.ok, isTrue);
    expect(direct.data['text'], 'legacy');
  });

  test('registry invoke returns failure when tool missing', () async {
    final host = McpHost();
    final result = await host.agentRegistry.invoke('missing_tool', const {});
    expect(result.ok, isFalse);
    expect(result.code, 'intent_not_found');
  });
}
