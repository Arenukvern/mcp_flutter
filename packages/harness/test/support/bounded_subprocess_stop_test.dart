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

/// Linux/macOS CI and local dev: uses `python3` + POSIX signals for SIG_IGN.
String? posixPython3SkipReason() {
  if (!Platform.isLinux && !Platform.isMacOS) {
    return 'SIG_IGN subprocess stop proof requires python3 on a POSIX host '
        '(Linux or macOS)';
  }
  return null;
}

void main() {
  group('stopOwnedSubprocess', () {
    late Directory workspace;
    String? python3Skip;

    setUpAll(() async {
      python3Skip = posixPython3SkipReason();
      if (python3Skip != null) return;
      final which = await Process.run('which', ['python3']);
      if (which.exitCode != 0) {
        python3Skip = 'python3 not on PATH (required for SIG_IGN child)';
      }
    });

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
        if (python3Skip != null) {
          markTestSkipped(python3Skip!);
          return;
        }
        final process = await Process.start(
          'python3',
          [
            '-c',
            'import signal,sys,time; signal.signal(signal.SIGTERM, signal.SIG_IGN)\n'
                "sys.stdout.write('ready\\n'); sys.stdout.flush()\n"
                'while True: time.sleep(0.05)',
          ],
        );
        final ready = Completer<void>();
        final stdoutDrained = Completer<void>();
        final lineBuffer = StringBuffer();
        process.stdout.listen(
          (data) {
            lineBuffer.write(utf8.decode(data));
            if (!ready.isCompleted && lineBuffer.toString().contains('ready\n')) {
              ready.complete();
            }
          },
          onDone: () {
            if (!stdoutDrained.isCompleted) stdoutDrained.complete();
          },
          onError: (Object error, StackTrace stack) {
            if (!stdoutDrained.isCompleted) {
              stdoutDrained.completeError(error, stack);
            }
          },
          cancelOnError: true,
        );
        await ready.future.timeout(const Duration(seconds: 5));
        final verdict = await stopOwnedSubprocess(
          process,
          stdoutDrain: stdoutDrained.future,
          grace: const Duration(seconds: 2),
          settlementBudget: const Duration(seconds: 15),
        );
        expect(verdict.forcedKill, isTrue);
        expect(verdict.settled, isTrue);
        expect(verdict.exitCode, isNotNull);
        expect(verdict.drainsCompleted, isTrue);
      },
      skip: posixPython3SkipReason(),
    );
  });
}
