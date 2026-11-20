// Bring-up spawns real processes (fake `oka` scripts) and polls the
// runner-session contract; a loaded CI runner stretches every wait, so
// per-test budgets stay generous rather than the 30 s default.
@Timeout(Duration(minutes: 3))
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart' show LaunchedApp;
import 'package:oka_harness/oka_harness.dart';
import 'package:test/test.dart';

/// A fake `oka` CLI: the `build` phase exits fast (records nothing — a real
/// build writes run_session.json next to the APK); the `dev` phase
/// publishes a valid runner-session file (mcp_flutter ADR-0014 spec v2
/// shape), prints its args, and stays alive like the real owning session.
const String _fakeOkaScript = r'''
#!/bin/sh
echo "fake-oka args: $*"
if [ "$1" = "build" ]; then
  echo "fake build complete"
  exit 0
fi
echo "fake-oka dev session args"
mkdir -p .flutter_mcp
cat > .flutter_mcp/runner-session.json <<'JSON'
{
  "schema": 1,
  "runner": "fake-oka-dev",
  "vm_service_uri": "http://127.0.0.1:45671/abc123=/",
  "control_port": 45672,
  "device_id": "emulator-5554",
  "pid": 42424,
  "started_at": "2026-09-27T00:00:00.000Z"
}
JSON
echo "fake session published"
sleep 300
''';

/// A fake `oka` whose build succeeds but whose dev session never publishes
/// (for the timeout path).
const String _stallingOkaScript = r'''
#!/bin/sh
if [ "$1" = "dev" ]; then
  echo "fake-oka stalling"
  sleep 300
fi
echo "fake-oka build ok"
''';

Future<Directory> _withFakeOka(String script) async {
  final dir = await Directory.systemTemp.createTemp('oka_harness_test');
  final scriptFile = File('${dir.path}/fake_oka')..writeAsStringSync(script);
  await Process.run('chmod', ['+x', scriptFile.path]);
  return dir;
}

/// Polls the session tap for [needle] — stdout lines arrive as stream
/// events, so a just-launched session's echo may lag the returned
/// [LaunchedApp] by a few hundred milliseconds.
Future<bool> tapContains(LaunchedApp app, String needle) async {
  for (var i = 0; i < 30; i++) {
    if (app.stdout.firstMatch(needle) != null) return true;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  if (app.stdout.firstMatch(needle) == null) {
    // ignore: avoid_print
    print('--- tap at failure ---');
    for (final line in app.stdout.tail(20)) {
      // ignore: avoid_print
      print('| $line');
    }
  }
  return app.stdout.firstMatch(needle) != null;
}

/// Polls [condition] every 100 ms until it holds; fails with [reason] on
/// expiry so a hung wait names the observable instead of timing out darkly.
Future<void> waitFor(
  bool Function() condition, {
  String reason = 'condition never held',
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail(reason);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await _withFakeOka(_fakeOkaScript);
  });

  tearDown(() async {
    await workspace.delete(recursive: true);
  });

  test(
    'launch owns the build phase, then reads the runner-session contract',
    () async {
      final target = AndroidAppTarget(
        projectDir: workspace.path,
        okaBin: '${workspace.path}/fake_oka',
        deviceId: 'emulator-9999',
        dartDefines: const {'INSPECTOR_EVIDENCE': 'fixture'},
        logcat: false,
      );
      final app = await target.launch();

      addTearDown(app.stop);
      expect(app.vmUri.host, '127.0.0.1');
      expect(app.vmUri.port, 45671);
      // The build phase ran with the defines threaded through.
      expect(await tapContains(app, 'build apk --debug'), isTrue);
      expect(
        await tapContains(app, '--dart-define INSPECTOR_EVIDENCE=fixture'),
        isTrue,
      );
      // Args threaded to the owning session.
      expect(await tapContains(app, '--device emulator-9999'), isTrue);
      expect(await tapContains(app, 'fake-oka dev session args'), isTrue);
      // The build ran with the SAME defines the dev session requests
      // (the parity check the real oka enforces).
    },
  );

  test('stop terminates the owning session', () async {
    final target = AndroidAppTarget(
      projectDir: workspace.path,
      okaBin: '${workspace.path}/fake_oka',
      logcat: false,
    );
    final app = await target.launch();
    final pid = app.process.pid;
    final code = await app.stop();
    expect(code, isNonZero, reason: 'SIGTERM should end the fake session');
    // The named observable, checked directly rather than trusted to the
    // exit-code plumbing: the owning session's pid leaves the process
    // table. Generous deadline — CI load can stretch reaping.
    await waitFor(
      () => Process.runSync('ps', [
        '-p',
        '$pid',
        '-o',
        'pid=',
      ]).stdout.toString().trim().isEmpty,
      reason: 'owning session pid $pid survived stop()',
    );
  });

  test(
    'launch(build: false) skips the build phase and attaches directly',
    () async {
      final target = AndroidAppTarget(
        projectDir: workspace.path,
        okaBin: '${workspace.path}/fake_oka',
        logcat: false,
      );
      final app = await target.launch(build: false);
      addTearDown(app.stop);
      expect(
        app.stdout.firstMatch('build apk'),
        isNull,
        reason: 'build:false must not run the build phase',
      );
      expect(app.stdout.firstMatch('fake-oka dev session args'), isNotNull);
    },
  );

  test('a session that never publishes times out and is torn down', () async {
    final stalling = await _withFakeOka(_stallingOkaScript);
    addTearDown(() => stalling.delete(recursive: true));
    final target = AndroidAppTarget(
      projectDir: stalling.path,
      okaBin: '${stalling.path}/fake_oka',
      logcat: false,
      sessionTimeout: const Duration(seconds: 2),
    );
    await expectLater(target.launch(), throwsA(isA<TimeoutException>()));
    // The failed bring-up must not leave an `oka` process behind.
    final leftover = await Process.run('pgrep', ['-f', 'fake_oka']);
    expect(
      leftover.stdout.toString().trim(),
      isEmpty,
      reason: 'no fake oka process should survive a failed launch',
    );
  });
}
