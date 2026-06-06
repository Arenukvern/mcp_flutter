import 'dart:io';

import 'package:flutter_mcp_toolkit_server/src/cli/migrate_agent_entries_command.dart';
import 'package:test/test.dart';

void main() {
  final migrator = MigrateAgentEntriesMigrator();
  final fixturesDir = Directory('test/fixtures/migrate');

  group('MigrateAgentEntriesMigrator', () {
    test('migrates starter tool and resource fixtures', () {
      final before = File(
        '${fixturesDir.path}/before_starter_entries.dart',
      ).readAsStringSync();
      final after = File(
        '${fixturesDir.path}/after_starter_entries.dart',
      ).readAsStringSync();
      final migrated = migrator.migrateSource(before);
      expect(migrated, after);
    });

    test('migrates extension type Set and implements clauses', () {
      final before = File(
        '${fixturesDir.path}/before_extension_type.dart',
      ).readAsStringSync();
      final migrated = migrator.migrateSource(before);
      expect(migrated, contains('Set<AgentCallEntry>'));
      expect(migrated, contains('implements AgentCallEntry'));
      expect(migrated, contains('AgentCallEntry.tool('));
      expect(migrated, isNot(contains('MCPCallEntry.tool(')));
    });

    test('wouldChange is false for already migrated source', () {
      final after = File(
        '${fixturesDir.path}/after_starter_entries.dart',
      ).readAsStringSync();
      expect(migrator.wouldChange(after), isFalse);
    });

    test('preserves ObjectSchema required and primitive property types', () {
      const before = '''
import 'package:mcp_toolkit/mcp_toolkit.dart';

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
    });

    test('adds intentcall imports when missing', () {
      final before = File(
        '${fixturesDir.path}/before_starter_entries.dart',
      ).readAsStringSync();
      final migrated = migrator.migrateSource(before);
      expect(
        migrated,
        contains("import 'package:intentcall_core/intentcall_core.dart';"),
      );
      expect(
        migrated,
        contains("import 'package:intentcall_schema/intentcall_schema.dart';"),
      );
    });
  });

  group('runMigrateAgentEntries', () {
    late Directory tmp;

    setUp(
      () => tmp = Directory.systemTemp.createTempSync('migrate_agent_entries_'),
    );
    tearDown(() => tmp.deleteSync(recursive: true));

    test('--check exits 1 when migrations are pending', () async {
      final file = File('${tmp.path}/entries.dart')
        ..writeAsStringSync(
          File(
            '${fixturesDir.path}/before_starter_entries.dart',
          ).readAsStringSync(),
        );

      final exitCode = await runMigrateAgentEntries(
        path: file.path,
        checkOnly: true,
        write: false,
      );
      expect(exitCode, 1);
    });

    test('--write applies migration in place', () async {
      final file = File('${tmp.path}/entries.dart')
        ..writeAsStringSync(
          File(
            '${fixturesDir.path}/before_starter_entries.dart',
          ).readAsStringSync(),
        );
      final expected = File(
        '${fixturesDir.path}/after_starter_entries.dart',
      ).readAsStringSync();

      final exitCode = await runMigrateAgentEntries(
        path: file.path,
        checkOnly: false,
        write: true,
      );

      expect(exitCode, 0);
      expect(file.readAsStringSync(), expected);
    });

    test('returns 66 for missing path', () async {
      final exitCode = await runMigrateAgentEntries(
        path: '${tmp.path}/missing.dart',
        checkOnly: true,
        write: false,
      );
      expect(exitCode, 66);
    });
  });
}
