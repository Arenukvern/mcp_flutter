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

  // Dedupe by pid (owner may overlap spawn ancestry).
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
  };
}

Future<Map<String, Object?>> _identityForPid(
  int pid, {
  required String role,
  required bool root,
}) async {
  final stat = await _readProcStat(pid);
  final alive = await _pidAliveKill0(pid);
  return {
    'pid': pid,
    'role': role,
    'rootOfTree': root,
    'aliveAtCapture': alive,
    'starttimeTicks': stat?['starttimeTicks'],
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
    final starttime = int.tryParse(after[19]); // field 22 (1-based after comm)
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

/// Re-check each frozen identity; orphans remain addressable after parent exit.
Future<List<Map<String, Object?>>> recheckTrackedHostIdentities(
  List<Map<String, Object?>> frozen,
) async {
  final out = <Map<String, Object?>>[];
  for (final id in frozen) {
    final pid = id['pid'] as int?;
    if (pid == null) {
      out.add({...id, 'aliveNow': false, 'identityMatch': false});
      continue;
    }
    final alive = await _pidAliveKill0(pid);
    final stat = alive ? await _readProcStat(pid) : null;
    final expectedStart = id['starttimeTicks'];
    final actualStart = stat?['starttimeTicks'];
    final identityMatch = !alive ||
        (expectedStart != null &&
            actualStart != null &&
            expectedStart == actualStart);
    final pidReuseSuspect =
        alive && expectedStart != null && actualStart != expectedStart;
    out.add({
      ...id,
      'aliveNow': alive,
      'starttimeTicksNow': actualStart,
      'commNow': stat?['comm'],
      'identityMatch': identityMatch,
      'pidReuseSuspect': pidReuseSuspect,
    });
  }
  return out;
}

/// True when any tracked identity is alive with matching starttime (not reuse).
bool trackedHostIdentitiesQuiet(List<Map<String, Object?>> rechecked) {
  for (final id in rechecked) {
    if (id['aliveNow'] != true) continue;
    if (id['pidReuseSuspect'] == true) continue;
    if (id['identityMatch'] == true) return false;
  }
  return true;
}
