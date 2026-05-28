import 'package:agentkit_core/agentkit_core.dart';
import 'package:test/test.dart';

void main() {
  final migrator = MigrateAgentEntriesMigrator();

  group('MigrateAgentEntriesMigrator inputSchema', () {
    test('preserves required and primitive property types', () {
      const before = '''
MCPCallEntry.tool(
  definition: MCPToolDefinition(
    name: 'calculate_fibonacci',
    description: 'Fibonacci',
    inputSchema: ObjectSchema(
      properties: {
        'n': IntegerSchema(minimum: 0, maximum: 100),
      },
      required: ['n'],
    ),
  ),
  handler: (final request) => MCPCallResult(
    message: 'ok',
    parameters: const {},
  ),
);
''';
      final migrated = migrator.migrateSource(before);
      expect(migrated, contains("'required': <String>['n']"));
      expect(migrated, contains("'n': {'type': 'integer'}"));
      expect(migrated, isNot(contains('TODO(migrate):')));
    });

    test('preserves top-level ObjectSchema property as object type', () {
      const before = '''
MCPCallEntry.tool(
  definition: MCPToolDefinition(
    name: 'wait_for',
    description: 'wait',
    inputSchema: ObjectSchema(
      properties: {
        'predicate': ObjectSchema(),
      },
      required: ['predicate'],
    ),
  ),
  handler: (final request) => MCPCallResult(
    message: 'ok',
    parameters: const {},
  ),
);
''';
      final migrated = migrator.migrateSource(before);
      expect(migrated, contains("'predicate': {'type': 'object'}"));
      expect(migrated, contains("'required': <String>['predicate']"));
      expect(migrated, isNot(contains(r"'kind'")));
      expect(migrated, isNot(contains('TODO(migrate):')));
    });

    test('preserves top-level ArraySchema without items', () {
      const before = '''
MCPCallEntry.tool(
  definition: MCPToolDefinition(
    name: 'list_tool',
    description: 'list',
    inputSchema: ObjectSchema(
      properties: {
        'ids': ArraySchema(),
      },
      required: ['ids'],
    ),
  ),
  handler: (final request) => MCPCallResult(
    message: 'ok',
    parameters: const {},
  ),
);
''';
      final migrated = migrator.migrateSource(before);
      expect(migrated, contains("'ids': {'type': 'array'}"));
      expect(migrated, contains("'required': <String>['ids']"));
      expect(migrated, isNot(contains('TODO(migrate):')));
    });

    test('preserves ArraySchema with primitive items', () {
      const before = '''
MCPCallEntry.tool(
  definition: MCPToolDefinition(
    name: 'tags_tool',
    description: 'tags',
    inputSchema: ObjectSchema(
      properties: {
        'tags': ArraySchema(items: StringSchema()),
      },
      required: ['tags'],
    ),
  ),
  handler: (final request) => MCPCallResult(
    message: 'ok',
    parameters: const {},
  ),
);
''';
      final migrated = migrator.migrateSource(before);
      expect(
        migrated,
        contains("'tags': {'type': 'array', 'items': {'type': 'string'}}"),
      );
      expect(migrated, contains("'required': <String>['tags']"));
      expect(migrated, isNot(contains('TODO(migrate):')));
    });

    test('preserves fill_form-shaped ArraySchema ObjectSchema items', () {
      const before = '''
MCPCallEntry.tool(
  definition: MCPToolDefinition(
    name: 'fill_form',
    description: 'fill',
    inputSchema: ObjectSchema(
      properties: {
        'fields': ArraySchema(
          items: ObjectSchema(
            properties: {
              'ref': StringSchema(),
              'text': StringSchema(),
            },
            required: ['ref', 'text'],
          ),
        ),
      },
      required: ['fields'],
    ),
  ),
  handler: (final request) => MCPCallResult(
    message: 'ok',
    parameters: const {},
  ),
);
''';
      final migrated = migrator.migrateSource(before);
      expect(migrated, contains("'type': 'array'"));
      expect(migrated, contains("'type': 'object'"));
      expect(migrated, contains("'ref'"));
      expect(migrated, contains("'text'"));
      expect(migrated, contains("'type': 'string'"));
      expect(
        migrated,
        contains("'required': <String>['ref', 'text']"),
      );
      expect(migrated, contains("'required': <String>['fields']"));
      expect(migrated, isNot(contains('TODO(migrate):')));
    });

    test('emits TODO when ArraySchema items are nested arrays', () {
      const before = '''
MCPCallEntry.tool(
  definition: MCPToolDefinition(
    name: 'matrix_tool',
    description: 'matrix',
    inputSchema: ObjectSchema(
      properties: {
        'rows': ArraySchema(
          items: ArraySchema(items: StringSchema()),
        ),
      },
      required: ['rows'],
    ),
  ),
  handler: (final request) => MCPCallResult(
    message: 'ok',
    parameters: const {},
  ),
);
''';
      final migrated = migrator.migrateSource(before);
      expect(migrated, contains("'rows'"));
      expect(migrated, contains("'type': 'array'"));
      expect(migrated, isNot(contains(r"'items': {")));
      expect(migrated, contains('TODO(migrate):'));
      expect(migrated, contains('nested ArraySchema items'));
    });

    test('preserves nested ObjectSchema inner properties', () {
      const before = '''
MCPCallEntry.tool(
  definition: MCPToolDefinition(
    name: 'wait_for',
    description: 'wait',
    inputSchema: ObjectSchema(
      properties: {
        'predicate': ObjectSchema(
          properties: {'kind': StringSchema()},
          required: ['kind'],
        ),
      },
      required: ['predicate'],
    ),
  ),
  handler: (final request) => MCPCallResult(
    message: 'ok',
    parameters: const {},
  ),
);
''';
      final migrated = migrator.migrateSource(before);
      expect(migrated, contains("'predicate': {"));
      expect(migrated, contains("'kind'"));
      expect(migrated, contains("'type': 'string'"));
      expect(migrated, contains("'required': <String>['kind']"));
      expect(migrated, isNot(contains('TODO(migrate):')));
    });

    test('preserves top-level additionalProperties: false', () {
      const before = '''
MCPCallEntry.tool(
  definition: MCPToolDefinition(
    name: 'tap_widget',
    description: 'tap',
    inputSchema: ObjectSchema(
      additionalProperties: false,
      properties: {
        'ref': StringSchema(),
      },
      required: ['ref'],
    ),
  ),
  handler: (final request) => MCPCallResult(
    message: 'ok',
    parameters: const {},
  ),
);
''';
      final migrated = migrator.migrateSource(before);
      expect(migrated, contains("'additionalProperties': false,"));
      expect(migrated, contains("'required': <String>['ref']"));
      expect(migrated, isNot(contains('TODO(migrate):')));
    });

    test('preserves nested additionalProperties: true on object property', () {
      const before = '''
MCPCallEntry.tool(
  definition: MCPToolDefinition(
    name: 'wait_for',
    description: 'wait',
    inputSchema: ObjectSchema(
      additionalProperties: false,
      properties: {
        'predicate': ObjectSchema(
          additionalProperties: true,
          properties: {'kind': StringSchema()},
          required: ['kind'],
        ),
      },
      required: ['predicate'],
    ),
  ),
  handler: (final request) => MCPCallResult(
    message: 'ok',
    parameters: const {},
  ),
);
''';
      final migrated = migrator.migrateSource(before);
      expect(migrated, contains("'additionalProperties': false,"));
      expect(migrated, contains("'additionalProperties': true,"));
      expect(migrated, contains("'required': <String>['predicate']"));
      expect(migrated, isNot(contains('TODO(migrate):')));
    });

    test('emits TODO when properties cannot be parsed', () {
      const before = '''
MCPCallEntry.tool(
  definition: MCPToolDefinition(
    name: 'custom',
    description: 'custom',
    inputSchema: ObjectSchema(
      properties: {
        'payload': UnknownSchema(),
      },
    ),
  ),
  handler: (final request) => MCPCallResult(
    message: 'ok',
    parameters: const {},
  ),
);
''';
      final migrated = migrator.migrateSource(before);
      expect(migrated, contains('TODO(migrate):'));
      expect(migrated, contains('unparsed property entries'));
      expect(migrated, contains("'properties': <String, Object?>{},"));
    });
  });
}
