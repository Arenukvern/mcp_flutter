import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'log_tap.dart';
import 'vm_client.dart';
import 'vm_service_uri.dart';

/// How the app is brought up. Owns build + launch + VM attach.
abstract interface class AppTarget {
  Future<LaunchedApp> launch({final bool build = true});
}

/// A running app process with its stdout tap and VM handle.
///
/// [AppTarget] implementations construct this; external bring-up (e.g. a
/// device dev session owned by a build tool) constructs it directly around
/// the owning process, with [onStop] carrying extra teardown.
final class LaunchedApp {
  LaunchedApp({
    required this.name,
    required this.process,
    required this.stdout,
    required this.vmUri,
    this.onStop,
  });

  final String name;
  final Process process;
  final LogTap stdout;
  final Uri vmUri;

  /// Extra teardown run by [stop] after the process has been signalled
  /// (best-effort: errors are swallowed so cleanup always finishes).
  final Future<void> Function()? onStop;

  VmClient? _vm;

  Future<VmClient> vm() async => _vm ??= await VmClient.connect(vmUri);

  Future<int> stop() async {
    await stdout.close();
    process.kill(ProcessSignal.sigterm);
    final code = await process.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        // SIGKILL escalation orphans the tool's own children (the running
        // app) — take them along.
        Process.runSync('pkill', ['-P', '${process.pid}']);
        process.kill(ProcessSignal.sigkill);
        return process.exitCode;
      },
    );
    await onStop?.call().catchError((final _) {});
    return code;
  }
}

/// Fresh-session bring-up for a directly launched debug binary.
///
/// Optionally runs [buildCommand] in [projectDir] (a plain full build —
/// not an owning `flutter run`/`flutter attach` session, so this never
/// competes with a dev runner over reload/compile), starts [binaryPath],
/// scrapes the VM service URI from the child's own stdout, and returns the
/// attached [LaunchedApp].
///
/// Subclasses pin the platform build command (see [MacosAppTarget]);
/// Android/iOS device targets live with their tooling (see `oka_harness`),
/// which delegates to the owning dev session and picks the VM URI up from
/// the runner-session contract instead of stdout scraping.
base class BinaryAppTarget implements AppTarget {
  BinaryAppTarget({
    required this.projectDir,
    required this.binaryPath,
    this.buildCommand = const <String>[],
    this.binaryArgs = const <String>[],
    this.environment = const <String, String>{},
    this.name = 'app',
    this.vmServiceTimeout = const Duration(seconds: 60),
  });

  final String projectDir;
  final String binaryPath;
  final List<String> binaryArgs;

  /// Full build command run before launch when `launch(build: true)`.
  /// Empty means "never build here" (reuse an existing binary).
  final List<String> buildCommand;

  /// Extra environment entries layered on top of the inherited parent
  /// environment (an empty map inherits unchanged — never a wiped env).
  final Map<String, String> environment;
  final String name;
  final Duration vmServiceTimeout;

  @override
  Future<LaunchedApp> launch({final bool build = true}) async {
    final env = _layeredEnvironment(environment);
    if (build && buildCommand.isNotEmpty) {
      final buildResult = await Process.run(
        buildCommand.first,
        buildCommand.sublist(1),
        workingDirectory: projectDir,
        environment: env,
        runInShell: true,
      );
      if (buildResult.exitCode != 0) {
        throw StateError(
          '${buildCommand.join(' ')} failed (${buildResult.exitCode}):\n'
          '${buildResult.stderr}',
        );
      }
    }
    final process = await Process.start(
      binaryPath,
      binaryArgs,
      workingDirectory: projectDir,
      environment: env,
    );
    final tap = LogTap()..add('[$name] launched ${binaryPath.split('/').last}');
    _pump(process.stdout, tap);
    _pump(process.stderr, tap);
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
  }

  void _pump(final Stream<List<int>> stream, final LogTap tap) {
    stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(tap.add, onDone: tap.close);
  }
}

/// Layers [extra] over the parent environment; `null` means "inherit
/// unchanged" for dart:io (an empty map would wipe the child's env).
Map<String, String>? _layeredEnvironment(final Map<String, String> extra) =>
    extra.isEmpty ? null : <String, String>{...Platform.environment, ...extra};

/// macOS debug app: `flutter build macos --debug` then launch the binary
/// directly (flutter run's kernel-service path is flaky under automation).
final class MacosAppTarget extends BinaryAppTarget {
  MacosAppTarget({
    required super.projectDir,
    required super.binaryPath,
    super.environment,
    super.name = 'macos-app',
  }) : super(buildCommand: const ['flutter', 'build', 'macos', '--debug']);
}

/// Windows debug app: `flutter build windows --debug` then launch the exe.
final class WindowsAppTarget extends BinaryAppTarget {
  WindowsAppTarget({
    required super.projectDir,
    required super.binaryPath,
    super.environment,
    super.name = 'windows-app',
  }) : super(buildCommand: const ['flutter', 'build', 'windows', '--debug']);
}
