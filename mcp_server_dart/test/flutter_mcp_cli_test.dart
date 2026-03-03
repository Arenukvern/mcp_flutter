import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('flutter_mcp_cli', () {
    late Directory tempDir;
    late String statePath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('flutter_mcp_cli_');
      statePath = '${tempDir.path}/state.json';
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('status returns JSON envelope with schema metadata', () async {
      final result = await _runCli(statePath, ['status']);
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

    test('human mode prints readable status', () async {
      final result = await _runCli(statePath, ['--human', 'status']);

      expect(result.exitCode, equals(0));
      final stdout = result.stdout as String;
      expect(stdout.contains('[status] OK'), isTrue);
    });

    test('session_end without existing session returns not found', () async {
      final result = await _runCli(statePath, ['session_end']);
      expect(result.exitCode, equals(1));

      final envelope =
          jsonDecode((result.stdout as String).trim()) as Map<String, dynamic>;
      expect(envelope['ok'], isFalse);
      final error = envelope['error'] as Map<String, dynamic>;
      expect(error['code'], equals('session_not_found'));
    });

    test('diagnose returns normalized bundle report', () async {
      final result = await _runCli(statePath, ['diagnose']);
      expect(result.exitCode, equals(0));

      final envelope =
          jsonDecode((result.stdout as String).trim()) as Map<String, dynamic>;
      expect(envelope['ok'], isTrue);
      final data = envelope['data'] as Map<String, dynamic>;
      expect(data['steps'], isA<List>());
      expect(
        (data['summary'] as Map<String, dynamic>)['total'],
        greaterThan(0),
      );
    });

    test('watch emits NDJSON event stream with monotonic seq', () async {
      final result = await _runCli(statePath, [
        'watch',
        '--command',
        'status',
        '--interval-ms',
        '10',
        '--max-events',
        '2',
      ]);
      expect(result.exitCode, equals(0));

      final lines = (result.stdout as String)
          .split('\n')
          .map((final line) => line.trim())
          .where((final line) => line.isNotEmpty)
          .toList();

      expect(lines.length, equals(4));

      final events = lines
          .map((final line) => jsonDecode(line) as Map<String, dynamic>)
          .toList();

      expect(events.first['event'], equals('watch_started'));
      expect(events[1]['event'], equals('command_result'));
      expect(events[2]['event'], equals('command_result'));
      expect(events.last['event'], equals('watch_stopped'));

      final seq = events.map((final e) => e['seq'] as int).toList();
      expect(seq, equals([1, 2, 3, 4]));
    });

    test(
      'explain_errors surfaces vm_not_connected when app is absent',
      () async {
        final result = await _runCli(statePath, [
          'explain_errors',
          '--no-include-summary',
        ]);
        expect(result.exitCode, equals(1));

        final envelope =
            jsonDecode((result.stdout as String).trim())
                as Map<String, dynamic>;
        expect(envelope['ok'], isFalse);
        final error = envelope['error'] as Map<String, dynamic>;
        expect(error['code'], equals('vm_not_connected'));
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
