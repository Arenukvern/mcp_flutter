import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:oka_android/oka_android.dart';
import 'package:path/path.dart' as p;

/// Consumer teardown receipt for an [AndroidAppTarget] / oka-owned [LaunchedApp].
///
/// Records only what the harness can observe: direct `oka dev` child exit and
/// whether the SDK-published runner-session file cleared on its own.
/// Does **not** prove adb forward, VM attach, or on-device descendants settled
/// (SDK lifecycle owns that; no consumer debris cleanup).
final class AndroidOkaSessionSettlement {
  const AndroidOkaSessionSettlement({
    required this.exitCode,
    required this.processPid,
    required this.processSettled,
    required this.runnerSessionAbsent,
    required this.stopKind,
    required this.runnerSessionAfterStop,
    this.runnerSessionWaitMs = 0,
  });

  final int exitCode;
  final int? processPid;

  /// Direct `oka dev` child no longer responds to `kill -0`.
  final bool processSettled;

  /// SDK removed `.flutter_mcp/runner-session.json` without harness mutation.
  final bool runnerSessionAbsent;

  /// `cooperative_oka_exit` vs `forced_harness_sigterm` (and related).
  final String stopKind;

  final int runnerSessionWaitMs;

  /// File + parsed discovery snapshot after stop (may still be present on gap).
  final Map<String, Object?> runnerSessionAfterStop;

  bool get cooperativeTeardown =>
      stopKind == 'cooperative_oka_exit' &&
      processSettled &&
      runnerSessionAbsent;

  /// Harness does not assert adb forward / app descendant cleanup.
  bool get ownedResourceSettlement => false;

  Map<String, Object?> toJson() => {
        'exitCode': exitCode,
        'processPid': processPid,
        'processSettled': processSettled,
        'runnerSessionAbsent': runnerSessionAbsent,
        'sdkRunnerSessionCleared': runnerSessionAbsent,
        'stopKind': stopKind,
        'runnerSessionWaitMs': runnerSessionWaitMs,
        'runnerSessionAfterStop': runnerSessionAfterStop,
        'cooperativeTeardown': cooperativeTeardown,
        'ownedResourceSettlement': ownedResourceSettlement,
        'provenOwnedResourceSettlement': false,
        'ownedResourceSettlementNote':
            'Consumer observes oka dev child + runner-session file only; '
            'exitCode==0 and runner-session absence alone are insufficient. '
            'adb forward, VM attach, and on-device app descendants require '
            'SDK cooperative shutdown (see android_owned_physical_observations.json).',
      };
}

const _runnerSessionPollTimeout = Duration(seconds: 5);

/// Snapshot runner-session ownership / preclear evidence (read-only).
Map<String, Object?> snapshotRunnerSessionOwnership(String projectDir) {
  final file = File(p.join(projectDir, '.flutter_mcp', 'runner-session.json'));
  try {
    final session = readRunnerSessionFile(projectDir);
    if (session == null) {
      return {
        'present': false,
        'path': file.path,
        'bytes': file.existsSync() ? file.lengthSync() : null,
      };
    }
    final vmUri = Uri.tryParse(session.vmServiceUri);
    return {
      'present': true,
      'path': file.path,
      'bytes': file.lengthSync(),
      'discoveryPid': session.pid,
      'deviceId': session.deviceId,
      'controlPort': session.controlPort,
      'vmServiceUriHost': vmUri?.host,
      'vmServiceUriPort': vmUri?.port,
      'startedAt': session.startedAt.toUtc().toIso8601String(),
    };
  } on FormatException catch (e) {
    return {
      'present': file.existsSync(),
      'path': file.path,
      'bytes': file.existsSync() ? file.lengthSync() : null,
      'parseError': e.toString(),
    };
  }
}

String _classifyStopKind(int exitCode) {
  if (exitCode == 0) return 'cooperative_oka_exit';
  // Dart / POSIX: SIGTERM often surfaces as 15, -15, or 143 (128+15).
  if (exitCode == 15 || exitCode == -15 || exitCode == 143) {
    return 'forced_harness_sigterm';
  }
  if (exitCode == -9 || exitCode == 9 || exitCode == 137) {
    return 'forced_harness_sigkill';
  }
  return 'oka_exit_nonzero';
}

Future<bool> _pidAlive(int pid) async {
  if (pid <= 0) return false;
  final probe = await Process.run('kill', ['-0', '$pid']);
  return probe.exitCode == 0;
}

Future<bool> _waitSdkRunnerSessionAbsent(
  String projectDir,
  Duration timeout,
) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (readRunnerSessionFile(projectDir) == null) {
      return true;
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return readRunnerSessionFile(projectDir) == null;
}

/// Records teardown after [LaunchedApp.stop] — observation only (no file delete).
Future<AndroidOkaSessionSettlement> recordAndroidOkaStopSettlement({
  required int exitCode,
  required int? processPid,
  required String projectDir,
  Duration runnerSessionPollTimeout = _runnerSessionPollTimeout,
}) async {
  final settled = processPid == null ? true : !await _pidAlive(processPid);
  final waitStarted = DateTime.now();
  final runnerSessionAbsent = await _waitSdkRunnerSessionAbsent(
    projectDir,
    runnerSessionPollTimeout,
  );
  final waitMs = DateTime.now().difference(waitStarted).inMilliseconds;
  return AndroidOkaSessionSettlement(
    exitCode: exitCode,
    processPid: processPid,
    processSettled: settled,
    runnerSessionAbsent: runnerSessionAbsent,
    stopKind: _classifyStopKind(exitCode),
    runnerSessionWaitMs: waitMs,
    runnerSessionAfterStop: snapshotRunnerSessionOwnership(projectDir),
  );
}
