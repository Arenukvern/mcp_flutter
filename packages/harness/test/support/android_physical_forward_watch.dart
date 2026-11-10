/// Classifies adb `forward --list` lines for VM session settlement (not control).
final class AndroidVmForwardWatch {
  const AndroidVmForwardWatch({
    required this.deviceId,
    required this.hostLocalVmPorts,
    required this.deviceRemoteVmPorts,
    this.excludeHostPorts = const {},
    this.observationComplete = true,
    this.observationUnknownReasons = const [],
  });

  final String deviceId;
  final Set<int> hostLocalVmPorts;
  final Set<int> deviceRemoteVmPorts;
  final Set<int> excludeHostPorts;
  final bool observationComplete;
  final List<String> observationUnknownReasons;

  bool get isUsable =>
      observationComplete &&
      deviceId.isNotEmpty &&
      hostLocalVmPorts.isNotEmpty &&
      deviceRemoteVmPorts.isNotEmpty;

  Map<String, Object?> toJson() => {
        'deviceId': deviceId,
        'hostLocalVmPorts': hostLocalVmPorts.toList()..sort(),
        'deviceRemoteVmPorts': deviceRemoteVmPorts.toList()..sort(),
        'excludeHostPorts': excludeHostPorts.toList()..sort(),
        'observationComplete': observationComplete,
        'observationUnknownReasons': observationUnknownReasons,
      };
}

/// Build watch from runner-session ownership + one forward list snapshot.
AndroidVmForwardWatch buildAndroidVmForwardWatch({
  required String deviceId,
  required Map<String, Object?> ownership,
  required List<String> forwardLines,
  int? forwardListExitCode,
}) {
  final reasons = <String>[];
  if (deviceId.isEmpty) {
    reasons.add('empty_device_id');
  }
  if (forwardListExitCode != null && forwardListExitCode != 0) {
    reasons.add('adb_forward_list_exit_$forwardListExitCode');
  }
  final localVm = ownership['vmServiceUriPort'] as int?;
  final control = ownership['controlPort'] as int?;
  if (localVm == null || localVm <= 0) {
    reasons.add('missing_vm_service_uri_port');
  }
  final hostLocals = <int>{};
  if (localVm != null && localVm > 0) {
    hostLocals.add(localVm);
  }
  final deviceRemotes = <int>{};
  for (final line in forwardLines) {
    final parsed = parseForwardLine(line);
    if (parsed == null) continue;
    if (parsed.serial != deviceId) continue;
    if (localVm != null && parsed.hostPort == localVm) {
      deviceRemotes.add(parsed.devicePort);
    }
  }
  if (hostLocals.isNotEmpty && deviceRemotes.isEmpty) {
    reasons.add('no_device_remote_for_primary_local_forward');
  }
  return AndroidVmForwardWatch(
    deviceId: deviceId,
    hostLocalVmPorts: hostLocals,
    deviceRemoteVmPorts: deviceRemotes,
    excludeHostPorts: control != null && control > 0 ? {control} : const {},
    observationComplete: reasons.isEmpty,
    observationUnknownReasons: reasons,
  );
}

typedef ParsedForwardLine = ({String serial, int hostPort, int devicePort});

ParsedForwardLine? parseForwardLine(String line) {
  final parts = line.trim().split(RegExp(r'\s+'));
  if (parts.length < 3) return null;
  final serial = parts[0];
  final hp = _tcpPort(parts[1]);
  final dp = _tcpPort(parts[2]);
  if (hp == null || dp == null) return null;
  return (serial: serial, hostPort: hp, devicePort: dp);
}

int? _tcpPort(String spec) {
  if (!spec.startsWith('tcp:')) return null;
  return int.tryParse(spec.substring(4));
}

/// Owned = recorded primary host local forward only; remote peers are candidates.
Map<String, Object?> classifyAdbForwards({
  required List<String> currentLines,
  required AndroidVmForwardWatch watch,
  required List<String> baselineLines,
  required int forwardListExitCode,
}) {
  if (forwardListExitCode != 0) {
    return {
      'observationComplete': false,
      'observationUnknownReasons': ['adb_forward_list_exit_$forwardListExitCode'],
      'baselineLines': List<String>.from(baselineLines),
      'currentLines': currentLines,
      'matchedOwnedBaselineLines': <String>[],
      'sameDeviceRemotePortCandidates': <String>[],
      'linesNotInBaselineSnapshot': <String>[],
      'watch': watch.toJson(),
    };
  }
  if (!watch.isUsable) {
    return {
      'observationComplete': false,
      'observationUnknownReasons': watch.observationUnknownReasons,
      'baselineLines': List<String>.from(baselineLines),
      'currentLines': currentLines,
      'matchedOwnedBaselineLines': <String>[],
      'sameDeviceRemotePortCandidates': <String>[],
      'linesNotInBaselineSnapshot': <String>[],
      'watch': watch.toJson(),
    };
  }

  final ownedMatched = <String>[];
  final remoteCandidates = <String>[];
  final baselineSet = baselineLines.toSet();
  for (final line in currentLines) {
    final parsed = parseForwardLine(line);
    if (parsed == null) continue;
    if (parsed.serial != watch.deviceId) continue;
  final ownedHost = watch.hostLocalVmPorts.contains(parsed.hostPort);
    if (ownedHost) {
      ownedMatched.add(line);
      continue;
    }
    final peerRemote = watch.deviceRemoteVmPorts.contains(parsed.devicePort);
    if (peerRemote) {
      remoteCandidates.add(line);
    }
  }
  final notInBaseline =
      currentLines.where((l) => !baselineSet.contains(l)).toList();
  return {
    'observationComplete': true,
    'observationUnknownReasons': <String>[],
    'baselineLines': List<String>.from(baselineLines),
    'currentLines': currentLines,
    'matchedOwnedBaselineLines': ownedMatched,
    'sameDeviceRemotePortCandidates': remoteCandidates,
    'linesNotInBaselineSnapshot': notInBaseline,
    'watch': watch.toJson(),
    'note':
        'Candidates share device remote VM port but are not the owned host-local '
        'pair; clearing candidates is not deletion authority for owned lines.',
  };
}
