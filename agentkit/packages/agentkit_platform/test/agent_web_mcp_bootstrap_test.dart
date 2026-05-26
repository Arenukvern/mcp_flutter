import 'package:agentkit_core/agentkit_core.dart';
import 'package:agentkit_platform/agentkit_platform.dart';
import 'package:test/test.dart';

void main() {
  test('AgentWebMcpBootstrap.registerFromEntries is safe on VM', () {
    expect(
      () => AgentWebMcpBootstrap.registerFromEntries(<AgentCallEntry>{}),
      returnsNormally,
    );
  });
}
