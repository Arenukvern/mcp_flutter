// Regenerate committed CLI/harness GIFs (vhs). Replaces regenerate_cli_gifs.sh.
//
// Usage (from repo root):
//   dart run docs/assets/gifs/regenerate.dart
//   dart run docs/assets/gifs/regenerate.dart --preflight
library;

import 'dart:convert';
import 'dart:io';

const _warnBudget = 2097152;
const _hardCap = 5242880;

final Map<String, String> _childEnv = Map<String, String>.from(Platform.environment);

Future<void> main(List<String> args) async {
  final preflight = args.contains('--preflight');
  final root = File(Platform.script.toFilePath())
      .parent
      .parent
      .parent
      .parent
      .absolute
      .path;
  final gifsDir = '$root/docs/assets/gifs';
  Directory.current = root;

  if (!preflight) {
    await _requireOnPath('vhs');
  }
  await _requireOnPath('flutter');
  await _compileWorkspaceCli(root);
  _ensureDisplay();

  if (preflight) {
    await _tapePreflight(gifsDir);
    stdout.writeln('regenerate_cli_gifs: preflight OK');
    return;
  }

  await _checkoutIntentcall(root);
  await _prebuildWeb('$root/showcase/flutter_demo');
  await _prebuildWeb('$root/showcase/flutter_test_app');
  await _stopShowcaseProcesses(root);

  for (final tape in ['harness-flutter', 'harness-web', 'cli-exec']) {
    await _run('vhs', ['$gifsDir/$tape.tape']);
  }

  await _enforceGifBudget(root);
  await _run(
    'dart',
    ['run', 'packages/harness/tool/showcase.dart', '--stop'],
    allowFailure: true,
  );
  stdout.writeln('regenerate_cli_gifs: OK');
}

Future<void> _tapePreflight(String gifsDir) async {
  for (final tape in ['harness-flutter', 'harness-web', 'cli-exec']) {
    final path = '$gifsDir/$tape.tape';
    if (!File(path).existsSync()) {
      stderr.writeln('regenerate_cli_gifs: missing tape $path');
      exit(1);
    }
  }
  final cliExec = File('$gifsDir/cli-exec.tape').readAsStringSync();
  if (!cliExec.contains('flutter-mcp-toolkit')) {
    stderr.writeln('regenerate_cli_gifs: cli-exec.tape must invoke flutter-mcp-toolkit');
    exit(1);
  }
  final toolkit = await _which('flutter-mcp-toolkit');
  if (toolkit == null || toolkit.isEmpty) {
    stderr.writeln('regenerate_cli_gifs: flutter-mcp-toolkit not on PATH after compile');
    exit(1);
  }
  stdout.writeln('regenerate_cli_gifs: flutter-mcp-toolkit=$toolkit');
  stdout.writeln('regenerate_cli_gifs: DISPLAY=${_childEnv['DISPLAY'] ?? '(unset)'}');
  stdout.writeln('regenerate_cli_gifs: tapes present (harness-flutter, harness-web, cli-exec)');
}

Future<void> _compileWorkspaceCli(String root) async {
  stdout.writeln('regenerate_cli_gifs: compiling workspace flutter-mcp-toolkit…');
  final build = '$root/mcp_server_dart/build';
  final compile = await _runProcess(
    'make',
    ['compile'],
    workingDirectory: '$root/mcp_server_dart',
    allowFailure: true,
  );
  if (compile.exitCode != 0) {
    final cached = File('$build/flutter-mcp-toolkit');
    if (!cached.existsSync()) {
      stderr.write(compile.stderr);
      stderr.writeln('regenerate_cli_gifs: make compile failed (no cached $build/flutter-mcp-toolkit)');
      exit(compile.exitCode);
    }
    stdout.writeln(
      'regenerate_cli_gifs: make compile failed; reusing cached ${cached.path}',
    );
  }
  _prependPath(build);
  final toolkit = await _which('flutter-mcp-toolkit');
  if (toolkit == null) {
    stderr.writeln('regenerate_cli_gifs: flutter-mcp-toolkit missing after compile');
    exit(1);
  }
  stdout.writeln('regenerate_cli_gifs: resolved flutter-mcp-toolkit=$toolkit');
}

void _ensureDisplay() {
  final display = _childEnv['DISPLAY']?.trim();
  if (display == null || display.isEmpty) {
    _childEnv['DISPLAY'] = ':99';
  }
}

