import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_toolkit_server/src/cli/cli_port_options.dart';
import 'package:test/test.dart';

Future<ProcessResult> _runCli(String statePath, List<String> args) => Process.run(
    'dart',
    [
      'run',
      'bin/flutter_mcp_toolkit.dart',
      '--state-file',
      statePath,
      ...args,
    ],
    workingDirectory: Directory.current.path,
  );

void main() {
  late Directory tempDir;
  late String statePath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('cli-port-test-');
    statePath = '${tempDir.path}/state.json';
    File(statePath).writeAsStringSync('{}');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('cliPositivePort', () {
    test('empty uses fallback', () {
      expect(cliPositivePort(null, fallback: 8181, flag: 'dart-vm-port'), 8181);
      expect(cliPositivePort('', fallback: 8181, flag: 'dart-vm-port'), 8181);
    });

    test('parses 65535', () {
      expect(cliPositivePort('65535', fallback: 1, flag: 'dart-vm-port'), 65535);
    });

    test('rejects 0, 65536, junk ports', () {
      const flag = 'dart-vm-port';
      for (final bad in [
        '0',
        '-1',
        '65536',
        '+8181',
        ' 8181',
        '0x1F',
        '08181',
      ]) {
        expect(
          () => cliPositivePort(bad, fallback: 1, flag: flag),
          throwsA(
            isA<CliPortUsageException>().having(
              (e) => e.message,
              'message',
              contains('--$flag="$bad"'),
            ),
          ),
          reason: 'reject $bad',
        );
      }
    });
  });

  group('flutter-mcp-toolkit CLI exit 64', () {
    test('invalid dart-vm-port returns JSON envelope', () async {
      final result = await _runCli(statePath, [
        'exec',
        '--name=noop',
        '--dart-vm-port=65536',
      ]);
      expect(result.exitCode, 64);
      final decoded = jsonDecode(result.stdout as String) as Map<String, Object?>;
      expect(decoded['ok'], false);
      final err = decoded['error'] as Map<String, Object?>?;
      expect(err?['message'], contains('--dart-vm-port="65536"'));
    });

    test('rejects leading-zero and signed ports with exit 64', () async {
      for (final port in ['0', '+8181', '08181']) {
        final result = await _runCli(statePath, [
          'exec',
          '--name=noop',
          '--dart-vm-port=$port',
        ]);
        expect(result.exitCode, 64, reason: port);
        final decoded = jsonDecode(result.stdout as String) as Map<String, Object?>;
        expect(decoded['ok'], false);
        final err = decoded['error'] as Map<String, Object?>?;
        expect(err?['message'], contains('--dart-vm-port="$port"'));
      }
    });

    test('rejects invalid web-browser-debugging-port and web-port', () async {
      for (final entry in [
        (['--web-browser-debugging-port=08181'], 'web-browser-debugging-port'),
        (['--web-port=65536'], 'web-port'),
      ]) {
        final result = await Process.run(
          'dart',
          [
            'run',
            'bin/flutter_mcp_toolkit.dart',
            '--state-file',
            statePath,
            ...entry.$1,
            'exec',
            '--name=status',
            '--args',
            '{}',
          ],
          workingDirectory: Directory.current.path,
        );
        expect(result.exitCode, 64, reason: entry.$2);
        final decoded = jsonDecode(result.stdout as String) as Map<String, Object?>;
        expect(decoded['ok'], false);
        final err = decoded['error'] as Map<String, Object?>?;
        expect(err?['message'], contains('--${entry.$2}='));
      }
    });

    test('webmcp verify rejects invalid --web-port', () async {
      final result = await Process.run(
        'dart',
        [
          'run',
          'bin/flutter_mcp_toolkit.dart',
          'webmcp',
          'verify',
          '--web-port=08181',
        ],
        workingDirectory: Directory.current.path,
      );
      expect(result.exitCode, 64);
      final decoded = jsonDecode(result.stdout as String) as Map<String, Object?>;
      expect(decoded['ok'], false);
    });
  });
}
