import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'flutter_app.dart';
import 'log_tap.dart';
import 'vm_service_uri.dart';

/// Owning interactive `flutter run` session (the showcase launch path).
///
/// Unlike [BinaryAppTarget] — a fresh detached binary with no compile
/// channel — this starts the flutter tool itself: it owns the build, the
/// daemon, and hot reload (`r`/`R`/`q` on stdin). It is the *first* owner,
/// so it never competes with another runner (the mcp_flutter ADR-0014
/// failure mode is a *second* attach killing the first session); callers
/// that need an app driven while it runs can pipe stdin through
/// [LaunchedApp.process] and tail [LaunchedApp.stdout].
///
/// The VM service URI is scraped from the tool's own announcement line, so
/// the [VmClient] surface (extension calls, evaluate, reload) works against
/// this session exactly as against a launched binary.
final class FlutterRunTarget implements AppTarget {
  FlutterRunTarget({
    required this.projectDir,
    this.device = 'macos',
    this.extraArgs = const <String>[],
    this.environment = const <String, String>{},
    this.name = 'flutter-run',
    this.flutterBin = 'flutter',
    this.vmServiceTimeout = const Duration(seconds: 180),
    this.onLine,
  });

  final String projectDir;

  /// `-d` device id (`macos`, `chrome`, a serial…).
  final String device;

  /// Extra flutter args (`--web-port=8080`, `--dart-define=…`, browser
  /// flags, …).
  final List<String> extraArgs;

  /// Extra environment entries layered on top of the inherited parent
  /// environment (an empty map inherits unchanged — never a wiped env).
  final Map<String, String> environment;
  final String name;

  /// Override in tests (a fake `flutter` script); defaults to `flutter`.
  final String flutterBin;
  final Duration vmServiceTimeout;

  /// Progress hook: every line the tool emits, including the long stretch
  /// before the VM service announcement resolves [launch] — use it to tee
  /// a first build's output somewhere visible.
  final void Function(String line)? onLine;

  @override
  Future<LaunchedApp> launch({final bool build = true}) async {
    // `flutter run` always builds; the AppTarget flag has nothing to skip.
    final process = await Process.start(
      flutterBin,
      ['run', '-d', device, '--debug', ...extraArgs],
      workingDirectory: projectDir,
      environment: environment.isEmpty
          ? null
          : <String, String>{...Platform.environment, ...environment},
    );
    final tap = LogTap()..add('[$name] flutter run -d $device');
    _pump(process.stdout, tap);
    _pump(process.stderr, tap);
    try {
      final line = await tap.waitFor(
        vmServiceUriPattern,
        timeout: vmServiceTimeout,
      );
      return LaunchedApp(
        name: name,
        process: process,
        stdout: tap,
        vmUri: vmServiceUriFromLine(line)!,
      );
    } on Object {
      // Never leave an owning session behind on a failed bring-up.
      process.kill();
      await process.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          // SIGKILL escalation orphans the tool's own children (the running
          // app) — take them along.
          Process.runSync('pkill', ['-P', '${process.pid}']);
          process.kill(ProcessSignal.sigkill);
          return process.exitCode;
        },
      );
      rethrow;
    }
  }

  void _pump(final Stream<List<int>> stream, final LogTap tap) {
    stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (final line) {
            tap.add(line);
            onLine?.call(line);
          },
          onDone: tap.close,
        );
  }
}
