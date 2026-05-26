import 'package:agentkit_mcp/agentkit_mcp.dart';
import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:flutter_mcp_toolkit_capability_core/src/tools/codegen/get_recent_logs_tool.dart';
import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/host.dart';
import 'package:test/test.dart';

final class _CodegenLogCapability implements Capability {
  @override
  String get id => 'fmt';

  @override
  String get description => 'codegen log pilot';

  @override
  String get version => '0.0.0';

  @override
  Future<void> register(final CapabilityContext context) async {
    context.registerTool(
      agentCallEntryToToolRegistration(
        getRecentLogsCallEntry,
        handler: (_) async => AgentResult.success(
          data: <String, Object?>{'codegen': true},
        ),
      ),
    );
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  test('McpHost registry invokes fmt_get_recent_logs from @AgentTool codegen', () async {
    final host = McpHost();
    await host.registerCapability(_CodegenLogCapability());

    final result = await host.agentRegistry.invoke(
      'fmt_get_recent_logs',
      const <String, Object?>{},
    );
    expect(result.ok, isTrue);
    expect(result.data['codegen'], isTrue);
  });
}
