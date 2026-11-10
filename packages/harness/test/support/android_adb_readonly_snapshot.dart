import 'dart:io';

import 'android_physical_forward_watch.dart';

const kNativeCaptureFixtureAndroidPackage =
    'dev.mcpflutter.native_layer_capture_fixture';

final class AdbForwardListSnapshot {
  const AdbForwardListSnapshot({
    required this.exitCode,
    required this.lines,
    required this.stderrTail,
    required this.parseFailures,
  });

  final int exitCode;
  final List<String> lines;
  final String stderrTail;
  final int parseFailures;

  bool get observationComplete => exitCode == 0;
}

Future<AdbForwardListSnapshot> fetchAdbForwardListOnce() async {
  final adb = Platform.environment['ADB'] ?? 'adb';
  final result = await Process.run(adb, ['forward', '--list']);
  final lines = '${result.stdout}'
      .trim()
      .split('\n')
      .where((l) => l.isNotEmpty)
      .toList();
  var parseFailures = 0;
  for (final line in lines) {
    if (parseForwardLine(line) == null) parseFailures++;
  }
  return AdbForwardListSnapshot(
    exitCode: result.exitCode,
    lines: lines,
    stderrTail: '${result.stderr}'.trim(),
    parseFailures: parseFailures,
  );
}

/// Distinguishes fixture absent vs adb unreachable (read-only).
///
/// Note: separate `get-state` and `pidof` shells admit device-state TOCTOU;
/// evidence treats adb failures as unknown, not "gone".
Future<Map<String, Object?>> observeFixtureAppOnDevice(String deviceId) async {
  if (deviceId.isEmpty) {
    return {
      'observationComplete': false,
      'fixtureAppState': 'unknown',
      'observationUnknownReasons': ['empty_device_id'],
      'pidList': <String>[],
    };
  }
  final adb = Platform.environment['ADB'] ?? 'adb';
  final state = await Process.run(adb, ['-s', deviceId, 'get-state']);
  if (state.exitCode != 0) {
    return {
      'observationComplete': false,
      'fixtureAppState': 'unknown',
      'observationUnknownReasons': [
        'adb_get_state_exit_${state.exitCode}',
      ],
      'adbGetStateStdout': '${state.stdout}'.trim(),
      'adbGetStateStderr': '${state.stderr}'.trim(),
      'pidList': <String>[],
    };
  }
  final pidof = await Process.run(
    adb,
    ['-s', deviceId, 'shell', 'pidof', kNativeCaptureFixtureAndroidPackage],
  );
  final stdout = '${pidof.stdout}'.trim();
  final pids = stdout.isEmpty
      ? <String>[]
      : stdout.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();

  if (pidof.exitCode == 0) {
    return {
      'observationComplete': true,
      'fixtureAppState': pids.isEmpty ? 'not_running' : 'running',
      'pidofExitCode': 0,
      'pidofStdout': stdout.isEmpty ? null : stdout,
      'pidList': pids,
    };
  }
  if (pidof.exitCode == 1 && stdout.isEmpty) {
    return {
      'observationComplete': true,
      'fixtureAppState': 'not_running',
      'pidofExitCode': 1,
      'pidList': <String>[],
      'note': 'pidof exit 1 with empty stdout treated as package not running',
    };
  }
  return {
    'observationComplete': false,
    'fixtureAppState': 'unknown',
    'observationUnknownReasons': ['pidof_exit_${pidof.exitCode}'],
    'pidofExitCode': pidof.exitCode,
    'pidofStdout': stdout.isEmpty ? null : stdout,
    'pidList': pids,
    'pidofStderr': '${pidof.stderr}'.trim(),
  };
}
