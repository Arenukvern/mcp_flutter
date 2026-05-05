import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('flutter-mcp-toolkit v3 contracts', () {
    late Directory tempDir;
    late String statePath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'flutter-mcp-toolkit_contract_',
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
        final global = globalHelp.stdout as String;
        expect(global.contains('Usage:'), isTrue);
        expect(global.contains('snapshot create'), isTrue);
        expect(global.contains('doctor'), isTrue);
        expect(
          global.contains('permissions status|request|open-settings'),
          isTrue,
        );
        expect(global.contains('validate-runtime'), isTrue);
        expect(global.contains('batch'), isTrue);
        expect(global.contains('--output-dir'), isTrue);

        final snapshotHelp = await _runCli(statePath, [
          'snapshot',
          'create',
          '--help',
        ]);
        expect(snapshotHelp.exitCode, equals(0));
        final scoped = snapshotHelp.stdout as String;
        expect(scoped.contains('snapshot create --name <id>'), isTrue);
        expect(scoped.contains('--check'), isTrue);
        expect(scoped.contains('--diff'), isTrue);
        expect(scoped.contains('--backup'), isTrue);
        expect(scoped.contains('--no-overwrite'), isTrue);
        expect(scoped.contains('Commands:'), isFalse);

        final doctorHelp = await _runCli(statePath, ['doctor', '--help']);
        expect(doctorHelp.exitCode, equals(0));
        final doctor = doctorHelp.stdout as String;
        expect(
          doctor.contains(
            'doctor [--json] [--target <ws_uri>] [--timeout-ms <n>]',
          ),
          isTrue,
        );

        final permissionsHelp = await _runCli(statePath, [
          'permissions',
          '--help',
        ]);
        expect(permissionsHelp.exitCode, equals(0));
        final permissions = permissionsHelp.stdout as String;
        expect(permissions.contains('permissions status'), isTrue);
        expect(permissions.contains('open-settings'), isTrue);

        final validateHelp = await _runCli(statePath, [
          'validate-runtime',
          '--help',
        ]);
        expect(validateHelp.exitCode, equals(0));
        final validate = validateHelp.stdout as String;
        expect(
          validate.contains('validate-runtime [--target <ws_uri>]'),
          isTrue,
        );
        expect(validate.contains('--connect-retries <n>'), isTrue);
        expect(validate.contains('--post-reload-delay-ms <n>'), isTrue);
        expect(validate.contains('--install-skill'), isTrue);

        final batchHelp = await _runCli(statePath, ['batch', '--help']);
        expect(batchHelp.exitCode, equals(0));
        final batch = batchHelp.stdout as String;
        expect(
          batch.contains('batch --steps <json> [--continue-on-error]'),
          isTrue,
        );
        expect(batch.contains('status"},{"name":"status'), isTrue);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test('batch executes multiple status steps in one invocation', () async {
      final result = await _runCli(statePath, [
        'batch',
        '--steps',
        '[{"name":"status"},{"name":"status","args":{}}]',
      ]);

      expect(result.exitCode, equals(0));

      final envelope =
          jsonDecode((result.stdout as String).trim()) as Map<String, dynamic>;
      expect(envelope['ok'], isTrue);

      final data = envelope['data'] as Map<String, dynamic>;
      final steps = (data['steps'] as List).cast<Map<String, dynamic>>();
      final summary = data['summary'] as Map<String, dynamic>;

      expect(steps, hasLength(2));
      expect(summary['total'], equals(2));
      expect(summary['executed'], equals(2));
      expect(summary['success'], equals(2));
      expect(summary['failed'], equals(0));
      expect(summary['continueOnError'], isFalse);

      for (var index = 0; index < steps.length; index += 1) {
        final step = steps[index];
        expect(step['index'], equals(index));
        expect(step['name'], equals('status'));
        expect(step['args'], isA<Map>());
        expect(step['ok'], isTrue);
        expect(step['error'], isNull);
        expect(step['data'], isA<Map>());
      }
    });

    test('batch reports step failure details for unknown commands', () async {
      final result = await _runCli(statePath, [
        'batch',
        '--steps',
        '[{"name":"status"},{"name":"unknown_command"}]',
      ]);

      expect(result.exitCode, isNonZero);

      final envelope =
          jsonDecode((result.stdout as String).trim()) as Map<String, dynamic>;
      expect(envelope['ok'], isFalse);
      final error = envelope['error'] as Map<String, dynamic>;
      expect(error['message'], contains('Batch stopped'));
      final details = error['details'] as Map<String, dynamic>;
      final steps = (details['steps'] as List).cast<Map<String, dynamic>>();
      final summary = details['summary'] as Map<String, dynamic>;

      expect(steps, hasLength(2));
      expect(steps[0]['ok'], isTrue);
      expect(steps[1]['ok'], isFalse);
      expect((steps[1]['error'] as Map<String, dynamic>)['code'], isNotEmpty);
      expect(summary['executed'], equals(2));
      expect(summary['failed'], equals(1));
      expect(summary['continueOnError'], isFalse);
    });

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
          'visual_capture_backend',
          'visual_capture_permission',
          'visual_capture_truth_mode',
          'app_permission_bridge',
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

    test('permissions preconnects before probing app-owned bridges', () async {
      final result = await _runCli(statePath, [
        '--flutter-device',
        'ios',
        '--vm-service-uri',
        'ws://127.0.0.1:1/unreachable/ws',
        'permissions',
        'status',
      ]);

      expect(result.exitCode, isNonZero);

      final envelope =
          jsonDecode((result.stdout as String).trim()) as Map<String, dynamic>;
      expect(envelope['ok'], isFalse);
      final error = envelope['error'] as Map<String, dynamic>;
      expect(error['code'], equals('connect_failed'));
    });

    test(
      'doctor reports app-owned bridge checks as connection-blocked when target is unreachable',
      () async {
        final result = await _runCli(statePath, [
          '--flutter-device',
          'ios',
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
        final byId = {for (final check in checks) check['id'] as String: check};

        expect(
          byId['app_permission_bridge']!['diagnostic'],
          contains('VM target is not connected'),
        );
      },
    );

    test('validate-runtime mirrors result envelope to output dir', () async {
      final outputDir = Directory('${tempDir.path}/artifacts');

      final result = await _runCli(statePath, [
        '--output-dir',
        outputDir.path,
        'validate-runtime',
        '--target',
        'ws://127.0.0.1:1/unreachable/ws',
        '--timeout-ms',
        '50',
      ]);

      expect(result.exitCode, isNonZero);

      final artifact = File('${outputDir.path}/validate-runtime.json');
      expect(artifact.existsSync(), isTrue);

      final envelope =
          jsonDecode(artifact.readAsStringSync()) as Map<String, dynamic>;
      expect(envelope['ok'], isFalse);
      expect((envelope['error'] as Map<String, dynamic>)['code'], isNotEmpty);
    });
  });
}

Future<ProcessResult> _runCli(final String statePath, final List<String> args) {
  final fullArgs = <String>[
    'run',
    'bin/flutter_mcp_toolkit.dart',
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
