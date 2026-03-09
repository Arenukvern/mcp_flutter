import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('flutter_mcp_cli v3 contracts', () {
    late Directory tempDir;
    late String statePath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'flutter_mcp_cli_contract_',
      );
      statePath = '${tempDir.path}/state.json';
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'global help and contextual subcommand help are distinct',
      () async {
        final globalHelp = await _runCli(statePath, ['--help']);
        expect(globalHelp.exitCode, equals(0));
        final global = (globalHelp.stdout as String);
        expect(global.contains('Usage:'), isTrue);
        expect(global.contains('snapshot create'), isTrue);
        expect(global.contains('doctor'), isTrue);
        expect(global.contains('validate-runtime'), isTrue);

        final snapshotHelp = await _runCli(statePath, [
          'snapshot',
          'create',
          '--help',
        ]);
        expect(snapshotHelp.exitCode, equals(0));
        final scoped = (snapshotHelp.stdout as String);
        expect(scoped.contains('snapshot create --name <id>'), isTrue);
        expect(scoped.contains('--check'), isTrue);
        expect(scoped.contains('--diff'), isTrue);
        expect(scoped.contains('--backup'), isTrue);
        expect(scoped.contains('--no-overwrite'), isTrue);
        expect(scoped.contains('Commands:'), isFalse);

        final doctorHelp = await _runCli(statePath, ['doctor', '--help']);
        expect(doctorHelp.exitCode, equals(0));
        final doctor = (doctorHelp.stdout as String);
        expect(
          doctor.contains(
            'doctor [--json] [--target <ws_uri>] [--timeout-ms <n>]',
          ),
          isTrue,
        );

        final validateHelp = await _runCli(statePath, [
          'validate-runtime',
          '--help',
        ]);
        expect(validateHelp.exitCode, equals(0));
        final validate = (validateHelp.stdout as String);
        expect(
          validate.contains('validate-runtime [--target <ws_uri>]'),
          isTrue,
        );
        expect(validate.contains('--connect-retries <n>'), isTrue);
        expect(validate.contains('--install-skill'), isTrue);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'schema exposes visual-debug commands with expected MCP visibility',
      () async {
        final schemaResult = await _runCli(statePath, ['schema']);
        expect(schemaResult.exitCode, equals(0));

        final envelope =
            jsonDecode((schemaResult.stdout as String).trim())
                as Map<String, dynamic>;
        expect(envelope['ok'], isTrue);

        final data = envelope['data'] as Map<String, dynamic>;
        final commands = (data['commands'] as List)
            .cast<Map<String, dynamic>>();
        final byName = <String, Map<String, dynamic>>{
          for (final command in commands) command['name'] as String: command,
        };

        expect(byName.containsKey('discover_debug_apps'), isTrue);
        expect(byName.containsKey('inspect_widget_at_point'), isTrue);
        expect(byName.containsKey('capture_ui_snapshot'), isTrue);
        expect(byName.containsKey('get_active_ports'), isTrue);
        expect(byName.containsKey('dynamicRegistryStats'), isTrue);

        expect(byName['discover_debug_apps']!['mcpExposed'], isTrue);
        expect(byName['inspect_widget_at_point']!['mcpExposed'], isTrue);
        expect(byName['capture_ui_snapshot']!['mcpExposed'], isTrue);
        expect(byName['get_active_ports']!['mcpExposed'], isFalse);
        expect(byName['dynamicRegistryStats']!['mcpExposed'], isFalse);
      },
    );

    test(
      'exec routes visual-debug commands via the shared command catalog',
      () async {
        final inspectResult = await _runCli(statePath, [
          'exec',
          '--name',
          'inspect_widget_at_point',
          '--args',
          '{"x":1,"y":1,"connection":{"uri":"ws://127.0.0.1:1/unreachable/ws"}}',
        ]);

        expect(inspectResult.exitCode, isNonZero);

        final envelope =
            jsonDecode((inspectResult.stdout as String).trim())
                as Map<String, dynamic>;
        expect(envelope['ok'], isFalse);
        final error = envelope['error'] as Map<String, dynamic>;
        final code = error['code'] as String;
        expect(code, isNot(equals('invalid_command')));
      },
    );

    test(
      'doctor emits required checks and critical-fail exit semantics',
      () async {
        final result = await _runCli(statePath, [
          'doctor',
          '--json',
          '--target',
          'ws://127.0.0.1:1/unreachable/ws',
          '--timeout-ms',
          '50',
        ]);

        expect(result.exitCode, isNonZero);

        final envelope =
            jsonDecode((result.stdout as String).trim())
                as Map<String, dynamic>;
        expect(envelope['ok'], isTrue);

        final data = envelope['data'] as Map<String, dynamic>;
        final checks = (data['checks'] as List).cast<Map<String, dynamic>>();
        expect(checks, isNotEmpty);

        final byId = {for (final check in checks) check['id'] as String: check};
        const expectedIds = {
          'dart_sdk',
          'flutter_sdk',
          'state_path_writable',
          'vm_target_reachable',
          'mcp_toolkit_extensions',
          'dynamic_registry_available',
        };
        expect(byId.keys.toSet(), containsAll(expectedIds));

        for (final id in expectedIds) {
          final check = byId[id]!;
          expect(check['id'], equals(id));
          expect(check['critical'], isA<bool>());
          expect(check['diagnostic'], isA<String>());
          expect(check['fix_command'], isA<String>());
          expect(
            const {'pass', 'warn', 'fail'}.contains(check['status']),
            isTrue,
          );
        }

        expect(byId['state_path_writable']!['critical'], isTrue);
        expect(byId['vm_target_reachable']!['critical'], isTrue);
      },
    );
  });
}

Future<ProcessResult> _runCli(final String statePath, final List<String> args) {
  final fullArgs = <String>[
    'run',
    'bin/flutter_mcp_cli.dart',
    '--state-file',
    statePath,
    ...args,
  ];
  return Process.run(
    'dart',
    fullArgs,
    workingDirectory: Directory.current.path,
  );
}
