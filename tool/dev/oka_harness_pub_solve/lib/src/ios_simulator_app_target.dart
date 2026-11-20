import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:oka_android/oka_android.dart';

/// Brings an iOS-SIMULATOR app up through an owning `flutter run` session
/// that publishes the SAME runner-session contract `oka dev` publishes
/// (`.flutter_mcp/runner-session.json`, mcp_flutter ADR-0014 spec v2; the
/// file's absence is the liveness signal).
///
/// Why `flutter run` and not an oka runner: oka's owning dev sessions are
/// Android/adb today — no iOS runner exists. A simulator needs no port
/// forwarding (its VM service is host-reachable), so the deterministic
/// source is the owning tool's own VM announcement, read from the process
/// THIS target starts (never a second attach — that is the bug class
/// ADR-0014 removed). The URI is then republished into the contract file
/// so attach-only consumers (`driverForLiveSession`,
/// `RunnerSessionProvider`) work unchanged across platforms.
///
/// `control_port` is published as 0: there is no oka control server here;
/// consumers check file presence (the primary signal) and the VM endpoint.
final class IosSimulatorAppTarget implements AppTarget {
  IosSimulatorAppTarget({
    required this.projectDir,
    required this.udid,
    this.dartDefines = const <String, String>{},
    this.flutterBin = 'flutter',
    this.name = 'ios-sim-app',
    this.vmServiceTimeout = const Duration(minutes: 10),
  });

  /// Flutter project directory (the runner-session file is published under
  /// `<projectDir>/.flutter_mcp/`).
  final String projectDir;

  /// Simulator UDID (`xcrun simctl list devices booted`); threaded to
  /// `flutter run -d`.
  final String udid;

  /// Passed to `flutter run` as `--dart-define` pairs (app config per oka
  /// ADR-0014's three-tier secrets model — defines carry app config, never
  /// host secrets).
  final Map<String, String> dartDefines;

  /// Override in tests (a fake `flutter` script); defaults to `flutter`.
  final String flutterBin;
  final String name;
  final Duration vmServiceTimeout;

  @override
  Future<LaunchedApp> launch({bool build = true}) async {
    if (!build) {
      throw ArgumentError(
        'IosSimulatorAppTarget always builds through its owning `flutter '
        'run`; to observe an already-running session use '
        'readRunnerSessionFile(projectDir) + VmClient.connect() instead of '
        'launching a second owner.',
      );
    }
    // A stale file would look like a live session; the runner deletes it on
    // exit, so anything left is debris (crash, SIGKILL).
    await clearRunnerSessionFile(projectDir);

    final args = <String>[
      'run',
      '-d',
      udid,
      '--debug',
      for (final entry in dartDefines.entries)
        ...['--dart-define', '${entry.key}=${entry.value}'],
    ];
    // Omitting `environment` inherits the parent unchanged (an explicit
    // empty map would wipe it — dart:io semantics), keeping oka's PATH
    // lookups for adb/flutter working.
    final process = await Process.start(
      flutterBin,
      args,
      workingDirectory: projectDir,
    );
    final tap = LogTap()..add('[$name] flutter run -d $udid');
    _pump(process.stdout, tap);
    _pump(process.stderr, tap);
    try {
      String line;
      try {
        line = await tap.waitFor(
          vmServiceUriPattern,
          timeout: vmServiceTimeout,
        );
      } on Object {
        // The owning session's own words are the diagnosis: a lock wait,
        // a failed Xcode build, an early exit — whatever kept the VM
        // service from ever being announced.
        throw StateError(
          'flutter run -d $udid announced no VM service within '
          '$vmServiceTimeout; session tail:\n'
          '${tap.tail(15).join('\n')}',
        );
      }
      final uri = vmServiceUriFromLine(line)!;
      await const FileDevDiscoveryStore().writeRunnerSession(
        projectDir,
        vmServiceUri: '$uri',
        controlPort: 0,
        deviceId: udid,
        processPid: process.pid,
      );
      return LaunchedApp(
        name: name,
        process: process,
        stdout: tap,
        vmUri: uri,
        onStop: () async {
          await clearRunnerSessionFile(projectDir);
        },
      );
    } on Object {
      // Never leave an owning session behind on a failed bring-up.
      process.kill();
      rethrow;
    }
  }

  void _pump(Stream<List<int>> stream, LogTap tap) {
    stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(tap.add, onDone: tap.close);
  }
}
