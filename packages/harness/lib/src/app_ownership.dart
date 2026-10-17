import 'dart:io';
import 'dart:math' as math;

/// How a scenario relates to the app process it drives.
enum AppOwnership {
  /// Build + launch + own: `launch` starts the process and `stop` ends
  /// it. The default — a scenario that owns bring-up can own teardown.
  launchAndOwn,

  /// Attach to an ALREADY-RUNNING app: the target never launches and
  /// never stops it (a borrowed lease — the safe choice when a desktop
  /// process was found running, because stopping someone's session is
  /// not the harness's call). Attach verifies the running binary
  /// instead: it must resolve to the target's [BinaryAppTarget.binaryPath]
  /// and the on-disk build must not be newer than the process (a stale
  /// app silently passing as the build under test is the failure mode
  /// this mode exists to prevent).
  attachOnly,
}

/// Identity of a built binary — the attach-only staleness contract.
///
/// Attach cannot know what the running process USED to be; it can only
/// compare identity. [BinaryAppTarget] checks that the pid's executable
/// resolves to the target's binary path and that the process started
/// before the on-disk binary's mtime; a scenario that wants a stronger
/// pin records a fingerprint right after building and passes it as
/// [BinaryAppTarget.expectedFingerprint] — attach then refuses to drive
/// anything but exactly that build.
final class BuildFingerprint {
  const BuildFingerprint({
    required this.path,
    required this.sizeBytes,
    required this.sha256,
    required this.modifiedAt,
  });

  final String path;
  final int sizeBytes;
  final String sha256;
  final DateTime modifiedAt;

  /// Fingerprints the file at [path] (sha256 via the system `shasum` —
  /// no crypto dependency in a harness that also runs on pub-only
  /// consumers).
  static Future<BuildFingerprint> of(final String path) async {
    final stat = await File(path).stat();
    final hash = await Process.run('shasum', <String>['-a', '256', path]);
    if (hash.exitCode != 0) {
      throw StateError('shasum -a 256 failed for $path: ${hash.stderr}');
    }
    return BuildFingerprint(
      path: path,
      sizeBytes: stat.size,
      sha256: (hash.stdout as String).split(' ').first.trim(),
      modifiedAt: stat.modified,
    );
  }

  /// Same build CONTENT (hash + size), regardless of mtime — copying or
  /// re-signing in place does not change the build.
  bool sameBuildAs(final BuildFingerprint other) =>
      sha256 == other.sha256 && sizeBytes == other.sizeBytes;

  @override
  bool operator ==(final Object other) =>
      other is BuildFingerprint &&
      other.path == path &&
      other.sizeBytes == sizeBytes &&
      other.sha256 == sha256;

  @override
  int get hashCode => Object.hash(path, sizeBytes, sha256);

  @override
  String toString() =>
      '$path (sha256 ${sha256.substring(0, math.min(12, sha256.length))}…, '
      '$sizeBytes B, modified $modifiedAt)';
}

/// `pgrep` stdout → pids (one per line, blank lines skipped).
List<int> parsePgrepPids(final String stdout) => stdout
    .split('\n')
    .map((final line) => line.trim())
    .where((final line) => line.isNotEmpty)
    .map(int.tryParse)
    .whereType<int>()
    .toList();

/// `lsof -a -p <pid> -d txt -Fn` stdout → the running executable's path
/// (the last `n` record; loader/kernel entries come first). Null when
/// the output carries none.
String? parseLsofExecutablePath(final String stdout) {
  final paths = stdout
      .split('\n')
      .where((final line) => line.startsWith('n'))
      .map((final line) => line.substring(1))
      .where((final path) => path.isNotEmpty)
      .toList();
  return paths.isEmpty ? null : paths.last;
}

/// `ps -o lstart=` output (`Thu Oct  6 21:04:33 2026`) → local
/// [DateTime]; null when the line is not that shape.
DateTime? parsePsLstart(final String line) {
  final parts = line.trim().split(RegExp(r'\s+'));
  if (parts.length != 5) return null;
  const months = <String, int>{
    'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
    'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
  };
  final month = months[parts[1]];
  final day = int.tryParse(parts[2]);
  final year = int.tryParse(parts[4]);
  final clock = parts[3].split(':');
  if (month == null || day == null || year == null || clock.length != 3) {
    return null;
  }
  final hour = int.tryParse(clock[0]);
  final minute = int.tryParse(clock[1]);
  final second = int.tryParse(clock[2]);
  if (hour == null || minute == null || second == null) return null;
  return DateTime(year, month, day, hour, minute, second);
}

/// True when the on-disk binary is newer than the running process's
/// start (beyond [tolerance] for filesystem timestamp coarseness):
/// attaching would silently test a stale app.
bool buildNewerThanProcess({
  required final DateTime binaryModified,
  required final DateTime processStarted,
  final Duration tolerance = const Duration(seconds: 5),
}) => binaryModified.isAfter(processStarted.add(tolerance));
