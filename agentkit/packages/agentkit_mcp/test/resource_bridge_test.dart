import 'package:agentkit_core/agentkit_core.dart';
import 'package:agentkit_mcp/agentkit_mcp.dart';
import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';
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
    expect(
      intent.descriptor.inputSchema,
      clientResourceReadInputSchema(),
    );
    final result = await intent.execute(
      AgentInvocation(
        descriptor: intent.descriptor,
        arguments: const <String, Object?>{'uri': 'custom://uri'},
      ),
    );
    expect(result.data['uri'], 'custom://uri');
  });

  test('resourceRegistrationToRegistration validates before handler', () {
    var handlerCalled = false;
    final registration = ResourceRegistration(
      uri: 'visual://localhost/errors',
      name: 'app_errors',
      description: 'errors',
      mimeType: 'application/json',
      handler: (final uri) async {
        handlerCalled = true;
        return AgentResult.success(
          data: <String, Object?>{'uri': uri},
        );
      },
    );
    final intent = resourceRegistrationToRegistration(
      capabilityId: 'fmt',
      registration: registration,
    );
    final invocation = AgentInvocation(
      descriptor: intent.descriptor,
      arguments: const <String, Object?>{},
    );

    expect(
      () => intent.execute(invocation),
      throwsA(isA<AgentValidationException>()),
    );
    expect(handlerCalled, isFalse);

    expect(
      () => intent.execute(
        AgentInvocation(
          descriptor: intent.descriptor,
          arguments: const <String, Object?>{
            'uri': 'custom://uri',
            'extra': true,
          },
        ),
      ),
      throwsA(isA<AgentValidationException>()),
    );
    expect(handlerCalled, isFalse);
  });

  test('resourceTemplateRegistrationToRegistration rejects unknown keys', () {
    final registration = ResourceTemplateRegistration(
      uriTemplate: 'visual://localhost/errors/{count}',
      name: 'application_errors',
      description: 'errors',
      mimeType: 'application/json',
      handler: (final uri) async => AgentResult.success(
        data: <String, Object?>{'uri': uri},
      ),
    );
    final intent = resourceTemplateRegistrationToRegistration(
      capabilityId: 'fmt',
      registration: registration,
    );

    expect(
      intent.descriptor.inputSchema,
      clientResourceTemplateReadInputSchema(),
    );

    expect(
      () => intent.execute(
        AgentInvocation(
          descriptor: intent.descriptor,
          arguments: const <String, Object?>{
            'uri': 'visual://localhost/errors/3',
            'unexpected': true,
          },
        ),
      ),
      throwsA(isA<AgentValidationException>()),
    );
  });
}
