import 'dart:convert';
import 'dart:io';

import 'android_host_identity_track.dart';
import 'android_physical_forward_watch.dart';
import 'native_layer_evidence.dart';

/// Android fixture application id (read-only process observation).
const kNativeCaptureFixtureAndroidPackage =
    'dev.mcpflutter.native_layer_capture_fixture';

const kPhysicalSettlementPollWindow = Duration(seconds: 10);
const _settlementPollInterval = Duration(milliseconds: 500);

Future<List<String>> _adbForwardLines() async {
  final adb = Platform.environment['ADB'] ?? 'adb';
  final forwards = await Process.run(adb, ['forward', '--list']);
  return '${forwards.stdout}'
      .trim()
      .split('\n')
      .where((l) => l.isNotEmpty)
      .toList();
}

Future<Map<String, Object?>?> _fixtureDevicePids(String deviceId) async {
  if (deviceId.isEmpty) return null;
  final adb = Platform.environment['ADB'] ?? 'adb';
  final pidof = await Process.run(
    adb,
    ['-s', deviceId, 'shell', 'pidof', kNativeCaptureFixtureAndroidPackage],
  );
  final stdout = '${pidof.stdout}'.trim();
  return {
    'exitCode': pidof.exitCode,
    'pidofStdout': stdout.isEmpty ? null : stdout,
    'pidList': stdout.isEmpty
        ? <String>[]
        : stdout.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList(),
  };
}

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
  final forwardLines = await _adbForwardLines();
  final adb = Platform.environment['ADB'] ?? 'adb';
  final forwards = await Process.run(adb, ['forward', '--list']);

  Map<String, Object?>? devicePids;
  if (deviceId != null && deviceId.isNotEmpty) {
    devicePids = await _fixtureDevicePids(deviceId);
  }

  Map<String, Object?>? forwardClassification;
  if (forwardWatch != null && forwardBaselineLines != null) {
    forwardClassification = classifyAdbForwards(
      currentLines: forwardLines,
      watch: forwardWatch,
      baselineLines: forwardBaselineLines,
    );
  }

  List<Map<String, Object?>>? identityRecheck;
  if (trackedIdentitiesFrozen != null && trackedIdentitiesFrozen.isNotEmpty) {
    identityRecheck = await recheckTrackedHostIdentities(trackedIdentitiesFrozen);
  }

  return {
    'phase': phase,
    'observedAt': DateTime.now().toUtc().toIso8601String(),
    'spawnHandlePid': spawnHandlePid,
    'sessionOwnerPid': sessionOwnerPid,
    'forwardWatch': forwardWatch?.toJson(),
    'forwardClassification': forwardClassification,
    'trackedHostIdentityRecheck': identityRecheck,
    'trackedHostIdentitiesQuiet':
        identityRecheck == null ? null : trackedHostIdentitiesQuiet(identityRecheck),
    'fixtureAppProcesses': ?devicePids,
    'deviceId': ?deviceId,
    'adbForwardList': {
      'exitCode': forwards.exitCode,
      'lines': forwardLines,
      'stderrTail': '${forwards.stderr}'.trim(),
    },
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

/// Writes immutable pre-stop baseline (forwards, app, watch) — not mutated later.
Future<Map<String, Object?>> writeAndroidPhysicalBaseline({
  required Directory artifactDir,
  required String deviceId,
  required AndroidVmForwardWatch forwardWatch,
  required List<String> forwardLines,
  required Map<String, Object?>? fixtureAppProcesses,
  required Map<String, Object?> identityBundle,
}) async {
  final baseline = {
    'recordedAt': DateTime.now().toUtc().toIso8601String(),
    'phase': 'pre_stop_baseline',
    'deviceId': deviceId,
    'forwardWatch': forwardWatch.toJson(),
    'adbForwardLines': List<String>.from(forwardLines),
    'fixtureAppProcesses': fixtureAppProcesses,
    'hostIdentityBundle': identityBundle,
    'immutable': true,
    'note':
        'Snapshot before cooperative stop; settlement compares against this '
        'without mutating stored lines.',
  };
  await writeJsonArtifact(
    artifactDir,
    'android_owned_physical_baseline.json',
    baseline,
  );
  return baseline;
}

/// Bounded read-only polling after cooperative stop (no kills).
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

  final last = finalSample;
  final elapsedMs = DateTime.now().difference(started).inMilliseconds;

  final verdictFields = physicalSettlementVerdictFromObservation(last);
  final proven = verdictFields['provenPhysicalSettlement'] == true;

  final evidence = {
    ...verdictFields,
    'note':
        'Physical settlement requires cleared owned forward baseline, no '
        'fixture app pid, and no live tracked host identities (by pid+starttime). '
        'SDK DevSessionStopReport.ok is runner-only; never '
        'provenOwnedResourceSettlement.',
    'sdkGapExpectation':
        'Read-only window documents survivors; no all-resource cleanup claim.',
    'windowSeconds': window.inSeconds,
    'pollIntervalMs': _settlementPollInterval.inMilliseconds,
    'windowElapsedMs': elapsedMs,
    'finalSampleAtOrAfterDeadline': elapsedMs >= window.inMilliseconds,
    'sampleCount': samples.length + 1,
    'settlementPollSamples': [...samples, finalSample],
    'observationsTimelineFile': 'android_owned_physical_observations.json',
    'baselineFile': 'android_owned_physical_baseline.json',
    'finalObservation': last,
    'verdict': proven ? 'physical_settled' : 'physical_leak_or_slow_teardown',
  };
  await writeJsonArtifact(
    artifactDir,
    'android_physical_settlement_evidence.json',
    evidence,
  );
  return evidence;
}

/// Derives read-only physical settlement verdict from one observation snapshot.
Map<String, Object?> physicalSettlementVerdictFromObservation(
  Map<String, Object?> observation,
) {
  final classification = observation['forwardClassification'] as Map?;
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
  final appPids =
      ((observation['fixtureAppProcesses'] as Map?)?['pidList'] as List?) ??
          const [];
  final identitiesQuiet = observation['trackedHostIdentitiesQuiet'] == true;

  final forwardsCleared = matchedOwned.isEmpty;
  final deviceAppGone = appPids.isEmpty;
  final hostQuiet = identitiesQuiet;

  final proven = forwardsCleared && deviceAppGone && hostQuiet;

  return {
    'provenPhysicalSettlement': proven,
    'provenOwnedResourceSettlement': false,
    'forwardLinesAtEnd': forwardLines,
    'matchedOwnedBaselineLinesAtEnd': matchedOwned,
    'sameDeviceRemotePortCandidatesAtEnd': remoteCandidates,
    'deviceAppPidsAtEnd': appPids,
    'trackedHostIdentitiesQuietAtEnd': identitiesQuiet,
  };
}
