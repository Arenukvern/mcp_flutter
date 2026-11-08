import 'dart:convert';
import 'dart:io';

import 'package:oka_android/oka_android.dart';
import 'package:oka_harness/oka_harness.dart';

const _sessionTeardownFileName = 'session-teardown.json';

/// Mirrors SDK identity filter for `.flutter_mcp/session-teardown.json`.
Map<String, Object?>? readConsumerSessionTeardownSidecar(
  String projectPath, {
  required int? owningPid,
}) {
  final file = File('$projectPath/.flutter_mcp/$_sessionTeardownFileName');
  if (!file.existsSync()) return null;
  try {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map) return null;
    final raw = Map<String, Object?>.from(decoded);
    final id = raw['identity'];
    if (owningPid != null && id is Map) {
      final runnerPid = id['runnerPid'];
      if (runnerPid is int && runnerPid != owningPid) {
        return null;
      }
    }
    return raw;
  } on Object {
    return null;
  }
}

/// JSON receipt from SDK [DevSessionStopReport] (truthful limits preserved).
Map<String, Object?> devSessionStopReportJson(
  DevSessionStopReport report, {
  Map<String, Object?>? sessionCleanupSidecar,
}) {
  final cleanupActionsSucceeded = sessionCleanupSidecar?['actionsSucceeded'];
  return {
    'ok': report.ok,
    'disposition': report.disposition.name,
    'runnerSessionCleared': report.runnerSessionCleared,
    'controlQuitAcknowledged': report.controlQuitAcknowledged,
    'controlQuitSent': report.controlQuitSent,
    'controlQuitConnectFailed': report.controlQuitConnectFailed,
    'controlReplyLost': report.controlReplyLost,
    'stdinQuitWritten': report.stdinQuitWritten,
    'processExitCode': report.processExitCode,
    'elapsedMs': report.elapsed.inMilliseconds,
    'limits': report.limits,
    'controlResponse': report.controlResponse,
    'message': report.message,
    'sessionCleanup': ?sessionCleanupSidecar,
    if (cleanupActionsSucceeded is bool)
      'sessionCleanupActionsSucceeded': cleanupActionsSucceeded,
    'provenOwnedResourceSettlement': false,
    'consumerPhysicalObservations':
        'See android_owned_physical_observations.json (read-only; not attested by SDK).',
  };
}

/// Identity-filtered session-teardown sidecar for consumer artifacts (fail-closed).
Map<String, Object?> sessionCleanupConsumerEvidence({
  required int? sessionOwnerPid,
  Map<String, Object?>? sessionCleanupSidecar,
  List<Map<String, Object?>>? trackedIdentitiesFrozen,
}) {
  final cleanup = sessionCleanupSidecar;
  final unknown = <String>[];
  var identityMatch = false;
  int? runnerPid;
  final actionsSucceeded = cleanup?['actionsSucceeded'] == true;
  if (cleanup == null) {
    unknown.add('session_cleanup_sidecar_missing');
  } else {
    final identity = cleanup['identity'];
    if (identity is Map) {
      final raw = identity['runnerPid'];
      if (raw is int) {
        runnerPid = raw;
        if (sessionOwnerPid != null) {
          identityMatch = raw == sessionOwnerPid;
          if (!identityMatch) {
            unknown.add('session_cleanup_identity_mismatch');
          }
        } else {
          unknown.add('session_owner_pid_unknown_at_stop');
        }
      } else {
        unknown.add('session_cleanup_identity_runner_pid_invalid');
      }
    } else {
      unknown.add('session_cleanup_identity_missing');
    }
  }
  if (cleanup != null && !actionsSucceeded) {
    unknown.add('session_cleanup_actions_not_succeeded');
  }
  return {
    'sessionCleanup': cleanup,
    'sessionCleanupActionsSucceeded': actionsSucceeded ? true : false,
    'sessionOwnerPidAtStop': sessionOwnerPid,
    'sessionCleanupRunnerPid': runnerPid,
    'sessionCleanupIdentityMatch': identityMatch,
    'trackedHostIdentitiesFrozenAtLaunch': trackedIdentitiesFrozen,
    'observationComplete': unknown.isEmpty,
    'observationUnknownReasons': unknown,
    'limits':
        'Parsed from SDK session-teardown sidecar after identity-filtered '
        'read; frozen host identities are launch-time orphans only — '
        'not post-stop settlement authority.',
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
