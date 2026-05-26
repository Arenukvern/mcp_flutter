import 'package:agentkit_core/agentkit_core.dart';
import 'package:agentkit_mcp/agentkit_mcp.dart';
import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:test/test.dart';

void main() {
  test('resourceRegistrationToRegistration invokes handler with uri', () async {
    final registration = ResourceRegistration(
      uri: 'visual://localhost/errors',
      name: 'app_errors',
      description: 'errors',
      mimeType: 'application/json',
      handler: (final uri) async => AgentResult.success(
        data: <String, Object?>{'uri': uri},
      ),
    );
    final intent = resourceRegistrationToRegistration(
      capabilityId: 'fmt',
      registration: registration,
    );
    expect(intent.descriptor.kind, AgentIntentKind.resource);
    final result = await intent.execute(
      AgentInvocation(
        descriptor: intent.descriptor,
        arguments: const <String, Object?>{'uri': 'custom://uri'},
      ),
    );
    expect(result.data['uri'], 'custom://uri');
  });
}
