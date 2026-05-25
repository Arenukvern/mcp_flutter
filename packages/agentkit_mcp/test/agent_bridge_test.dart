import 'package:agentkit_core/agentkit_core.dart';
import 'package:agentkit_mcp/agentkit_mcp.dart';
import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';
import 'package:test/test.dart';

void main() {
  test('toolRegistrationToRegistration maps MCP success', () async {
    final registration = ToolRegistration(
      name: 'echo',
      description: 'echo',
      inputSchema: const {'type': 'object', 'properties': <String, Object?>{}},
      handler: (_) async => CallToolResult(
        content: [TextContent(text: '{"ok":true}')],
      ),
    );
    final intent = toolRegistrationToRegistration(
      capabilityId: 'fmt',
      registration: registration,
    );
    final result = await intent.execute(
      AgentInvocation(
        descriptor: intent.descriptor,
        arguments: const {},
      ),
    );
    expect(result.ok, isTrue);
    expect(result.data['text'], '{"ok":true}');
  });
}
