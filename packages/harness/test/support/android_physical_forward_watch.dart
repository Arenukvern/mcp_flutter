/// Classifies adb `forward --list` lines for VM session settlement (not control).
final class AndroidVmForwardWatch {
  const AndroidVmForwardWatch({
    required this.deviceId,
    required this.hostLocalVmPorts,
    required this.deviceRemoteVmPorts,
    this.excludeHostPorts = const {},
  });

  final String deviceId;
  final Set<int> hostLocalVmPorts;
  final Set<int> deviceRemoteVmPorts;

  /// e.g. loopback control — never used for VM forward matching.
  final Set<int> excludeHostPorts;

  Map<String, Object?> toJson() => {
        'deviceId': deviceId,
        'hostLocalVmPorts': hostLocalVmPorts.toList()..sort(),
        'deviceRemoteVmPorts': deviceRemoteVmPorts.toList()..sort(),
        'excludeHostPorts': excludeHostPorts.toList()..sort(),
      };
}

/// Build watch from runner-session ownership + live forward list (read-only).
AndroidVmForwardWatch buildAndroidVmForwardWatch({
  required String deviceId,
  required Map<String, Object?> ownership,
  required List<String> forwardLines,
}) {
  final localVm = ownership['vmServiceUriPort'] as int?;
  final control = ownership['controlPort'] as int?;
  final hostLocals = <int>{};
  if (localVm != null && localVm > 0) {
    hostLocals.add(localVm);
  }
  final deviceRemotes = <int>{};
  for (final line in forwardLines) {
  final parsed = _parseForwardLine(line);
    if (parsed == null) continue;
    if (parsed.serial != deviceId) continue;
    if (localVm != null && parsed.hostPort == localVm) {
      deviceRemotes.add(parsed.devicePort);
    }
  }
  // Secondary host locals sharing the same device remote VM port (e.g. 35059→35699).
  for (final line in forwardLines) {
    final parsed = _parseForwardLine(line);
    if (parsed == null) continue;
    if (parsed.serial != deviceId) continue;
    if (deviceRemotes.contains(parsed.devicePort) &&
        parsed.hostPort != localVm &&
        parsed.hostPort > 0) {
      if (control == null || parsed.hostPort != control) {
        hostLocals.add(parsed.hostPort);
      }
    }
  }
  return AndroidVmForwardWatch(
    deviceId: deviceId,
    hostLocalVmPorts: hostLocals,
    deviceRemoteVmPorts: deviceRemotes,
    excludeHostPorts: control != null && control > 0 ? {control} : const {},
  );
}

({String serial, int hostPort, int devicePort})? _parseForwardLine(String line) {
  final parts = line.trim().split(RegExp(r'\s+'));
  if (parts.length < 3) return null;
  final serial = parts[0];
  final host = parts[1];
  final device = parts[2];
  final hp = _tcpPort(host);
  final dp = _tcpPort(device);
  if (hp == null || dp == null) return null;
  return (serial: serial, hostPort: hp, devicePort: dp);
}

int? _tcpPort(String spec) {
  if (!spec.startsWith('tcp:')) return null;
  return int.tryParse(spec.substring(4));
}

/// Immutable baseline + delta classification (baseline not mutated).
Map<String, Object?> classifyAdbForwards({
  required List<String> currentLines,
  required AndroidVmForwardWatch watch,
  required List<String> baselineLines,
}) {
  final ownedMatched = <String>[];
  final remoteCandidates = <String>[];
  final baselineSet = baselineLines.toSet();
  for (final line in currentLines) {
    final parsed = _parseForwardLine(line);
    if (parsed == null) continue;
    if (parsed.serial != watch.deviceId) continue;
    final matchesOwned = watch.hostLocalVmPorts.contains(parsed.hostPort) ||
        watch.deviceRemoteVmPorts.contains(parsed.devicePort);
    if (matchesOwned) {
      ownedMatched.add(line);
      continue;
    }
    final sharesRemote = watch.deviceRemoteVmPorts.contains(parsed.devicePort);
    if (sharesRemote) {
      remoteCandidates.add(line);
    }
  }
  final notInBaseline =
      currentLines.where((l) => !baselineSet.contains(l)).toList();
  return {
    'baselineLines': List<String>.from(baselineLines),
    'currentLines': currentLines,
    'matchedOwnedBaselineLines': ownedMatched,
    'sameDeviceRemotePortCandidates': remoteCandidates,
    'linesNotInBaselineSnapshot': notInBaseline,
    'watch': watch.toJson(),
  };
}
