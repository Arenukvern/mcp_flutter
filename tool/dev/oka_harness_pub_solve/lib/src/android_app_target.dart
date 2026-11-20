import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:oka_android/oka_android.dart';

import 'session_composition.dart';

/// Brings an Android app up through oka's owning dev session.
///
/// `oka dev` is the single owning attach session (build → install → launch
/// → VM-service forward → attach, oka ADR-0011): it compiles, owns the
/// daemon protocol, and publishes the forwarded host-reachable VM endpoint
/// in `<project>/.flutter_mcp/runner-session.json` (mcp_flutter ADR-0014
/// spec v2; absence of the file is the liveness signal). This target spawns
/// it, waits for the file, and returns a [LaunchedApp] around the `oka dev`
/// process — no second attach (which would kill the owning session), no
/// logcat-scraped VM URI guessing.
///
/// App logs under automation surface through adb logcat streamed into the
/// same [LaunchedApp.stdout] tap (prefixed `[logcat] `), so log-based
/// assertions work the same as on desktop targets.
final class AndroidAppTarget implements AppTarget {
  AndroidAppTarget({
    required this.projectDir,
    this.deviceId,
    this.dartDefines = const <String, String>{},
    this.environment = const <String, String>{},
    this.name = 'android-app',
    this.okaBin = 'oka',
    this.logcat = true,
    this.sessionTimeout = const Duration(minutes: 5),
  });

  /// Flutter project directory (oka runs against it and the runner-session
  /// file is read from `<projectDir>/.flutter_mcp/`).
  final String projectDir;

  /// Device serial. Required on multi-device hosts (phone + emulator);
  /// threaded to `oka dev --device`.
  final String? deviceId;

  /// Passed to `oka dev` as `--dart-define` pairs (app config per oka
  /// ADR-0014's three-tier secrets model — defines carry app config, never
  /// host secrets).
  final Map<String, String> dartDefines;
  final Map<String, String> environment;
  final String name;

  /// Override in tests (a fake `oka` script); defaults to `oka` on PATH.
  final String okaBin;
  final bool logcat;
  final Duration sessionTimeout;

  @override
  Future<LaunchedApp> launch({bool build = true}) async {
    // A stale file would look like a live session; the runner deletes it on
    // exit, so anything left is debris (crash, SIGKILL).
    await clearRunnerSessionFile(projectDir);

    final defineArgs = [
      for (final entry in dartDefines.entries) ...[
        '--dart-define',
        '${entry.key}=${entry.value}',
      ],
    ];
    final tap = LogTap();
    if (build) {
      // The dev session validates its flags against the manifest recorded
      // by `oka build apk --debug` (ADR-0011 H1) — dart-defines included.
      // A define the build never recorded is a refusal at attach time, so
      // the target owns the build, cache-aware (unchanged steps reuse
      // artifacts; typically seconds after the first cold build).
      tap.add('[$name] $okaBin build apk --debug ${defineArgs.join(' ')}');
      final buildProcess = await Process.run(
        okaBin,
        ['build', 'apk', '--debug', ...defineArgs],
        workingDirectory: projectDir,
        environment: environment.isEmpty
            ? null
            : <String, String>{...Platform.environment, ...environment},
        runInShell: true,
      );
      if (buildProcess.exitCode != 0) {
        throw StateError(
          'oka build apk --debug failed (${buildProcess.exitCode}):\n'
          '${buildProcess.stdout}\n${buildProcess.stderr}',
        );
      }
    }

    final args = <String>[
      'dev',
      if (deviceId != null) ...['--device', deviceId!],
      ...defineArgs,
    ];
    final process = await Process.start(
      okaBin,
      args,
      workingDirectory: projectDir,
      // Layer on the parent environment; an empty map means "inherit
      // unchanged" (dart:io wipes the child env for an explicit empty map,
      // which would break oka's PATH lookups for adb/flutter).
      environment: environment.isEmpty
          ? null
          : <String, String>{...Platform.environment, ...environment},
    );
    tap.add('[$name] $okaBin ${args.join(' ')}');
    _pump(process.stdout, tap);
    _pump(process.stderr, tap);

    Process? logcatProcess;
    try {
      final session = await _waitForSession(process, tap);
      if (logcat) {
        logcatProcess = await _startLogcat(session.deviceId, tap);
      }
      return LaunchedApp(
        name: name,
        process: process,
        stdout: tap,
        vmUri: Uri.parse(session.vmServiceUri),
        onStop: () async {
          logcatProcess?.kill();
        },
      );
    } on Object {
      // Never leave an owning session behind on a failed bring-up.
      process.kill();
      rethrow;
    }
  }

  Future<DevSessionDiscovery> _waitForSession(
    Process process,
    LogTap tap,
  ) async {
    final deadline = DateTime.now().add(sessionTimeout);
    while (DateTime.now().isBefore(deadline)) {
      final DevSessionDiscovery? session;
      try {
        session = readRunnerSessionFile(projectDir);
      } on FormatException {
        // A torn or half-published file is "not ready yet" while the
        // deadline holds — the writer may be mid-publish. The deadline
        // surfaces the real content instead.
        await Future<void>.delayed(const Duration(milliseconds: 500));
        continue;
      }
      if (session != null) return session;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    throw TimeoutException(
      'oka dev did not publish .flutter_mcp/runner-session.json within '
      '$sessionTimeout; session tail:\n${tap.tail(15).join('\n')}',
    );
  }

  Future<Process?> _startLogcat(String deviceId, LogTap tap) async {
    try {
      final process = await Process.start('adb', [
        '-s',
        deviceId,
        'logcat',
        '-T',
        '1',
      ]);
      _pump(process.stdout, tap, prefix: '[logcat] ');
      _pump(process.stderr, tap, prefix: '[logcat] ');
      return process;
    } on Object {
      // adb unavailable: log assertions fall back to `oka dev` stdout only.
      return null;
    }
  }

  void _pump(
    Stream<List<int>> stream,
    LogTap tap, {
    String prefix = '',
  }) {
    stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          prefix.isEmpty ? tap.add : (line) => tap.add('$prefix$line'),
          onDone: tap.close,
        );
  }
}

/// Convenience: attach a [ToolkitDriver] to the live session's VM service.
///
/// Refuses to launch anything — the runner owns the session; this only
/// reads its published endpoint, through the contract-typed path
/// ([resolveLiveSessionOutputs]).
Future<ToolkitDriver> driverForLiveSession(String projectDir) async {
  final outputs = await resolveLiveSessionOutputs(projectDir);
  return ToolkitDriver(
    await VmClient.connect(Uri.parse(outputs.require(runnerSessionVmUri))),
  );
}
