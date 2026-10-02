/// The MCP Flutter showcase, as a Dart composition root over
/// `flutter_mcp_harness` (replaces `scripts/run_showcase.sh`,
/// `scripts/run_web_showcase.sh`, and `scripts/stop_showcase.sh`).
///
/// Modes:
///   (none)                macOS showcase, interactive foreground
///   --web [--detach]      Chrome showcase with WebMCP flags
///   --stop                clean stray showcase processes and ports
///
/// This tool only owns bring-up/teardown. The second-terminal IntentCall
/// doors (discover / bridge ping / MCP serve) are
/// `tool/intentcall_session.dart`, which scrapes the VM service URI from
/// the same `.showcase/` logs this tool tees.
///
/// Interactive mode streams the flutter tool's output (also teed to
/// `.showcase/*.log`, which `make exec-sweep` greps), relays your keystrokes
/// (r / R / q), and tears the session down on exit or Ctrl-C.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:path/path.dart' as p;

final String repoRoot = p.normalize(
  p.join(p.dirname(Platform.script.toFilePath()), '..', '..', '..'),
);

final String showcaseDir = p.join(repoRoot, '.showcase');
final String appDir = p.join(repoRoot, 'showcase', 'flutter_test_app');

const String scheme = 'mcpfluttertest';

void log(final String message) {
  // ignore: avoid_print
  print('[showcase] $message');
}

/// exit() skips Dart's stdout flush for redirected output — flush first so
/// failure reasons are never lost.
Future<Never> quit(final int code) async {
  await stdout.flush();
  await stderr.flush();
  exit(code);
}

Future<void> main(final List<String> arguments) async {
  final web = arguments.contains('--web');
  final detach = arguments.contains('--detach');
  final stop = arguments.contains('--stop');
  if (arguments.contains('-h') || arguments.contains('--help')) {
    log('usage: dart run packages/harness/tool/showcase.dart '
        '[--web [--detach] | --stop]');
    await quit(0);
  }
  if (stop) {
    await stopShowcase();
    await quit(0);
  }
  if (web) {
    await webShowcase(detach: detach);
  } else {
    await macosShowcase();
  }
}

// ---------------------------------------------------------------------------
// stop — the stop_showcase.sh equivalent (safe to run repeatedly)
// ---------------------------------------------------------------------------

Future<void> stopShowcase() async {
  log('cleaning showcase/flutter_test_app / MCP showcase processes…');
  final pidFile = File(p.join(showcaseDir, 'flutter.pid'));
  if (pidFile.existsSync()) {
    final savedPid = int.tryParse(pidFile.readAsStringSync().trim());
    if (savedPid != null) {
      Process.killPid(savedPid, ProcessSignal.sigterm);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      Process.killPid(savedPid, ProcessSignal.sigkill);
    }
    pidFile.deleteSync();
  }
  // The detached web session writes its own pid file.
  final webPidFile = File(p.join(showcaseDir, 'web_flutter.pid'));
  if (webPidFile.existsSync()) {
    final webPid = int.tryParse(webPidFile.readAsStringSync().trim());
    if (webPid != null) Process.killPid(webPid, ProcessSignal.sigkill);
    webPidFile.deleteSync();
  }

  // Flutter tool driving this repo's test app.
  await _runIgnoringExitCode(
        'pkill', ['-f', 'flutter run.*showcase/flutter_test_app']);
  await _runIgnoringExitCode('pkill', ['-f', 'flutter_tools.*run.*macos']);

  // macOS showcase GUI (survives parent flutter kill).
  if (Platform.isMacOS) {
    await _runIgnoringExitCode('killall', ['test_app']);
  }

  // Default integration / showcase VM port.
  await _freePort(8181);

  // MCP server binaries spawned by integration tests.
  await _runIgnoringExitCode('pkill', ['-f', 'flutter-mcp-toolkit-server']);
  await _runIgnoringExitCode('pkill', ['-f', 'flutter_mcp_toolkit_server']);
  log('done');
}

Future<void> _freePort(final int port) async {
  if (_which('lsof') == null) return;
  await for (final pid in _pidsOnPort(port)) {
    Process.killPid(pid, ProcessSignal.sigterm);
  }
  await Future<void>.delayed(const Duration(milliseconds: 300));
  await for (final pid in _pidsOnPort(port)) {
    Process.killPid(pid, ProcessSignal.sigkill);
  }
}

Stream<int> _pidsOnPort(final int port) async* {
  final result = await Process.run('lsof', ['-ti', ':$port']);
  for (final token in result.stdout.toString().split(RegExp(r'\s+'))) {
    final pid = int.tryParse(token);
    if (pid != null) yield pid;
  }
}

