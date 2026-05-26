import 'package:agentkit_core/agentkit_core.dart';
import 'package:test/test.dart';

import '../example/demo_ping_tool.dart';

void main() {
  test('generated demoPingRegistration invokes handler', () async {
    final registration = demoPingRegistration;
    expect(registration.qualifiedName, 'app_demo_ping');
    expect(registration.descriptor.inputSchema['required'], ['message']);

    final result = await registration.execute(
      AgentInvocation(
        descriptor: registration.descriptor,
        arguments: const {'message': 'hi'},
      ),
    );
    expect(result.ok, isTrue);
    expect(result.data['pong'], 'hi');
  });

  test('generated demoPingCallEntry registers via toRegistration', () {
    expect(demoPingCallEntry.name, 'demo_ping');
    expect(demoPingCallEntry.toRegistration().qualifiedName, 'app_demo_ping');
  });
}
