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

Map<String, Object?> spawnBindingReportJson(
  RunnerSessionSpawnBindingReport report,
) {
  return {
    'discoveryPid': report.discoveryPid,
    'spawnPid': report.spawnPid,
    'binding': report.binding.name,
    'isPlausibleOwnership': report.isPlausibleOwnership,
  };
}

/// SDK ownership: discovery pid is session owner; spawn pid is wrapper handle.
void assertOkaSpawnBindingAtLaunch({
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
  if (ownership['parseError'] != null) {
    throw StateError(
      'Cannot prove oka ownership: unreadable runner-session: $ownership',
    );
  }
  if (!app.spawnBinding.isPlausibleOwnership) {
    throw StateError(
      'Cannot prove oka ownership: spawn binding not plausible '
      '(binding=${app.spawnBinding.binding}): '
      '${spawnBindingReportJson(app.spawnBinding)}',
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
      'sessionOwnerPid': session.pid,
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
