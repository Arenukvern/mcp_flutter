import 'dart:convert';
import 'dart:io';

/// Android fixture application id (read-only process observation).
const kNativeCaptureFixtureAndroidPackage =
    'dev.mcpflutter.native_layer_capture_fixture';

/// Read-only host/device observations for oka-owned sessions (no kills).
Future<Map<String, Object?>> snapshotAndroidOwnedPhysicalObservations({
  required String phase,
  required String? deviceId,
  int? hostOkaDevChildPid,
  String? runnerDiscoveryPid,
}) async {
  final adb = Platform.environment['ADB'] ?? 'adb';
  final forwards = await Process.run(adb, ['forward', '--list']);
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
  return {
    'phase': phase,
    'observedAt': DateTime.now().toUtc().toIso8601String(),
    'hostOkaDevChildPid': hostOkaDevChildPid,
    'runnerDiscoveryPid': runnerDiscoveryPid,
    'adbForwardList': {
      'exitCode': forwards.exitCode,
      'lines': '${forwards.stdout}'
          .trim()
          .split('\n')
          .where((l) => l.isNotEmpty)
          .toList(),
      'stderrTail': '${forwards.stderr}'.trim(),
    },
    if (deviceId != null) 'deviceId': deviceId,
    if (devicePids != null) 'fixtureAppProcesses': devicePids,
    'readOnly': true,
  };
}

int? _discoveryPidFromOwnership(Map<String, Object?> ownership) {
  final pid = ownership['discoveryPid'];
  return pid is int ? pid : int.tryParse('$pid');
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
  await file.writeAsString('${const JsonEncoder.withIndent('  ').convert(timeline)}\n');
}

/// Convenience for integration: discovery pid from [snapshotRunnerSessionOwnership].
Future<void> recordAndroidPhysicalObservation({
  required Directory artifactDir,
  required String phase,
  required String deviceId,
  int? hostOkaDevChildPid,
  required Map<String, Object?> runnerOwnership,
}) async {
  await appendPhysicalObservationTimeline(
    artifactDir,
    await snapshotAndroidOwnedPhysicalObservations(
      phase: phase,
      deviceId: deviceId,
      hostOkaDevChildPid: hostOkaDevChildPid,
      runnerDiscoveryPid: '${_discoveryPidFromOwnership(runnerOwnership)}',
    ),
  );
}
