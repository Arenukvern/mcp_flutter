@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:test/test.dart';

import 'linux_bounded_flutter_run.dart';

void main() {
  test(
    'wsUri timeout stops bounded owner (no multi-hour survivor)',
    () async {
      final dir = Directory.systemTemp.createTempSync('linux_bounded_fail_');
      final fakeFlutter = File('${dir.path}/fake_flutter.sh')
        ..writeAsStringSync(
          '#!/bin/sh\n'
          'while true; do sleep 1; done\n',
        );
      await Process.run('chmod', ['+x', fakeFlutter.path]);
      final target = LinuxBoundedFlutterRunTarget(
        projectDir: dir.path,
        flutterBin: fakeFlutter.path,
        vmServiceTimeout: const Duration(milliseconds: 400),
        runDeadline: const Duration(seconds: 30),
        stopGrace: const Duration(milliseconds: 200),
      );
      await expectLater(target.launch(), throwsA(isA<TimeoutException>()));
    },
    skip: !Platform.isLinux ? 'Linux-only owner' : null,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
