import 'dart:convert';
import 'dart:io';

import 'package:oka_core/oka_core.dart';

import 'native_layer_evidence.dart';

/// Android fixture application id (read-only process observation).
const kNativeCaptureFixtureAndroidPackage =
    'dev.mcpflutter.native_layer_capture_fixture';

const kPhysicalSettlementPollWindow = Duration(seconds: 10);
const _settlementPollInterval = Duration(milliseconds: 500);

Future<bool> _pidAlive(int pid) async {
  if (pid <= 0) return false;
  final probe = await Process.run('kill', ['-0', '$pid']);
  return probe.exitCode == 0;
}

Future<Map<String, Object?>> _hostProcessSlice(int? pid) async {
  if (pid == null || pid <= 0) {
    return {'pid': pid, 'alive': false, 'descendantPids': <int>[]};
  }
  final alive = await _pidAlive(pid);
  const probe = HostProcessTreeProbe();
  final tree = await probe.enumerate(pid);
  final descendants =
      tree == null ? <int>[] : tree.descendants();
  return {
    'pid': pid,
    'alive': alive,
    'descendantPids': descendants,
    'descendantCount': descendants.length,
  };
}

List<String> _forwardLinesMatchingPorts(List<String> lines, Set<int> ports) {
  if (ports.isEmpty) return const [];
  return lines
      .where((line) => ports.any((p) => line.contains('tcp:$p')))
      .toList();
}

/// Read-only host/device observations for oka-owned sessions (no kills).
Future<Map<String, Object?>> snapshotAndroidOwnedPhysicalObservations({
  required String phase,
  required String? deviceId,
  int? spawnHandlePid,
  int? sessionOwnerPid,
  Set<int> vmForwardHostPorts = const {},
  Map<String, Object?>? runnerSessionOwnership,
}) async {
  final adb = Platform.environment['ADB'] ?? 'adb';
  final forwards = await Process.run(adb, ['forward', '--list']);
  final forwardLines = '${forwards.stdout}'
      .trim()
      .split('\n')
      .where((l) => l.isNotEmpty)
      .toList();
  Map<String, Object?>? devicePids;
  if (deviceId != null && deviceId.isNotEmpty) {
    final pidof = await Process.run(
      adb,
      ['-s', deviceId, 'shell', 'pidof', kNativeCaptureFixtureAndroidPackage],
    );
    final stdout = '${pidof.stdout}'.trim();
    devicePids = {
      'exitCode': pidof.exitCode,
      'pidofStdout': stdout.isEmpty ? null : stdout,
      'pidList': stdout.isEmpty
          ? <String>[]
          : stdout.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList(),
    };
  }
  final spawnSlice = await _hostProcessSlice(spawnHandlePid);
  final ownerSlice = await _hostProcessSlice(sessionOwnerPid);
  final matchedForwards = _forwardLinesMatchingPorts(forwardLines, vmForwardHostPorts);

  return {
    'phase': phase,
    'observedAt': DateTime.now().toUtc().toIso8601String(),
    'spawnHandlePid': spawnHandlePid,
    'sessionOwnerPid': sessionOwnerPid,
    'hostSpawnHandle': spawnSlice,
    'hostSessionOwner': ownerSlice,
    'vmForwardHostPortsWatched': vmForwardHostPorts.toList(),
    'adbForwardList': {
      'exitCode': forwards.exitCode,
      'lines': forwardLines,
      'matchedVmSessionLines': matchedForwards,
      'stderrTail': '${forwards.stderr}'.trim(),
    },
    'deviceId': ?deviceId,
    'fixtureAppProcesses': ?devicePids,
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
  Set<int> vmForwardHostPorts = const {},
  Map<String, Object?>? runnerSessionOwnership,
}) async {
  await appendPhysicalObservationTimeline(
    artifactDir,
    await snapshotAndroidOwnedPhysicalObservations(
      phase: phase,
      deviceId: deviceId.isEmpty ? null : deviceId,
      spawnHandlePid: spawnHandlePid,
      sessionOwnerPid: sessionOwnerPid,
      vmForwardHostPorts: vmForwardHostPorts,
      runnerSessionOwnership: runnerSessionOwnership,
    ),
  );
}