/// `kill -0` equivalent: does a process with this pid exist?
Future<bool> _pidAlive(final int pid) async {
  final result = await Process.run('kill', ['-0', '$pid']);
  return result.exitCode == 0;
}

Future<void> _runIgnoringExitCode(
  final String executable,
  final List<String> arguments,
) async {
  try {
    await Process.run(executable, arguments);
  } on Object {
    // Missing binary / nothing matched — the stop path is best-effort.
  }
}

String? _which(final String executable) {
  final pathEnv = Platform.environment['PATH'] ?? '';
  for (final dir in pathEnv.split(':')) {
    if (dir.isEmpty) continue;
    final candidate = p.join(dir, executable);
    if (File(candidate).existsSync()) return candidate;
  }
  return null;
}

// ---------------------------------------------------------------------------
// macOS showcase — the run_showcase.sh equivalent
// ---------------------------------------------------------------------------

Future<void> macosShowcase() async {
  await stopShowcase();
  Directory(showcaseDir).createSync(recursive: true);
  final logFile = File(p.join(showcaseDir, 'flutter_app.log'));
  final logSink = logFile.openWrite();
  log('running flutter test app on macOS…');
  log('logs → ${logFile.path}');

  // Tee progress from the first build line; a cold macOS build (pods,
  // kernel compile) can take longer than the default VM-service timeout.
  void tee(final String line) {
    stdout.writeln(line);
    logSink.writeln(line);
  }

  final target = FlutterRunTarget(
    projectDir: appDir,
    device: 'macos',
    vmServiceTimeout: const Duration(minutes: 10),
    onLine: tee,
  );
  final LaunchedApp app;
  try {
    app = await target.launch();
  } on Object catch (error) {
    log('flutter run failed before the VM service appeared: $error');
    await quit(1);
  }
  File(p.join(showcaseDir, 'flutter.pid'))
      .writeAsStringSync('${app.process.pid}');
  log('flutter pid ${app.process.pid}');

  // Keep teeing live session lines (hot reload cycles, app output).
  app.stdout.stream.listen(tee);

  final wsUri = canonicalVmServiceWsUri(app.vmUri);
  stdout.writeln();
  log('Dart VM Service:  ${app.vmUri}');
  log('canonical WS URI: $wsUri');

  final linkFile = File(
    p.join(_homeDir(), '.intentcall', 'links', '$scheme.json'),
  );
  var linkReady = false;
  final linkDeadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(linkDeadline)) {
    if (linkFile.existsSync()) {
      linkReady = true;
      break;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }

  stdout.writeln();
  log(linkReady
      ? 'link record: ${linkFile.path}'
      : 'link record not visible yet at ${linkFile.path}');
  if (!linkReady) {
    log('the app publishes it after the first frame when publishSurfaceLink is on.');
  }
  log('IntentCall doors, second terminal:');
  log('  dart run packages/harness/tool/intentcall_session.dart demo');
  log('  (or serve-link / serve-debug to expose the app over MCP)');
  stdout.writeln();
  log("  export WS='$wsUri'");
  log('  flutter-mcp-toolkit exec --name semantic_snapshot \\');
  log(r'    --args "{\"connection\":{\"targetId\":\"$WS\"}}"');
  stdout.writeln();
  log('app is running. Press r for hot reload, q to quit.');
  log('to stop from another terminal: make showcase-stop');
  stdout.writeln();

  await _relayUntilExit(app, logSink);
}

// ---------------------------------------------------------------------------
// web showcase — the run_web_showcase.sh equivalent
// ---------------------------------------------------------------------------

