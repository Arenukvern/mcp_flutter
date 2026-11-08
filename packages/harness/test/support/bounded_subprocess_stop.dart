import 'dart:async';
import 'dart:io';

import 'package:universal_tooling_runtime/universal_tooling_runtime.dart';

/// Structured teardown for a harness-owned child [Process] (e.g. adb logcat).
final class SubprocessStopVerdict {
  const SubprocessStopVerdict({
    required this.pid,
    required this.exitCode,
    required this.drainsCompleted,
    required this.physicallySettled,
    required this.forcedKill,
    this.drainError,
    this.exitError,
  });

  final int pid;
  final int? exitCode;
  final bool drainsCompleted;
  final bool physicallySettled;
  final bool forcedKill;
  final String? drainError;
  final String? exitError;

  bool get settled => physicallySettled && drainsCompleted;

  Map<String, Object?> toJson() => {
        'pid': pid,
        'exitCode': exitCode,
        'drainsCompleted': drainsCompleted,
        'physicallySettled': physicallySettled,
        'forcedKill': forcedKill,
        'settled': settled,
        if (drainError != null) 'drainError': drainError,
        if (exitError != null) 'exitError': exitError,
      };
}

/// SIGTERM → exit wait → optional SIGKILL; await stream drains; verify pid gone.
Future<SubprocessStopVerdict> stopOwnedSubprocess(
  Process process, {
  Future<void>? stdoutDrain,
  Future<void>? stderrDrain,
  Duration grace = const Duration(seconds: 3),
  Duration settlementBudget = const Duration(seconds: 5),
}) async {
  final pid = process.pid;
  var forcedKill = false;
  String? exitError;
  int? exitCode;

  if (!process.kill(ProcessSignal.sigterm)) {
    exitError = 'sigterm not delivered';
  }
  try {
    exitCode = await process.exitCode.timeout(grace);
  } on TimeoutException {
    forcedKill = true;
    process.kill(ProcessSignal.sigkill);
    try {
      exitCode = await process.exitCode.timeout(grace);
    } on Object catch (error) {
      exitError = 'exit after sigkill: $error';
    }
  } on Object catch (error) {
    exitError = 'exit wait: $error';
  }

  var drainsCompleted = true;
  String? drainError;
  final drains = <Future<void>>[
    if (stdoutDrain != null) stdoutDrain,
    if (stderrDrain != null) stderrDrain,
  ];
  if (drains.isNotEmpty) {
    try {
      await Future.wait(drains).timeout(grace);
    } on Object catch (error) {
      drainsCompleted = false;
      drainError = '$error';
    }
  }

  final physicallySettled = await awaitProcessSettlement(
    [pid],
    budget: settlementBudget,
  );

  return SubprocessStopVerdict(
    pid: pid,
    exitCode: exitCode,
    drainsCompleted: drainsCompleted,
    physicallySettled: physicallySettled,
    forcedKill: forcedKill,
    drainError: drainError,
    exitError: exitError,
  );
}
