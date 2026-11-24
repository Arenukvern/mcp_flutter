import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Repo root when tests run from `mcp_server_dart/` (default `dart test` cwd).
Directory showcaseRepoRoot() =>
    Directory('${Directory.current.path}/..').absolute;

/// Kills stray showcase / integration Flutter and MCP server processes.
Future<void> stopShowcaseProcesses() async {
  final root = showcaseRepoRoot();
  await _killRunnerSessionPids(root.path);
  final stop = await Process.run(
    'dart',
    <String>[
      'run',
      '${root.path}/packages/harness/tool/showcase.dart',
      '--stop',
    ],
    workingDirectory: root.path,
  );
  final err = stop.stderr.toString().trim();
  if (err.isNotEmpty) {
  // ignore: avoid_print
    stderr.writeln('[showcase.dart --stop stderr] $err');
  }
  final out = stop.stdout.toString().trim();
  if (out.isNotEmpty) {
  // ignore: avoid_print
    stdout.writeln('[showcase.dart --stop] $out');
  }
}

Future<void> _killRunnerSessionPids(String root) async {
  final sessionFile = File(
    '$root/showcase/flutter_test_app/.flutter_mcp/runner-session.json',
  );
  if (!sessionFile.existsSync()) return;
  try {
    final map = jsonDecode(sessionFile.readAsStringSync()) as Map<String, dynamic>;
    final pid = map['pid'];
    if (pid is! num) return;
    final processPid = pid.toInt();
    if (processPid <= 0) return;
    Process.killPid(processPid, ProcessSignal.sigterm);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    try {
      Process.killPid(processPid, ProcessSignal.sigkill);
    } on Object {
      // already exited
    }
  // ignore: avoid_print
    stdout.writeln('[showcase_cleanup] stopped runner-session pid=$processPid');
  } on Object {
    // unreadable session — showcase.dart --stop still runs
  }
}

/// Waits until [port] is not listening (or [timeout] elapses).
Future<void> waitForPortFree(
  int port, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final probe = await Process.run('bash', <String>[
      '-c',
      'lsof -i :$port >/dev/null 2>&1',
    ]);
    if (probe.exitCode != 0) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
}

/// Graceful `q` then hard kill + [stopShowcaseProcesses].
Future<void> stopLaunchedFlutterProcess(
  Process process, {
  required StreamSubscription<String> stdoutSub,
  required StreamSubscription<String> stderrSub,
}) async {
  try {
    process.stdin.writeln('q');
    await process.exitCode.timeout(const Duration(seconds: 15));
  } on Exception {
    process.kill(ProcessSignal.sigkill);
  }
  await stdoutSub.cancel();
  await stderrSub.cancel();
  await stopShowcaseProcesses();
}