Future<void> webShowcase({required final bool detach}) async {
  await stopShowcase();
  Directory(showcaseDir).createSync(recursive: true);

  final webPort = Platform.environment['WEB_PORT'] ?? '8080';
  final vmPort = Platform.environment['VM_HOST_PORT'] ?? '8181';
  final route = Platform.environment['FLUTTER_ROUTE'] ?? '';
  final dogfoodVisual = Platform.environment['DOGFOOD_VISUAL'] ?? '';
  final canvaskitUrl = Platform.environment['WEB_CANVASKIT_URL'] ?? '';

  log('Chrome :$webPort with WebMCP flags');
  if (route.isNotEmpty) log('route=$route');
  log('recipe: dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart '
      'webmcp chrome-args');

  final extraArgs = <String>[
    '--web-port=$webPort',
    '--host-vmservice-port=$vmPort',
    if (route.isNotEmpty) '--route=$route',
    if (dogfoodVisual == '1' || dogfoodVisual == 'true')
      '--dart-define=DOGFOOD_VISUAL=true',
    if (canvaskitUrl.isNotEmpty)
      '--dart-define=FLUTTER_WEB_CANVASKIT_URL=$canvaskitUrl'
    else
      '--no-web-resources-cdn',
    '--web-browser-flag=--enable-features=WebModelContext',
    '--web-browser-flag=--enable-experimental-web-platform-features',
  ];

  if (detach) {
    final logFile = File(p.join(showcaseDir, 'web_app.log'));
    // Start the log clean: the session scraper reads the LAST ws
    // announcement, and an appended log would serve the previous
    // session's (dead) endpoint until the new one announces.
    logFile.writeAsStringSync('');
    // Detached children get no stdio, so land the output in the log file
    // the same way the shell script's `nohup … >>log 2>&1 < /dev/null` did.
    final pid = await _spawnDetachedWithLog(
      arguments: ['run', '-d', 'chrome', '--debug', ...extraArgs],
      logPath: logFile.path,
    );
    File(p.join(showcaseDir, 'web_flutter.pid')).writeAsStringSync('$pid');
    log('flutter pid $pid (detached)');

    final ws = await _waitForWsInLogFile(
      logFile,
      requireReadyPattern: true,
      isAlive: () => _pidAlive(pid),
    );
    if (ws == null) {
      log('flutter exited or never published a VM ws URI (180s).');
      await quit(1);
    }
    _printWebReady('$ws', webPort);
    await quit(0);
  }

  final logFile = File(p.join(showcaseDir, 'web_app.log'));
  final logSink = logFile.openWrite();
  void tee(final String line) {
    stdout.writeln(line);
    logSink.writeln(line);
  }

  final target = FlutterRunTarget(
    projectDir: appDir,
    device: 'chrome',
    extraArgs: extraArgs,
    vmServiceTimeout: const Duration(minutes: 10),
    onLine: tee,
  );
  final LaunchedApp app;
  try {
    app = await target.launch();
  } on Object catch (error) {
    log('flutter run -d chrome failed before the VM service appeared: $error');
    await quit(1);
  }
  File(p.join(showcaseDir, 'web_flutter.pid'))
      .writeAsStringSync('${app.process.pid}');

  app.stdout.stream.listen(tee);

  _printWebReady('${canonicalVmServiceWsUri(app.vmUri)}', webPort);
  await _relayUntilExit(app, logSink);
}

void _printWebReady(final String wsUri, final String webPort) {
  stdout.writeln();
  log('WS_URI=$wsUri');
  log('verify: dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart '
      'webmcp verify --web-port $webPort');
  log('stop: make showcase-stop');
}

// ---------------------------------------------------------------------------
// shared interactive plumbing
// ---------------------------------------------------------------------------

/// Streams the tool's stdin into the flutter process (r / R / q) and waits
/// for the session to end; Ctrl-C and normal exit both tear the session
/// down (the shell script's `trap … EXIT INT TERM` semantics).
Future<void> _relayUntilExit(
  final LaunchedApp app,
  final IOSink logSink,
) async {
  ProcessSignal.sigint.watch().listen((final _) {
    log('interrupted — stopping showcase session…');
    stopShowcase().whenComplete(() => quit(130));
  });

  stdin.listen(
    (final chunk) => app.process.stdin.add(chunk),
    onDone: () {
      // EOF on stdin (backgrounded tool): quit the app cleanly.
      app.process.stdin.write('q');
    },
  );

  final code = await app.process.exitCode;
  await stopShowcase();
  await logSink.flush();
  await logSink.close();
  log('log retained under $showcaseDir');
  await quit(code);
}

Future<int> _spawnDetachedWithLog({
  required final List<String> arguments,
  required final String logPath,
}) async {
  final quoted = [
    'flutter',
    ...arguments,
  ].map((final part) => "'${part.replaceAll("'", r"'\''")}'").join(' ');
  final script = "exec $quoted >> '$logPath' 2>&1 < /dev/null";
  final process = await Process.start(
    'sh',
    ['-c', script],
    workingDirectory: appDir,
    mode: ProcessStartMode.detached,
  );
  return process.pid;
}

Future<Uri?> _waitForWsInLogFile(
  final File logFile, {
  required final bool requireReadyPattern,
  required final Future<bool> Function() isAlive,
}) async {
  const readyPattern = 'Flutter run key commands';
  final deadline = DateTime.now().add(const Duration(seconds: 180));
  while (DateTime.now().isBefore(deadline)) {
    if (!await isAlive()) return null;
    if (logFile.existsSync()) {
      final content = logFile.readAsStringSync();
      final ws = lastVmServiceWsUriIn(content);
      if (ws != null && (!requireReadyPattern || content.contains(readyPattern))) {
        return ws;
      }
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  return null;
}

// ---------------------------------------------------------------------------
// intentcall glue
// ---------------------------------------------------------------------------

String _homeDir() =>
    Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '~';
