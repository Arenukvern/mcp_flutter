import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_toolkit_server/src/cli/cli_port_options.dart';
import 'package:test/test.dart';

void main() {
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
    Future<ProcessResult> runBadPort(String port) => Process.run(
          'dart',
          [
            'run',
            'mcp_server_dart/bin/flutter_mcp_toolkit.dart',
            'exec',
            '--name=noop',
            '--dart-vm-port=$port',
          ],
          workingDirectory: '/agent/repos/mcp_flutter',
        );

    test('invalid dart-vm-port returns JSON envelope', () async {
      final result = await runBadPort('65536');
      expect(result.exitCode, 64);
      final decoded = jsonDecode(result.stdout as String) as Map<String, Object?>;
      expect(decoded['ok'], false);
      final err = decoded['error'] as Map<String, Object?>?;
      expect(err?['message'], contains('--dart-vm-port="65536"'));
    });

    test('rejects leading-zero and signed ports with exit 64', () async {
      for (final port in ['0', '+8181', '08181']) {
        final result = await runBadPort(port);
        expect(result.exitCode, 64, reason: port);
        final decoded = jsonDecode(result.stdout as String) as Map<String, Object?>;
        expect(decoded['ok'], false);
        final err = decoded['error'] as Map<String, Object?>?;
        expect(err?['message'], contains('--dart-vm-port="$port"'));
      }
    });
  });
}
