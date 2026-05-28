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

  group('integer minimum and maximum', () {
    const schema = {
      'type': 'object',
      'properties': {
        'n': {'type': 'integer', 'minimum': 0, 'maximum': 100},
      },
    };

    test('accepts value at inclusive bounds', () {
      expect(() => validateAgainstSchema(schema, {'n': 0}), returnsNormally);
      expect(() => validateAgainstSchema(schema, {'n': 100}), returnsNormally);
      expect(() => validateAgainstSchema(schema, {'n': 50}), returnsNormally);
    });

    test('rejects value below minimum', () {
      expect(
        () => validateAgainstSchema(schema, {'n': -1}),
        throwsA(
          isA<AgentValidationException>().having(
            (e) => e.message,
            'message',
            contains('at least 0'),
          ),
        ),
      );
    });

    test('rejects value above maximum', () {
      expect(
        () => validateAgainstSchema(schema, {'n': 101}),
        throwsA(
          isA<AgentValidationException>().having(
            (e) => e.message,
            'message',
            contains('at most 100'),
          ),
        ),
      );
    });
  });

  group('array items object required/properties', () {
    const schema = {
      'type': 'object',
      'required': ['fields'],
      'properties': {
        'fields': {
          'type': 'array',
          'items': {
            'type': 'object',
            'additionalProperties': false,
            'required': ['ref', 'text'],
            'properties': {
              'ref': {'type': 'string'},
              'text': {'type': 'string'},
            },
          },
        },
      },
    };

    test('accepts valid field items', () {
      expect(
        () => validateAgainstSchema(schema, {
          'fields': [
            {'ref': 's_0', 'text': 'alice'},
          ],
        }),
        returnsNormally,
      );
    });

    test('rejects empty field object', () {
      expect(
        () => validateAgainstSchema(schema, {
          'fields': [{}],
        }),
        throwsA(
          isA<AgentValidationException>().having(
            (e) => e.message,
            'message',
            allOf(contains('ref'), contains('fields[0]')),
          ),
        ),
      );
    });

    test('rejects field object missing ref', () {
      expect(
        () => validateAgainstSchema(schema, {
          'fields': [
            {'text': 'x'},
          ],
        }),
        throwsA(
          isA<AgentValidationException>().having(
            (e) => e.message,
            'message',
            allOf(contains('ref'), contains('fields[0]')),
          ),
        ),
      );
    });
  });

  group('string enum', () {
    const schema = {
      'type': 'object',
      'properties': {
        'direction': {
          'type': 'string',
          'enum': ['up', 'down', 'left', 'right'],
        },
      },
    };

    test('accepts allowed enum value', () {
      expect(
        () => validateAgainstSchema(schema, {'direction': 'down'}),
        returnsNormally,
      );
    });

    test('rejects value outside enum', () {
      expect(
        () => validateAgainstSchema(schema, {'direction': 'sideways'}),
        throwsA(
          isA<AgentValidationException>().having(
            (e) => e.message,
            'message',
            allOf(contains('direction'), contains('one of')),
          ),
        ),
      );
    });
  });

  group('number minimum and maximum', () {
    const schema = {
      'type': 'object',
      'properties': {
        'ratio': {'type': 'number', 'minimum': 0, 'maximum': 1.5},
      },
    };

    test('accepts value within bounds', () {
      expect(() => validateAgainstSchema(schema, {'ratio': 1.0}), returnsNormally);
      expect(() => validateAgainstSchema(schema, {'ratio': 1.5}), returnsNormally);
    });

    test('rejects value outside bounds', () {
      expect(
        () => validateAgainstSchema(schema, {'ratio': -0.1}),
        throwsA(isA<AgentValidationException>()),
      );
      expect(
        () => validateAgainstSchema(schema, {'ratio': 2}),
        throwsA(isA<AgentValidationException>()),
      );
    });
  });
}
