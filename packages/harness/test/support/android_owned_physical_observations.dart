import 'dart:convert';
import 'dart:io';

import 'android_adb_readonly_snapshot.dart';
import 'android_host_identity_track.dart';
import 'android_physical_forward_watch.dart';
import 'native_layer_evidence.dart';

export 'android_adb_readonly_snapshot.dart' show kNativeCaptureFixtureAndroidPackage;

const kPhysicalSettlementPollWindow = Duration(seconds: 10);
const _settlementPollInterval = Duration(milliseconds: 500);

/// Read-only host/device observations for oka-owned sessions (no kills).
Future<Map<String, Object?>> snapshotAndroidOwnedPhysicalObservations({
  required String phase,
  required String? deviceId,
  int? spawnHandlePid,
  int? sessionOwnerPid,
  AndroidVmForwardWatch? forwardWatch,
  List<String>? forwardBaselineLines,
  List<Map<String, Object?>>? trackedIdentitiesFrozen,
  Map<String, Object?>? runnerSessionOwnership,
}) async {
  final forwards = await fetchAdbForwardListOnce();
  final fixture = deviceId == null || deviceId.isEmpty
      ? {
          'observationComplete': false,
          'fixtureAppState': 'unknown',
          'observationUnknownReasons': ['empty_device_id'],
          'pidList': <String>[],
        }
      : await observeFixtureAppOnDevice(deviceId);

  Map<String, Object?>? forwardClassification;
  final unknownReasons = <String>[];
  if (forwards.parseFailures > 0) {
    unknownReasons.add('forward_line_parse_failures_${forwards.parseFailures}');
  }
  if (!forwards.observationComplete) {
    unknownReasons.add('adb_forward_list_exit_${forwards.exitCode}');
  }
  if (fixture['observationComplete'] != true) {
    unknownReasons.addAll(
      ((fixture['observationUnknownReasons'] as List?)?.cast<String>()) ??
          const [],
    );
  }
  if (forwardWatch != null && forwardBaselineLines != null) {
    forwardClassification = classifyAdbForwards(
      currentLines: forwards.lines,
      watch: forwardWatch,
      baselineLines: forwardBaselineLines,
      forwardListExitCode: forwards.exitCode,
    );
    if (forwardClassification['observationComplete'] != true) {
      unknownReasons.addAll(
        ((forwardClassification['observationUnknownReasons'] as List?)
                ?.cast<String>()) ??
            const [],
      );
    }
  } else if (forwardWatch == null || forwardBaselineLines == null) {
    unknownReasons.add('missing_forward_classification_inputs');
  }

  List<Map<String, Object?>>? identityRecheck;
  Map<String, Object?>? identityEval;
  if (trackedIdentitiesFrozen != null && trackedIdentitiesFrozen.isNotEmpty) {
    identityRecheck = await recheckTrackedHostIdentities(trackedIdentitiesFrozen);
    identityEval = evaluateTrackedHostIdentities(identityRecheck);
    if (identityEval['observationComplete'] != true) {
      unknownReasons.addAll(
        ((identityEval['observationUnknownReasons'] as List?)?.cast<String>()) ??
            const [],
      );
    }
  }

  return {
    'phase': phase,
    'observedAt': DateTime.now().toUtc().toIso8601String(),
    'spawnHandlePid': spawnHandlePid,
    'sessionOwnerPid': sessionOwnerPid,
    'forwardWatch': forwardWatch?.toJson(),
    'forwardClassification': forwardClassification,
    'trackedHostIdentityRecheck': identityRecheck,
    'trackedHostIdentityEval': identityEval,
    'fixtureAppProcesses': fixture,
    'deviceId': ?deviceId,
    'adbForwardList': {
      'exitCode': forwards.exitCode,
      'lines': forwards.lines,
      'stderrTail': forwards.stderrTail,
      'parseFailures': forwards.parseFailures,
    },
    'observationUnknownReasons': unknownReasons,
    'observationComplete': unknownReasons.isEmpty,
    'readOnly': true,
    'runnerSessionOwnership': ?runnerSessionOwnership,
  };
}

