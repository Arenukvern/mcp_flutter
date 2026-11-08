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
  });

  final int exitCode;
  final int? processPid;
  final bool processSettled;
  final bool runnerSessionAbsent;

  bool get cooperativeTeardown =>
      processSettled && runnerSessionAbsent && exitCode != -1;

  Map<String, Object?> toJson() => {
        'exitCode': exitCode,
        'processPid': processPid,
        'processSettled': processSettled,
        'runnerSessionAbsent': runnerSessionAbsent,
        'cooperativeTeardown': cooperativeTeardown,
      };
}

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
}) async {
  final settled = processPid == null ? true : !await _pidAlive(processPid);
  final runnerSessionAbsent = readRunnerSessionFile(projectDir) == null;
  return AndroidOkaSessionSettlement(
    exitCode: exitCode,
    processPid: processPid,
    processSettled: settled,
    runnerSessionAbsent: runnerSessionAbsent,
  );
}
