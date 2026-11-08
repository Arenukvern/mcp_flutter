@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'bounded_subprocess_stop.dart';

const _cooperativeScript = r'''
#!/bin/sh
trap 'exit 0' TERM
while true; do sleep 0.02; done
''';

void main() {
  group('stopOwnedSubprocess', () {
    late Directory workspace;

    setUp(() async {
      workspace = await Directory.systemTemp.createTemp('bounded_subprocess_');
    });

    tearDown(() async {
      await workspace.delete(recursive: true);
    });

    Future<String> writeScript(String body) async {
      final path = '${workspace.path}/proc.sh';
      final file = File(path);
      await file.writeAsString(body);
      await Process.run('chmod', ['+x', path]);
      return path;
    }

    test('cooperative child settles after SIGTERM', () async {
      final script = await writeScript(_cooperativeScript);
      final process = await Process.start(script, const []);
      final stdoutDrain = process.stdout.drain<void>();
      final verdict = await stopOwnedSubprocess(
        process,
        stdoutDrain: stdoutDrain,
      );
      expect(verdict.settled, isTrue);
      expect(verdict.forcedKill, isFalse);
    });

    test('ignoring SIGTERM escalates to SIGKILL and settles', () async {
      final process = await Process.start(
        'python3',
        [
          '-c',
          'import signal,sys,time; signal.signal(signal.SIGTERM, signal.SIG_IGN)\n'
              "sys.stdout.write('ready\\n'); sys.stdout.flush()\n"
              'while True: time.sleep(0.05)',
        ],
      );
      await process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(seconds: 5));
      final verdict = await stopOwnedSubprocess(
        process,
        grace: const Duration(seconds: 2),
        settlementBudget: const Duration(seconds: 15),
      );
      expect(verdict.forcedKill, isTrue);
      expect(verdict.settled, isTrue);
      expect(verdict.exitCode, isNotNull);
    });
  });
}
