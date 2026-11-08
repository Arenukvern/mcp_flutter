import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:oka_android/oka_android.dart';

/// Teardown receipt for an [AndroidAppTarget] / oka-owned [LaunchedApp].
final class AndroidOkaSessionSettlement {
  const AndroidOkaSessionSettlement({
    required this.exitCode,
    required this.processPid,
    required this.processSettled,
    required this.runnerSessionAbsent,
    this.runnerSessionWaitMs = 0,
    this.runnerSessionDebrisCleared = false,
  });

  final int exitCode;
  final int? processPid;
  final bool processSettled;
  final bool runnerSessionAbsent;

  /// Wall time spent polling for oka `finally` session cleanup after stop.
  final int runnerSessionWaitMs;

  /// Harness removed a stale file after SIGTERM stop (oka ADR: debris on kill).
  final bool runnerSessionDebrisCleared;

  bool get cooperativeTeardown =>
      processSettled && runnerSessionAbsent && exitCode == 0;

  Map<String, Object?> toJson() => {
        'exitCode': exitCode,
        'processPid': processPid,
        'processSettled': processSettled,
        'runnerSessionAbsent': runnerSessionAbsent,
        'runnerSessionWaitMs': runnerSessionWaitMs,
        'runnerSessionDebrisCleared': runnerSessionDebrisCleared,
        'cooperativeTeardown': cooperativeTeardown,
      };
}

/// oka `dev` clears runner-session.json in a `finally` after exit; harness
/// `LaunchedApp.stop` may observe [Process.exitCode] before that unlink lands.
const _runnerSessionPollTimeout = Duration(seconds: 5);

Future<bool> _pidAlive(int pid) async {
  if (pid <= 0) return false;
  final probe = await Process.run('kill', ['-0', '$pid']);
  return probe.exitCode == 0;
}

/// Records teardown after [LaunchedApp.stop] for oka-owned Android sessions.
Future<AndroidOkaSessionSettlement> recordAndroidOkaStopSettlement({
  required int exitCode,
  required int? processPid,
  required String projectDir,
  Duration runnerSessionPollTimeout = _runnerSessionPollTimeout,
}) async {
  final settled = processPid == null ? true : !await _pidAlive(processPid);
  final waitStarted = DateTime.now();
  final runnerSessionAbsent = await _waitRunnerSessionAbsentWithTimeout(
    projectDir,
    runnerSessionPollTimeout,
  );
  final waitMs = DateTime.now().difference(waitStarted).inMilliseconds;
  var absent = runnerSessionAbsent;
  var debrisCleared = false;
  if (!absent && settled) {
    await clearRunnerSessionFile(projectDir);
    debrisCleared = true;
    absent = readRunnerSessionFile(projectDir) == null;
  }
  return AndroidOkaSessionSettlement(
    exitCode: exitCode,
    processPid: processPid,
    processSettled: settled,
    runnerSessionAbsent: absent,
    runnerSessionWaitMs: waitMs,
    runnerSessionDebrisCleared: debrisCleared,
  );
}

Future<bool> _waitRunnerSessionAbsentWithTimeout(
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
