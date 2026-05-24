import 'dart:async';
import 'dart:io';

/// Repo root when tests run from `mcp_server_dart/` (default `dart test` cwd).
Directory showcaseRepoRoot() =>
    Directory('${Directory.current.path}/..').absolute;

File _stopShowcaseScript() =>
    File('${showcaseRepoRoot().path}/scripts/stop_showcase.sh');

/// Kills stray showcase / integration Flutter and MCP server processes.
Future<void> stopShowcaseProcesses() async {
  final script = _stopShowcaseScript();
  if (!script.existsSync()) {
    return;
  }
  await Process.run('bash', <String>[script.path]);
}

/// Waits until [port] is not listening (or [timeout] elapses).
Future<void> waitForPortFree(
  final int port, {
  final Duration timeout = const Duration(seconds: 30),
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
  final Process process, {
  required final StreamSubscription<String> stdoutSub,
  required final StreamSubscription<String> stderrSub,
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
