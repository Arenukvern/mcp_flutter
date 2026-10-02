import 'dart:async';
import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:test/test.dart';

/// A fake `flutter` CLI: announces a VM service like the real tool does,
/// then stays alive (owning session) until signalled.
const String _fakeFlutterScript = r'''
#!/bin/sh
echo "args: $*"
echo "Launching lib/main.dart on macOS in debug mode..."
echo "A Dart VM Service on macOS is available at: http://127.0.0.1:45671/abc123_=/"
echo "Flutter run key commands."
echo "r Hot reload."
while true; do sleep 1; done
''';

/// A fake `flutter` CLI whose bring-up never completes: it stays alive
/// (owning session, pid written to `$PID_FILE`) but never announces a VM
/// service.
const String _silentFlutterScript = r'''
#!/bin/sh
echo $$ > "$PID_FILE"
echo "Launching lib/main.dart on macOS in debug mode..."
while true; do sleep 1; done
''';

/// True when [pid] still names a live process (`kill -0` succeeds).
bool _processIsAlive(final int pid) =>
    Process.runSync('kill', <String>['-0', '$pid']).exitCode == 0;

void main() {
  late Directory workspace;
  late String fakeFlutter;
  late String silentFlutter;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('flutter_run_test');
    fakeFlutter = '${workspace.path}/fake_flutter';
    File(fakeFlutter).writeAsStringSync(_fakeFlutterScript);
    await Process.run('chmod', ['+x', fakeFlutter]);
    silentFlutter = '${workspace.path}/fake_flutter_silent';
    File(silentFlutter).writeAsStringSync(_silentFlutterScript);
    await Process.run('chmod', ['+x', silentFlutter]);
  });

  tearDown(() async {
    await workspace.delete(recursive: true);
  });

  test('launch attaches to the owning session and scrapes the VM URI',
      () async {
    final target = FlutterRunTarget(
      projectDir: workspace.path,
      flutterBin: fakeFlutter,
      device: 'macos',
    );
    final app = await target.launch();

    addTearDown(app.stop);
    expect(app.vmUri.host, '127.0.0.1');
    expect(app.vmUri.port, 45671);
    expect(app.stdout.firstMatch('Flutter run key commands.'), isNotNull);
  });

  test('extraArgs are threaded to flutter run', () async {
    final target = FlutterRunTarget(
      projectDir: workspace.path,
      flutterBin: fakeFlutter,
      extraArgs: ['--web-port=8080'],
    );
    final app = await target.launch();

    addTearDown(app.stop);
    expect(app.stdout.firstMatch('--web-port=8080'), isNotNull,
        reason: 'the fake flutter echoes its args');
  });

  test('stop terminates the owning session', () async {
    final target = FlutterRunTarget(
      projectDir: workspace.path,
      flutterBin: fakeFlutter,
    );
    final app = await target.launch();
    final code = await app.stop();
    expect(code, isNonZero);
  });

  test('a failed bring-up reaps the owning session before rethrowing',
      () async {
    final pidFile = File('${workspace.path}/pid');
    final target = FlutterRunTarget(
      projectDir: workspace.path,
      flutterBin: silentFlutter,
      environment: {'PID_FILE': pidFile.path},
      vmServiceTimeout: const Duration(milliseconds: 300),
    );
    await expectLater(target.launch(), throwsA(isA<TimeoutException>()));
    // The fake flutter writes the pid right before the (short) VM wait;
    // under heavy load the reap can win that race by a hair. Retry the
    // read briefly — the assertion is about the reap, not file timing.
    var pid = -1;
    for (var attempt = 0; attempt < 20; attempt++) {
      try {
        pid = int.parse(pidFile.readAsStringSync().trim());
        break;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
    // Death confirmation lags the kill under heavy machine load — poll
    // briefly. A reap that never happened still fails (bounded wait).
    var alive = _processIsAlive(pid);
    for (var attempt = 0; attempt < 60 && alive; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      alive = _processIsAlive(pid);
    }
    expect(alive, isFalse,
        reason: 'launch must await the confirmed death before rethrowing');
  });

  test('stop returns only after the child process is confirmed dead',
      () async {
    final process = await Process.start('sleep', <String>['30']);
    final app = LaunchedApp(
      name: 'sleepy',
      process: process,
      stdout: LogTap(),
      vmUri: Uri.parse('http://127.0.0.1:1/unused'),
    );
    final code = await app.stop();
    expect(code, isNonZero);
    expect(_processIsAlive(process.pid), isFalse,
        reason: 'stop must await the confirmed death before returning');
  });
}