Future<void> appendPhysicalObservationTimeline(
  Directory artifactDir,
  Map<String, Object?> observation,
) async {
  final path = '${artifactDir.path}/android_owned_physical_observations.json';
  final file = File(path);
  final List<Object?> timeline;
  if (file.existsSync()) {
    timeline = jsonDecode(file.readAsStringSync()) as List<Object?>;
  } else {
    timeline = <Object?>[];
  }
  timeline.add(observation);
  await file.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(timeline)}\n',
  );
}

Future<void> recordAndroidPhysicalObservation({
  required Directory artifactDir,
  required String phase,
  required String deviceId,
  int? spawnHandlePid,
  int? sessionOwnerPid,
  AndroidVmForwardWatch? forwardWatch,
  List<String>? forwardBaselineLines,
  List<Map<String, Object?>>? trackedIdentitiesFrozen,
  Map<String, Object?>? runnerSessionOwnership,
}) async {
  await appendPhysicalObservationTimeline(
    artifactDir,
    await snapshotAndroidOwnedPhysicalObservations(
      phase: phase,
      deviceId: deviceId.isEmpty ? null : deviceId,
      spawnHandlePid: spawnHandlePid,
      sessionOwnerPid: sessionOwnerPid,
      forwardWatch: forwardWatch,
      forwardBaselineLines: forwardBaselineLines,
      trackedIdentitiesFrozen: trackedIdentitiesFrozen,
      runnerSessionOwnership: runnerSessionOwnership,
    ),
  );
}

/// Immutable baseline before `launchOka` (forwards + fixture); never mutated.
Future<Map<String, Object?>> writeAndroidPhysicalBaseline({
  required Directory artifactDir,
  required String phase,
  required String deviceId,
  required AdbForwardListSnapshot forwards,
  required Map<String, Object?> fixtureObservation,
}) async {
  final baseline = {
    'recordedAt': DateTime.now().toUtc().toIso8601String(),
    'phase': phase,
    'deviceId': deviceId,
    'adbForwardList': {
      'exitCode': forwards.exitCode,
      'lines': forwards.lines,
      'stderrTail': forwards.stderrTail,
      'parseFailures': forwards.parseFailures,
    },
    'fixtureAppProcesses': fixtureObservation,
    'immutable': true,
    'note':
        'Captured before launchOka; settlement delta compares current state '
        'to this snapshot without mutating it (delta does not prove ownership).',
  };
  await writeJsonArtifact(
    artifactDir,
    'android_owned_physical_baseline.json',
    baseline,
  );
  return baseline;
}

