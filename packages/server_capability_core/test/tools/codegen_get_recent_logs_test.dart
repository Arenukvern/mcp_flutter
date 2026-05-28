// packages/server_capability_core/test/tools/codegen_get_recent_logs_test.dart
import 'package:agentkit_core/agentkit_core.dart';
import 'package:agentkit_mcp/agentkit_mcp.dart';
import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:collection/collection.dart';
import 'package:flutter_mcp_toolkit_capability_core/src/tools/codegen/get_recent_logs_tool.dart';
import 'package:flutter_mcp_toolkit_capability_core/src/tools/log_tools.dart';
import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';
import 'package:flutter_mcp_toolkit_capability_kernel/testing.dart';
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';
import 'package:test/test.dart';

import '../_test_helpers.dart';

void main() {
  const schemaEquality = DeepCollectionEquality();

  group('get_recent_logs @AgentTool codegen', () {
    test('generated call entry exposes fmt namespace and bare tool name', () {
      final intent = getRecentLogsCallEntry.toRegistration();
      expect(intent.descriptor.namespace, 'fmt');
      expect(intent.descriptor.name, 'get_recent_logs');
      expect(intent.qualifiedName, 'fmt_get_recent_logs');
    });

    test('call entry inputSchema matches getRecentLogsInputSchema', () {
      expect(
        schemaEquality.equals(
          getRecentLogsInputSchema(),
          getRecentLogsCallEntry.toRegistration().descriptor.inputSchema,
        ),
        isTrue,
      );
    });

    test('agentCallEntryToToolRegistration registers and invokes via host path', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.success(data: <String>['line']);
      final ctx = FakeCapabilityContext(
        capabilityId: 'fmt',
        services: <Type, HostService>{CommandRunner: runner},
      );
      registerLogTools(ctx);

      final reg = ctx.registrationFor('get_recent_logs')!;
      final result = await reg.handler(const <String, Object?>{'count': 10});
      expect(result.ok, isTrue);
      expect(runner.executedCommands, hasLength(1));
      expect(
        runner.executedCommands.first,
        isA<GetRecentLogsCommand>().having((c) => c.count, 'count', 10),
      );
    });

    test('bridge round-trips through RegisteredAgentIntent execute', () async {
      final registration = agentCallEntryToToolRegistration(
        getRecentLogsCallEntry,
        handler: (_) async => AgentResult.success(
          data: <String, Object?>{'via': 'bridge'},
        ),
      );
      final intent = toolRegistrationToRegistration(
        capabilityId: 'fmt',
        registration: registration,
      );
      final result = await intent.execute(
        AgentInvocation(
          descriptor: intent.descriptor,
          arguments: const <String, Object?>{},
        ),
      );
      expect(result.ok, isTrue);
      expect(result.data['via'], 'bridge');
    });
  });
}
