import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:test/test.dart';

void main() {
  test('rejects missing required field', () {
    const schema = {
      'type': 'object',
      'additionalProperties': false,
      'required': ['ref'],
      'properties': {'ref': {'type': 'string'}},
    };
    expect(
      () => validateAgainstSchema(schema, {}),
      throwsA(isA<AgentValidationException>()),
    );
  });

  test('rejects unknown properties when additionalProperties is false', () {
    const schema = {
      'type': 'object',
      'additionalProperties': false,
      'properties': {'ref': {'type': 'string'}},
    };
    expect(
      () => validateAgainstSchema(schema, {'extra': 'x'}),
      throwsA(isA<AgentValidationException>()),
    );
  });
}
