@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:test/test.dart';

import 'native_layer_evidence.dart';

void main() {
  test(
    'owned logcat stops on synthetic failure before oka dev launch',
    () async {
      final which = await Process.run('bash', ['-lc', 'command -v adb']);
      if (which.exitCode != 0) {
        markTestSkipped('adb not installed');
      }
      final sink = LogTap();
      AndroidEngineLogcatSession? logcat;
      try {
        logcat = await AndroidEngineLogcatSession.start(
          deviceId: 'emulator-5554',
          sink: sink,
        );
        if (logcat == null) {
          markTestSkipped('adb logcat start unavailable in this VM');
        }
        throw StateError('synthetic preflight failure before target.launch');
      } on StateError catch (e) {
        expect('$e', contains('preflight failure'));
      } finally {
        await logcat?.stop();
      }
    },
  );
}
