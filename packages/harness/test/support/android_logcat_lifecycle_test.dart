@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:test/test.dart';

import 'native_layer_evidence.dart';

const _fakeAdbScript = r'''
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == "-s" && "$3" == "logcat" && "$4" == "-c" ]]; then
  exit 0
fi
if [[ "$1" == "-s" && "$3" == "logcat" ]]; then
  trap 'exit 0' TERM
  while true; do sleep 0.02; done
fi
echo "fake_adb: unhandled argv: $*" >&2
exit 1
''';

Future<String> _materializeFakeAdb(Directory workspace) async {
  final dest = File('${workspace.path}/fake_adb');
  await dest.writeAsString(_fakeAdbScript);
  await Process.run('chmod', ['+x', dest.path]);
  return dest.path;
}

void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('fake_adb_logcat_');
  });

  tearDown(() async {
    await workspace.delete(recursive: true);
  });

  test('owned logcat stops on synthetic failure before target launch', () async {
    final adbBin = await _materializeFakeAdb(workspace);
    final sink = LogTap();
    AndroidEngineLogcatSession? logcat;
    try {
      logcat = await AndroidEngineLogcatSession.start(
        deviceId: 'emulator-5554',
        sink: sink,
        adbBin: adbBin,
      );
      throw StateError('synthetic preflight failure before target.launch');
    } on StateError catch (error) {
      expect('$error', contains('preflight failure'));
    } finally {
      final verdict = await logcat!.stop();
      expect(verdict.settled, isTrue);
      expect(verdict.forcedKill, isFalse);
    }
  });

  test('logcat stop records settled verdict after cooperative child', () async {
    final adbBin = await _materializeFakeAdb(workspace);
    final sink = LogTap();
    final logcat = await AndroidEngineLogcatSession.start(
      deviceId: 'emulator-5554',
      sink: sink,
      adbBin: adbBin,
    );
    expect(logcat.pid, greaterThan(0));
    final verdict = await logcat.stop();
    expect(verdict.settled, isTrue);
    expect(logcat.lastStopVerdict, isNotNull);
  });
}
