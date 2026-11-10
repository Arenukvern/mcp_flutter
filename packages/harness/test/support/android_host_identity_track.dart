import 'dart:io';

import 'package:oka_core/oka_core.dart';

/// Frozen host PIDs + start identity captured before cooperative stop.
Future<Map<String, Object?>> captureHostIdentityBundle({
  required int? spawnHandlePid,
  required int? sessionOwnerPid,
}) async {
  const probe = HostProcessTreeProbe();
  final identities = <Map<String, Object?>>[];

  Future<void> addTree(int? pid, String role) async {
    if (pid == null || pid <= 0) return;
    identities.add(await _identityForPid(pid, role: role, root: true));
    final tree = await probe.enumerate(pid);
    if (tree == null) return;
    for (final d in tree.descendants()) {
      identities.add(
        await _identityForPid(d, role: '${role}_descendant', root: false),
      );
    }
  }

  await addTree(spawnHandlePid, 'spawn_handle');
  await addTree(sessionOwnerPid, 'session_owner');

  final byPid = <int, Map<String, Object?>>{};
  for (final id in identities) {
    final pid = id['pid'] as int?;
    if (pid != null) byPid[pid] = id;
  }
  final frozen = byPid.values.toList()
    ..sort((a, b) => (a['pid'] as int).compareTo(b['pid'] as int));

  return {
    'capturedAt': DateTime.now().toUtc().toIso8601String(),
    'identityCount': frozen.length,
    'identities': frozen,
    'limits':
        'Does not track host processes spawned during stop after this capture.',
  };
}

Future<Map<String, Object?>> _identityForPid(
  int pid, {
  required String role,
  required bool root,
}) async {
  final stat = await _readProcStat(pid);
  final alive = await _pidAliveKill0(pid);
  final start = stat?['starttimeTicks'];
  return {
    'pid': pid,
    'role': role,
    'rootOfTree': root,
    'aliveAtCapture': alive,
    'starttimeTicks': start,
    'identityObservabilityAtCapture': start != null ? 'known' : 'unknown',
    'comm': stat?['comm'],
    'cmdlinePrefix': stat?['cmdlinePrefix'],
  };
}

Future<bool> _pidAliveKill0(int pid) async {
  final r = await Process.run('kill', ['-0', '$pid']);
  return r.exitCode == 0;
}

Future<Map<String, Object?>?> _readProcStat(int pid) async {
  try {
    final stat = await File('/proc/$pid/stat').readAsString();
    final close = stat.lastIndexOf(')');
    if (close < 0) return null;
    final after = stat.substring(close + 2).split(' ');
    final starttime = int.tryParse(after[19]);
    final comm = stat.substring(stat.indexOf('(') + 1, close);
    String? cmdline;
    try {
      final raw = await File('/proc/$pid/cmdline').readAsBytes();
      final filtered = raw.where((b) => b > 0 && b < 128).take(120).toList();
      cmdline = String.fromCharCodes(filtered);
    } on Object {
      cmdline = null;
    }
    return {
      'starttimeTicks': starttime,
      'comm': comm,
      'cmdlinePrefix': cmdline,
    };
  } on Object {
    return null;
  }
}

/// Re-check each frozen identity (read-only).
Future<List<Map<String, Object?>>> recheckTrackedHostIdentities(
  List<Map<String, Object?>> frozen,
) async {
  final out = <Map<String, Object?>>[];
  for (final id in frozen) {
    out.add(await _recheckOneIdentity(id));
  }
  return out;
}

Future<Map<String, Object?>> _recheckOneIdentity(Map<String, Object?> id) async {
  final pid = id['pid'] as int?;
  if (pid == null || pid <= 0) {
    return {
      ...id,
      'aliveNow': false,
      'identityObservabilityNow': 'unknown',
      'trackedProcessSurviving': false,
      'pidReuseSuspect': null,
    };
  }
  final alive = await _pidAliveKill0(pid);
  final stat = alive ? await _readProcStat(pid) : null;
  final expectedStart = id['starttimeTicks'];
  final actualStart = stat?['starttimeTicks'];
  final captureObs = id['identityObservabilityAtCapture'] as String?;

  String observabilityNow;
  bool? pidReuseSuspect;
  bool trackedSurviving;

  if (!alive) {
    observabilityNow = 'known_absent';
    trackedSurviving = false;
    pidReuseSuspect = false;
  } else if (captureObs == 'unknown' || expectedStart == null) {
    observabilityNow = 'unknown';
    trackedSurviving = true;
    pidReuseSuspect = null;
  } else if (actualStart == null) {
    observabilityNow = 'unknown';
    trackedSurviving = true;
    pidReuseSuspect = null;
  } else if (actualStart == expectedStart) {
    observabilityNow = 'known';
    trackedSurviving = true;
    pidReuseSuspect = false;
  } else {
    observabilityNow = 'known';
    trackedSurviving = true;
    pidReuseSuspect = true;
  }

  return {
    ...id,
    'aliveNow': alive,
    'starttimeTicksNow': actualStart,
    'commNow': stat?['comm'],
    'identityObservabilityNow': observabilityNow,
    'pidReuseSuspect': pidReuseSuspect,
    'trackedProcessSurviving': trackedSurviving,
  };
}

/// Pure evaluation for settlement (unknown at capture/now => not quiet).
Map<String, Object?> evaluateTrackedHostIdentities(
  List<Map<String, Object?>> rechecked,
) {
  final reasons = <String>[];
  var surviving = false;
  for (final id in rechecked) {
    final obs = id['identityObservabilityNow'] as String?;
    if (obs == 'unknown') {
      reasons.add('identity_unknown_pid_${id['pid']}');
      continue;
    }
    if (id['pidReuseSuspect'] == true) {
      surviving = true;
      continue;
    }
    if (id['trackedProcessSurviving'] == true) {
      surviving = true;
    }
  }
  return {
    'trackedHostIdentitiesQuiet': surviving == false && reasons.isEmpty,
    'observationComplete': reasons.isEmpty,
    'observationUnknownReasons': reasons,
    'trackedProcessSurviving': surviving,
  };
}

/// Test helper: evaluate one row without live /proc (injects recheck fields).
Map<String, Object?> evaluateSingleTrackedIdentityRow(Map<String, Object?> row) =>
    evaluateTrackedHostIdentities([row]);
