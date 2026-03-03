import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('flutter_mcp_cli v2 one-shot', () {
    late Directory tempDir;
    late String statePath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('flutter_mcp_cli_v2_');
      statePath = '${tempDir.path}/state.json';
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('exec status returns JSON envelope with schema metadata', () async {
      final result = await _runCli(statePath, [
        'exec',
        '--name',
        'status',
        '--args',
        '{}',
      ]);
      expect(result.exitCode, equals(0));

      final jsonEnvelope =
          jsonDecode((result.stdout as String).trim()) as Map<String, dynamic>;
      expect(jsonEnvelope['ok'], isTrue);
      expect(jsonEnvelope['data'], isA<Map<String, dynamic>>());
      expect(
        (jsonEnvelope['data'] as Map<String, dynamic>)['connected'],
        isFalse,
      );

      final meta = jsonEnvelope['meta'] as Map<String, dynamic>;
      expect(meta['schemaVersion'], equals('core-envelope/v1'));
      expect(meta['command'], equals('status'));
      expect(meta['timestamp'], isA<String>());
    });

    test('schema returns full command catalog', () async {
      final result = await _runCli(statePath, ['schema']);
      expect(result.exitCode, equals(0));

      final envelope =
          jsonDecode((result.stdout as String).trim()) as Map<String, dynamic>;
      expect(envelope['ok'], isTrue);

      final data = envelope['data'] as Map<String, dynamic>;
      expect(data['schemaVersion'], equals('command-catalog/v1'));

      final commands = (data['commands'] as List).cast<Map<String, dynamic>>();
      final names = commands.map((final c) => c['name'] as String).toSet();
      expect(names.contains('status'), isTrue);
      expect(names.contains('get_vm'), isTrue);
      expect(names.contains('session_start'), isTrue);
    });

    test('schema supports per-command lookup', () async {
      final result = await _runCli(statePath, ['schema', '--name', 'status']);
      expect(result.exitCode, equals(0));

      final envelope =
          jsonDecode((result.stdout as String).trim()) as Map<String, dynamic>;
      expect(envelope['ok'], isTrue);

      final data = envelope['data'] as Map<String, dynamic>;
      final command = data['command'] as Map<String, dynamic>;
      expect(command['name'], equals('status'));
      expect(command['inputSchema'], isA<Map<String, dynamic>>());
      expect(command['outputSchema'], isA<Map<String, dynamic>>());
    });

    test('capabilities returns feature model', () async {
      final result = await _runCli(statePath, ['capabilities']);
      expect(result.exitCode, equals(0));

      final envelope =
          jsonDecode((result.stdout as String).trim()) as Map<String, dynamic>;
      expect(envelope['ok'], isTrue);

      final data = envelope['data'] as Map<String, dynamic>;
      expect(data['protocolVersion'], equals('flutter-mcp-cli/2.0'));
      expect(data['schemaVersion'], equals('command-catalog/v1'));
      expect((data['features'] as Map<String, dynamic>)['serve'], isTrue);
    });

    test(
      'exec invalid command returns deterministic error descriptor',
      () async {
        final result = await _runCli(statePath, [
          'exec',
          '--name',
          'does_not_exist',
          '--args',
          '{}',
        ]);
        expect(result.exitCode, equals(64));

        final envelope =
            jsonDecode((result.stdout as String).trim())
                as Map<String, dynamic>;
        expect(envelope['ok'], isFalse);
        final error = envelope['error'] as Map<String, dynamic>;
        expect(error['code'], equals('invalid_command'));
        expect(error['retryable'], isFalse);
        expect(error['exitCode'], equals(64));
        expect(error['category'], equals('validation'));
      },
    );

    test('exec rejects malformed nested connection object', () async {
      final result = await _runCli(statePath, [
        'exec',
        '--name',
        'get_vm',
        '--args',
        '{"connection":"not-an-object"}',
      ]);
      expect(result.exitCode, equals(64));

      final envelope =
          jsonDecode((result.stdout as String).trim()) as Map<String, dynamic>;
      expect(envelope['ok'], isFalse);
      final error = envelope['error'] as Map<String, dynamic>;
      expect(error['code'], equals('invalid_command'));
      expect((error['message'] as String).contains('expected object'), isTrue);
    });

    test(
      'exec rejects legacy flat host/port aliases on non-connect commands',
      () async {
        final result = await _runCli(statePath, [
          'exec',
          '--name',
          'get_vm',
          '--args',
          '{"host":"localhost","port":8181}',
        ]);
        expect(result.exitCode, equals(64));

        final envelope =
            jsonDecode((result.stdout as String).trim())
                as Map<String, dynamic>;
        expect(envelope['ok'], isFalse);
        final error = envelope['error'] as Map<String, dynamic>;
        expect(error['code'], equals('invalid_command'));
        expect(
          (error['message'] as String).contains('Use args.connection'),
          isTrue,
        );
      },
    );

    test(
      'exec connect rejects mixed native selector and args.connection',
      () async {
        final result = await _runCli(statePath, [
          'exec',
          '--name',
          'connect',
          '--args',
          '{"uri":"ws://localhost:8181/ws","connection":{"targetId":"ws://localhost:8181/ws"}}',
        ]);
        expect(result.exitCode, equals(64));

        final envelope =
            jsonDecode((result.stdout as String).trim())
                as Map<String, dynamic>;
        expect(envelope['ok'], isFalse);
        final error = envelope['error'] as Map<String, dynamic>;
        expect(error['code'], equals('invalid_command'));
        expect(
          (error['message'] as String).contains(
            'cannot combine args.connection',
          ),
          isTrue,
        );
      },
    );

    test('exec rejects legacy host:port connection.targetId', () async {
      final result = await _runCli(statePath, [
        'exec',
        '--name',
        'status',
        '--args',
        '{"connection":{"targetId":"localhost:8181"}}',
      ]);
      expect(result.exitCode, equals(67));

      final envelope =
          jsonDecode((result.stdout as String).trim()) as Map<String, dynamic>;
      expect(envelope['ok'], isFalse);
      final error = envelope['error'] as Map<String, dynamic>;
      expect(error['code'], equals('connect_failed'));
      expect(
        (error['message'] as String).contains(
          'host:port identifiers are no longer supported',
        ),
        isTrue,
      );
      final details = error['details'] as Map<String, dynamic>;
      expect(details['reason'], equals('invalid_target_id_legacy_host_port'));
      expect(details['migrationHint'], isA<String>());
    });

    test(
      'snapshot create + diff + bundle create are functional',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final createA = await _runCli(statePath, [
          'snapshot',
          'create',
          '--name',
          'a',
          '--args',
          '{"commands":[{"name":"status","args":{}}]}',
        ]);
        expect(createA.exitCode, equals(0));

        final createB = await _runCli(statePath, [
          'snapshot',
          'create',
          '--name',
          'b',
          '--args',
          '{"commands":[{"name":"status","args":{}}]}',
        ]);
        expect(createB.exitCode, equals(0));

        final diff = await _runCli(statePath, [
          'snapshot',
          'diff',
          '--from',
          'a',
          '--to',
          'b',
        ]);
        expect(diff.exitCode, equals(0));

        final diffEnvelope =
            jsonDecode((diff.stdout as String).trim()) as Map<String, dynamic>;
        expect(diffEnvelope['ok'], isTrue);
        expect(
          (diffEnvelope['data'] as Map<String, dynamic>)['summary'],
          isA<Map<String, dynamic>>(),
        );

        final bundleDir = '${tempDir.path}/bundle_out';
        final bundle = await _runCli(statePath, [
          'bundle',
          'create',
          '--from-snapshot',
          'a',
          '--output',
          bundleDir,
        ]);
        expect(bundle.exitCode, equals(0));

        final bundleEnvelope =
            jsonDecode((bundle.stdout as String).trim())
                as Map<String, dynamic>;
        expect(bundleEnvelope['ok'], isTrue);
        final data = bundleEnvelope['data'] as Map<String, dynamic>;
        expect(data['outputDirectory'], equals(bundleDir));
        expect(File('$bundleDir/manifest.json').existsSync(), isTrue);
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
