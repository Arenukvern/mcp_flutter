// CI/local probe: `oka build apk --debug` + `checkDevSession` with full trace.
//
// Run from `showcase/native_layer_capture_fixture`:
// dart run ../../packages/harness/tool/oka_android_build_probe.dart
library;

import 'dart:convert';
import 'dart:io';

import '../test/support/native_layer_oka_diagnostics.dart';

Future<void> main(List<String> args) async {
  final projectDir = Directory.current.path;
  final okaBin = Platform.environment['OKA_BIN'] ?? 'oka';
  final trace = await runOkaAndroidManifestBuildTraced(
    projectDir: projectDir,
    okaBin: okaBin,
  );
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(trace));
  final ok = trace['exitCode'] == 0 && trace['checkDevSessionOk'] == true;
  if (!ok) {
    stderr.writeln(
      'oka android build probe failed: hosted RecordRunSessionStep / '
      'checkDevSession did not accept the artifact tree.',
    );
    exitCode = 1;
  }
}
