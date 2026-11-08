import 'package:oka_android/oka_android.dart';
import 'package:oka_harness/oka_harness.dart';

/// JSON receipt from SDK [DevSessionStopReport] (truthful limits preserved).
Map<String, Object?> devSessionStopReportJson(DevSessionStopReport report) {
  return {
    'ok': report.ok,
    'disposition': report.disposition.name,
    'runnerSessionCleared': report.runnerSessionCleared,
    'controlQuitAcknowledged': report.controlQuitAcknowledged,
    'processExitCode': report.processExitCode,
    'elapsedMs': report.elapsed.inMilliseconds,
    'limits': report.limits,
    'controlResponse': report.controlResponse,
    'message': report.message,
    'provenOwnedResourceSettlement': false,
    'consumerPhysicalObservations':
        'See android_owned_physical_observations.json (read-only; not attested by SDK).',
  };
}

/// Fail-closed: runner-session must exist and name the owning `oka dev` child.
void assertOkaDevOwnershipAtLaunch({
  required OkaLaunchedApp app,
  required String projectDir,
}) {
  final ownership = snapshotRunnerSessionOwnership(projectDir);
  if (ownership['present'] != true) {
    throw StateError(
      'Cannot prove oka ownership: runner-session missing after launch: '
      '$ownership',
    );
  }
  final discoveryPid = ownership['discoveryPid'];
  final expected = app.pid;
  if (discoveryPid is! int || discoveryPid != expected) {
    throw StateError(
      'Cannot prove oka ownership: discovery pid $discoveryPid != '
      'host child $expected: $ownership',
    );
  }
  if (ownership['parseError'] != null) {
    throw StateError(
      'Cannot prove oka ownership: unreadable runner-session: $ownership',
    );
  }
}

/// Snapshot runner-session ownership / preclear evidence (read-only).
Map<String, Object?> snapshotRunnerSessionOwnership(String projectDir) {
  try {
    final session = readRunnerSessionFile(projectDir);
    if (session == null) {
      return {
        'present': false,
        'path': projectDir,
      };
    }
    final vmUri = Uri.tryParse(session.vmServiceUri);
    return {
      'present': true,
      'discoveryPid': session.pid,
      'deviceId': session.deviceId,
      'controlPort': session.controlPort,
      'vmServiceUriHost': vmUri?.host,
      'vmServiceUriPort': vmUri?.port,
      'startedAt': session.startedAt.toUtc().toIso8601String(),
    };
  } on FormatException catch (e) {
    return {
      'present': true,
      'parseError': e.toString(),
    };
  }
}
