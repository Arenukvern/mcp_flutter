import 'package:agentkit_core/agentkit_core.dart';
import 'package:agentkit_mcp/agentkit_mcp.dart';
import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:test/test.dart';

void main() {
  test('toolRegistrationToRegistration invokes AgentResult handler', () async {
    final registration = ToolRegistration(
      name: 'echo',
      description: 'echo',
      inputSchema: const {'type': 'object', 'properties': <String, Object?>{}},
      handler: (final args) async => AgentResult.success(
        data: const <String, Object?>{'text': '{"ok":true}'},
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

  test('toolRegistrationToRegistration validates before handler', () {
    var handlerCalled = false;
    final registration = ToolRegistration(
      name: 'strict',
      description: 'strict',
      inputSchema: const <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'required': <String>['ref'],
        'properties': <String, Object?>{
          'ref': <String, Object?>{'type': 'string'},
        },
      },
      handler: (final args) async {
        handlerCalled = true;
        return AgentResult.success(data: args);
      },
    );
    final intent = toolRegistrationToRegistration(
      capabilityId: 'fmt',
      registration: registration,
    );

    expect(
      () => intent.execute(
        AgentInvocation(
          descriptor: intent.descriptor,
          arguments: const <String, Object?>{},
        ),
      ),
      throwsA(isA<AgentValidationException>()),
    );
    expect(handlerCalled, isFalse);

    expect(
      () => intent.execute(
        AgentInvocation(
          descriptor: intent.descriptor,
          arguments: const <String, Object?>{
            'ref': 'ok',
            'extra': true,
          },
        ),
      ),
      throwsA(isA<AgentValidationException>()),
    );
    expect(handlerCalled, isFalse);
  });
}
