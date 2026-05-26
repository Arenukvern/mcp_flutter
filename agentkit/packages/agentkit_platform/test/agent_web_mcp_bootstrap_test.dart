import 'package:agentkit_core/agentkit_core.dart';
import 'package:agentkit_platform/agentkit_platform.dart';
import 'package:test/test.dart';

void main() {
  test('registerAgentWebMcpFromEntries is safe on VM', () {
    expect(
      () => registerAgentWebMcpFromEntries(<AgentCallEntry>{}),
      returnsNormally,
    );
  });
}
