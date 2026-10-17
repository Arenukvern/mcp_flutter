import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'app_ownership.dart';
import 'log_tap.dart';
import 'vm_client.dart';
import 'vm_service_uri.dart';

/// How the app is brought up. Owns build + launch + VM attach.
abstract interface class AppTarget {
  Future<LaunchedApp> launch({bool build = true});
}

/// A running app process with its stdout tap and VM handle — or, in
/// attach-only ownership, a borrowed lease on a process this tool does
/// NOT own ([process] is null and [stop] is a no-op).
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
    this.fingerprint,
  }) : ownership = AppOwnership.launchAndOwn;

  /// Attached bring-up: the app was already running and the harness only
  /// borrows it. [stop] never signals the process — the owner keeps full
  /// control; [fingerprint] carries the verified build identity.
  LaunchedApp.attached({
    required this.name,
    required this.stdout,
    required this.vmUri,
    this.fingerprint,
  }) : process = null,
       onStop = null,
       ownership = AppOwnership.attachOnly;

  final String name;

  /// Null in attach-only ownership: the harness never held the process.
  final Process? process;
  final LogTap stdout;
  final Uri vmUri;

  /// The verified build identity (attach-only carries the fingerprint it
  /// checked; owned launches can record what was launched).
  final BuildFingerprint? fingerprint;

  /// How this app relates to the process: owned (stop ends it) or
  /// attached (stop never touches it).
  final AppOwnership ownership;

  /// Extra teardown run by [stop] after the process has been signalled
  /// (best-effort: errors are swallowed so cleanup always finishes).
  final Future<void> Function()? onStop;

  VmClient? _vm;

  Future<VmClient> vm() async => _vm ??= await VmClient.connect(vmUri);

  Future<int> stop() async {
    await stdout.close();
    final process = this.process;
    // Attach-only: the process belongs to someone else — never stop it.
    if (process == null) return 0;
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
    await onStop?.call().catchError((_) {});
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
/// **App ownership is a first-class choice** ([AppOwnership]):
/// [AppOwnership.launchAndOwn] (the default) builds, launches, and stops
/// the app. [AppOwnership.attachOnly] instead borrows an
/// already-running process: it discovers the pid by binary name (or
/// takes [attachPid]), verifies the running executable against
/// [binaryPath] and the on-disk build against the running process's
/// start time (plus [expectedFingerprint] when pinned), attaches through
/// [vmServiceUri], and NEVER stops the process — a scenario run ends
/// with the owner's session exactly as it found it.
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
    this.ownership = AppOwnership.launchAndOwn,
    this.attachPid,
    this.vmServiceUri,
    this.expectedFingerprint,
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

  /// Launch-and-own (default) or attach-only (see [AppOwnership]).
  final AppOwnership ownership;

  /// Explicit pid for [AppOwnership.attachOnly]; null discovers by
  /// binary name (exactly one match required — several is an error
  /// naming the pids, not a silent pick).
  final int? attachPid;

  /// The running app's VM service (`http://…/#authToken=…`), required
  /// for [AppOwnership.attachOnly]: a process this tool did not launch
  /// has no stdout to scrape — the URI can only be named, by the
  /// session that owns the app.
  final Uri? vmServiceUri;

  /// Optional exact build pin for [AppOwnership.attachOnly]: recorded
  /// right after building (or carried from the scenario's setup), attach
  /// refuses unless the on-disk binary is still exactly this build.
  final BuildFingerprint? expectedFingerprint;

  @override
  Future<LaunchedApp> launch({bool build = true}) async {
    if (ownership == AppOwnership.attachOnly) {
      // Attach never builds: it does not own bring-up, and rebuilding
      // would break the identity between the on-disk binary and the
      // running process the fingerprint check just verified.
      return _attach();
    }
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

  void _pump(Stream<List<int>> stream, LogTap tap) {
    stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(tap.add, onDone: tap.close);
  }

  /// Attach-only bring-up: find the running process, verify it is the
  /// build under test, never touch its lifecycle. Throws with named
  /// data on every mismatch — a stale or wrong app must fail loudly,
  /// not quietly pass as the build under test.
  Future<LaunchedApp> _attach() async {
    final uri = vmServiceUri;
    if (uri == null) {
      throw StateError(
        '$name: attachOnly needs vmServiceUri — a process this tool did '
        'not launch has no stdout to scrape, so its VM service can only '
        'be named by the session that owns it.',
      );
    }
    final pid = attachPid ?? await _discoverPid();
    await _verifyRunningBinary(pid);
    final fingerprint = await BuildFingerprint.of(binaryPath);
    final tap = LogTap()
      ..add(
        '[$name] attached to pid $pid — ${AppOwnership.attachOnly.name}, '
        'lifecycle untouched; build: $fingerprint',
      );
    return LaunchedApp.attached(
      name: name,
      stdout: tap,
      vmUri: uri,
      fingerprint: fingerprint,
    );
  }

  /// One running process whose command line carries the binary name.
  /// This tool's own pid is excluded (a scenario's argv can contain the
  /// path it is about to attach to).
  Future<int> _discoverPid() async {
    final binaryName = binaryPath.split('/').last;
    final probe = await Process.run('pgrep', <String>['-f', binaryName]);
    final pids = parsePgrepPids(probe.stdout as String)
        .where((candidate) => candidate != pid)
        .toList();
    if (pids.isEmpty) {
      throw StateError(
        '$name: attachOnly found no running "$binaryName" '
        '(pgrep exit ${probe.exitCode}). Start it first, or use the '
        'default launchAndOwn ownership.',
      );
    }
    if (pids.length > 1) {
      throw StateError(
        '$name: attachOnly found ${pids.length} processes matching '
        '"$binaryName" ($pids) — pass attachPid to disambiguate.',
      );
    }
    return pids.single;
  }

  /// The running process must BE the on-disk binary, and the on-disk
  /// binary must not be newer than the process (a rebuild after launch
  /// means the running app is stale). An [expectedFingerprint] pin adds
  /// the exact-build check on top.
  Future<void> _verifyRunningBinary(int pid) async {
    final exe = await Process.run('lsof', <String>[
      '-a',
      '-p',
      '$pid',
      '-d',
      'txt',
      '-Fn',
    ]);
    final exePath = parseLsofExecutablePath(exe.stdout as String);
    if (exePath == null || !_sameFile(exePath, binaryPath)) {
      throw StateError(
        '$name: pid $pid is not $binaryPath — it runs '
        '${exePath ?? '<unresolvable>'}. Refusing to attach: the '
        'scenario would drive an app other than the build under test.',
      );
    }
    final started = parsePsLstart(
      (await Process.run('ps', <String>['-o', 'lstart=', '-p', '$pid']))
          .stdout as String,
    );
    final modified = (await File(binaryPath).stat()).modified;
    if (started != null &&
        buildNewerThanProcess(
          binaryModified: modified,
          processStarted: started,
        )) {
      throw StateError(
        '$name: the on-disk build at $binaryPath is newer than running '
        'pid $pid (rebuilt $modified, process started $started) — '
        'attaching would silently test a stale app. Retire the old '
        'process with its owner, or relaunch under launchAndOwn.',
      );
    }
    final expected = expectedFingerprint;
    if (expected != null) {
      final current = await BuildFingerprint.of(binaryPath);
      if (!current.sameBuildAs(expected)) {
        throw StateError(
          '$name: the on-disk build does not match the expected '
          'fingerprint — expected $expected, found $current. The build '
          'under test changed since the pin was recorded.',
        );
      }
    }
  }

  /// Path equality that survives symlink and macOS `/private` prefix
  /// differences (lsof reports the path the process opened; the target
  /// may name the logical one).
  bool _sameFile(String a, String b) {
    if (a == b) return true;
    try {
      return File(a).resolveSymbolicLinksSync() ==
          File(b).resolveSymbolicLinksSync();
    } on FileSystemException {
      return false;
    }
  }
}

/// Layers [extra] over the parent environment; `null` means "inherit
/// unchanged" for dart:io (an empty map would wipe the child's env).
Map<String, String>? _layeredEnvironment(Map<String, String> extra) =>
    extra.isEmpty ? null : <String, String>{...Platform.environment, ...extra};

/// macOS debug app: `flutter build macos --debug` then launch the binary
/// directly (flutter run's kernel-service path is flaky under automation).
final class MacosAppTarget extends BinaryAppTarget {
  MacosAppTarget({
    required super.projectDir,
    required super.binaryPath,
    super.environment,
    super.name = 'macos-app',
    super.ownership,
    super.attachPid,
    super.vmServiceUri,
    super.expectedFingerprint,
  }) : super(buildCommand: const ['flutter', 'build', 'macos', '--debug']);
}

/// Windows debug app: `flutter build windows --debug` then launch the exe.
final class WindowsAppTarget extends BinaryAppTarget {
  WindowsAppTarget({
    required super.projectDir,
    required super.binaryPath,
    super.environment,
    super.name = 'windows-app',
    super.ownership,
    super.attachPid,
    super.vmServiceUri,
    super.expectedFingerprint,
  }) : super(buildCommand: const ['flutter', 'build', 'windows', '--debug']);
}