Future<Map<String, Object?>> recordAndroidPhysicalSettlementWindow({
  required Directory artifactDir,
  required String deviceId,
  int? spawnHandlePid,
  int? sessionOwnerPid,
  required AndroidVmForwardWatch forwardWatch,
  required List<String> forwardBaselineLines,
  required List<Map<String, Object?>> trackedIdentitiesFrozen,
  Duration window = kPhysicalSettlementPollWindow,
}) async {
  final started = DateTime.now();
  final deadline = started.add(window);
  final samples = <Map<String, Object?>>[];

  Future<Map<String, Object?>> takeSample(String phase) =>
      snapshotAndroidOwnedPhysicalObservations(
        phase: phase,
        deviceId: deviceId,
        spawnHandlePid: spawnHandlePid,
        sessionOwnerPid: sessionOwnerPid,
        forwardWatch: forwardWatch,
        forwardBaselineLines: forwardBaselineLines,
        trackedIdentitiesFrozen: trackedIdentitiesFrozen,
      );

  while (DateTime.now().isBefore(deadline)) {
    final sample = await takeSample('post_stop_settle_poll');
    samples.add(sample);
    await appendPhysicalObservationTimeline(artifactDir, sample);
    if (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(_settlementPollInterval);
    }
  }

  while (DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  final finalSample = await takeSample('post_stop_settle_final');
  await appendPhysicalObservationTimeline(artifactDir, finalSample);

  final elapsedMs = DateTime.now().difference(started).inMilliseconds;
  final deadlineMet = elapsedMs >= window.inMilliseconds;
  final finalForVerdict = {
    ...finalSample,
    'settlementWindowDeadlineMet': deadlineMet,
  };
  final verdictFields = physicalSettlementVerdictFromObservation(finalForVerdict);
  final proven = verdictFields['provenPhysicalSettlement'] == true;

  final evidence = {
    ...verdictFields,
    'limits':
        'Host identities frozen before stop; processes spawned during stop are '
        'not tracked. Candidates are not deletion authority for owned forwards.',
    'windowSeconds': window.inSeconds,
    'pollIntervalMs': _settlementPollInterval.inMilliseconds,
    'windowElapsedMs': elapsedMs,
    'finalSampleAtOrAfterDeadline': elapsedMs >= window.inMilliseconds,
    'sampleCount': samples.length + 1,
    'settlementPollSamples': [...samples, finalSample],
    'observationsTimelineFile': 'android_owned_physical_observations.json',
    'baselineFile': 'android_owned_physical_baseline.json',
    'finalObservation': finalSample,
    'verdict': proven
        ? 'physical_settled'
        : verdictFields['observationComplete'] == false
            ? 'physical_observation_incomplete'
            : 'physical_leak_or_slow_teardown',
  };
  await writeJsonArtifact(
    artifactDir,
    'android_physical_settlement_evidence.json',
    evidence,
  );
  return evidence;
}

Map<String, Object?> physicalSettlementVerdictFromObservation(
  Map<String, Object?> observation,
) {
  final unknown = <String>[
    ...(((observation['observationUnknownReasons'] as List?)?.cast<String>()) ??
        const []),
  ];
  if (observation['observationComplete'] != true) {
    unknown.add('snapshot_observation_incomplete');
  }
  if (observation['settlementWindowDeadlineMet'] == false) {
    unknown.add('settlement_window_deadline_not_met');
  }

  final classification = observation['forwardClassification'] as Map?;
  if (classification == null) {
    unknown.add('missing_forward_classification');
  }
  if (classification?['observationComplete'] != true) {
    unknown.addAll(
      ((classification?['observationUnknownReasons'] as List?)?.cast<String>()) ??
          const [],
    );
  }

  final identityEval =
      observation['trackedHostIdentityEval'] as Map<String, Object?>?;
  if (identityEval == null) {
    unknown.add('missing_tracked_host_identity_eval');
  } else if (identityEval['observationComplete'] != true) {
    unknown.addAll(
      ((identityEval['observationUnknownReasons'] as List?)?.cast<String>()) ??
          const [],
    );
  }

  final fixture = observation['fixtureAppProcesses'] as Map?;
  if (fixture?['observationComplete'] != true) {
    unknown.addAll(
      ((fixture?['observationUnknownReasons'] as List?)?.cast<String>()) ??
          const [],
    );
  }

  final observationComplete = unknown.isEmpty;
  final matchedOwned =
      (classification?['matchedOwnedBaselineLines'] as List?)?.cast<String>() ??
          const <String>[];
  final remoteCandidates =
      (classification?['sameDeviceRemotePortCandidates'] as List?)
              ?.cast<String>() ??
          const <String>[];
  final forwardLines =
      ((observation['adbForwardList'] as Map?)?['lines'] as List?)
              ?.cast<String>() ??
          const <String>[];

  final fixtureState = fixture?['fixtureAppState'] as String?;
  final deviceAppGone =
      observationComplete && fixtureState == 'not_running';
  final forwardsCleared = observationComplete && matchedOwned.isEmpty;
  final hostQuiet =
      observationComplete && identityEval?['trackedHostIdentitiesQuiet'] == true;
  final candidatesPresent = remoteCandidates.isNotEmpty;

  final proven = observationComplete &&
      forwardsCleared &&
      deviceAppGone &&
      hostQuiet &&
      !candidatesPresent;

  return {
    'provenPhysicalSettlement': proven,
    'provenOwnedResourceSettlement': false,
    'observationComplete': observationComplete,
    'observationUnknownReasons': unknown,
    'forwardLinesAtEnd': forwardLines,
    'matchedOwnedBaselineLinesAtEnd': matchedOwned,
    'sameDeviceRemotePortCandidatesAtEnd': remoteCandidates,
    'remotePortCandidatesPresentAtEnd': candidatesPresent,
    'fixtureAppStateAtEnd': fixtureState,
    'deviceAppGoneAtEnd': deviceAppGone,
    'trackedHostIdentitiesQuietAtEnd':
        identityEval?['trackedHostIdentitiesQuiet'],
  };
}