Future<void> _checkDisplayReady() async {
  final display = _childEnv['DISPLAY'] ?? ':99';
  if (await _which('xdpyinfo') == null) return;
  final r = await _runProcess('xdpyinfo', ['-display', display]);
  if (r.exitCode != 0) {
    stderr.writeln('regenerate_cli_gifs: DISPLAY=$display is not ready (start Xvfb)');
    exit(1);
  }
}

Future<void> _checkoutIntentcall(String root) async {
  final script = '$root/tool/ci/checkout_intentcall.sh';
  if (!File(script).existsSync()) return;
  await _checkDisplayReady();
  await _run('bash', [script]);
  final parent = Directory(root).parent.path;
  final link = '$parent/intentcall';
  final target = '$root/intentcall';
  if (!File(target).existsSync()) return;
  if (File(link).existsSync() || Link(link).existsSync()) return;
  try {
    await Link(link).create(target, recursive: true);
  } on Object {
    // intentcall sibling symlink optional on this host
  }
}

Future<void> _prebuildWeb(String appDir) async {
  stdout.writeln('regenerate_cli_gifs: prebuilding $appDir (web)…');
  await _run('flutter', ['build', 'web'], workingDirectory: appDir);
}

Future<void> _stopShowcaseProcesses(String root) async {
  final killed = await _killRunnerSessionPids(root);
  if (!killed) {
    await _runProcess('pkill', ['-f', 'flutter run.*flutter_demo'], allowFailure: true);
    await _runProcess('pkill', ['-f', 'flutter run.*flutter_test_app'], allowFailure: true);
  }
}

Future<bool> _killRunnerSessionPids(String root) async {
  var any = false;
  for (final rel in ['showcase/flutter_test_app', 'showcase/flutter_demo']) {
    final sessionFile = File('$root/$rel/.flutter_mcp/runner-session.json');
    if (!sessionFile.existsSync()) continue;
    try {
      final map = jsonDecode(sessionFile.readAsStringSync()) as Map<String, dynamic>;
      final pid = map['pid'];
      if (pid is! num) continue;
      final processPid = pid.toInt();
      if (processPid <= 0) continue;
      Process.killPid(processPid, ProcessSignal.sigterm);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      try {
        Process.killPid(processPid, ProcessSignal.sigkill);
      } on Object {
        // already exited
      }
      any = true;
      stdout.writeln('regenerate_cli_gifs: stopped runner-session pid=$processPid ($rel)');
    } on Object {
      continue;
    }
  }
  return any;
}

Future<void> _enforceGifBudget(String root) async {
  final committedGifs = <String>[
    '$root/docs/assets/gifs/harness-flutter.gif',
    '$root/docs/assets/gifs/harness-web.gif',
    '$root/docs/assets/gifs/cli-exec.gif',
    '$root/docs/view_screenshots.gif',
  ];
  for (final gif in committedGifs) {
    if (!File(gif).existsSync()) continue;
    final size = File(gif).lengthSync();
    final rel = gif.startsWith(root) ? gif.substring(root.length + 1) : gif;
    if (size > _warnBudget) {
      stderr.writeln('regenerate_cli_gifs: warning — $rel is $size bytes (budget 2MB)');
    }
    if (size > _hardCap) {
      stderr.writeln('regenerate_cli_gifs: GIF over 5MB cap: $rel ($size bytes)');
      exit(1);
    }
  }
}

void _prependPath(String segment) {
  final current = _childEnv['PATH'] ?? '';
  _childEnv['PATH'] = current.isEmpty ? segment : '$segment:$current';
}

Future<void> _requireOnPath(String name) async {
  if (await _which(name) == null) {
    stderr.writeln('$name not on PATH');
    exit(1);
  }
}

Future<String?> _which(String name) async {
  final r = await _runProcess('bash', ['-lc', 'command -v $name']);
  if (r.exitCode != 0) return null;
  return r.stdout.toString().trim();
}

Future<ProcessResult> _runProcess(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  bool allowFailure = false,
}) async {
  final r = await Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: _childEnv,
  );
  if (!allowFailure && r.exitCode != 0) {
    stderr.write(r.stderr);
    stdout.write(r.stdout);
    exit(r.exitCode);
  }
  return r;
}

Future<void> _run(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  bool allowFailure = false,
}) async {
  await _runProcess(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    allowFailure: allowFailure,
  );
}