/// Bounded read-only polling after cooperative stop (no kills).
Future<Map<String, Object?>> recordAndroidPhysicalSettlementWindow({
  required Directory artifactDir,
  required String deviceId,
  int? spawnHandlePid,
  int? sessionOwnerPid,
  Set<int> vmForwardHostPorts = const {},
  Duration window = kPhysicalSettlementPollWindow,
}) async {
  final started = DateTime.now();
  final samples = <Map<String, Object?>>[];
  while (DateTime.now().difference(started) < window) {
    final sample = await snapshotAndroidOwnedPhysicalObservations(
      phase: 'post_stop_settle_poll',
      deviceId: deviceId,
      spawnHandlePid: spawnHandlePid,
      sessionOwnerPid: sessionOwnerPid,
      vmForwardHostPorts: vmForwardHostPorts,
    );
    samples.add(sample);
    await appendPhysicalObservationTimeline(artifactDir, sample);
    await Future<void>.delayed(_settlementPollInterval);
  }
  final last = samples.isEmpty
      ? await snapshotAndroidOwnedPhysicalObservations(
          phase: 'post_stop_settle_final',
          deviceId: deviceId,
          spawnHandlePid: spawnHandlePid,
          sessionOwnerPid: sessionOwnerPid,
          vmForwardHostPorts: vmForwardHostPorts,
        )
      : samples.last;
  if (samples.isEmpty) {
    await appendPhysicalObservationTimeline(artifactDir, last);
  }

  final verdictFields = physicalSettlementVerdictFromObservation(last);
  final proven = verdictFields['provenPhysicalSettlement'] == true;

  final evidence = {
    ...verdictFields,
    'note':
        'Physical settlement requires cleared VM forwards, no fixture app pid, '
        'and no live host owner/spawn/descendants after window. SDK '
        'DevSessionStopReport.ok is runner-only (quit app.stop best-effort, '
        'daemon shutdown fire-and-forget, no await); never '
        'provenOwnedResourceSettlement. No adb forward --remove in SDK.',
    'sdkGapExpectation':
        '10s read-only window documents survivors (forwards, app pid, host tree); '
        'does not claim all-resource settlement success.',
    'windowSeconds': window.inSeconds,
    'pollIntervalMs': _settlementPollInterval.inMilliseconds,
    'sampleCount': samples.length,
    'settlementPollSamples': samples,
    'observationsTimelineFile': 'android_owned_physical_observations.json',
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
  final forwardLines =
      ((observation['adbForwardList'] as Map?)?['lines'] as List?)
              ?.cast<String>() ??
          const <String>[];
  final matched =
      ((observation['adbForwardList'] as Map?)?['matchedVmSessionLines'] as List?)
              ?.cast<String>() ??
          const <String>[];
  final appPids =
      ((observation['fixtureAppProcesses'] as Map?)?['pidList'] as List?) ??
          const [];
  final ownerAlive =
      (observation['hostSessionOwner'] as Map?)?['alive'] == true;
  final spawnAlive =
      (observation['hostSpawnHandle'] as Map?)?['alive'] == true;
  final ownerDescendants =
      ((observation['hostSessionOwner'] as Map?)?['descendantPids'] as List?) ??
          [];
  final spawnDescendants =
      ((observation['hostSpawnHandle'] as Map?)?['descendantPids'] as List?) ??
          [];

  final forwardsCleared = matched.isEmpty;
  final deviceAppGone = appPids.isEmpty;
  final hostTreeQuiet = !ownerAlive &&
      !spawnAlive &&
      ownerDescendants.isEmpty &&
      spawnDescendants.isEmpty;

  final proven = forwardsCleared && deviceAppGone && hostTreeQuiet;

  return {
    'provenPhysicalSettlement': proven,
    'provenOwnedResourceSettlement': false,
    'forwardLinesAtEnd': forwardLines,
    'matchedVmForwardsAtEnd': matched,
    'deviceAppPidsAtEnd': appPids,
    'hostOwnerAliveAtEnd': ownerAlive,
    'hostSpawnAliveAtEnd': spawnAlive,
    'hostOwnerDescendantCountAtEnd': ownerDescendants.length,
    'hostSpawnDescendantCountAtEnd': spawnDescendants.length,
  };
}
