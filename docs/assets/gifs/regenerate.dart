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
  // Prebuild canonical showcase web assets before vhs (required for cli-exec tape).
  await _prebuildWeb('$root/showcase/flutter_test_app');
  await _stopShowcaseProcesses(root);
  await _checkDisplayBeforeVhs();

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
  if (!File(script).existsSync()) {
    stderr.writeln('regenerate_cli_gifs: missing $script');
    exit(1);
  }
  await _run('bash', [script]);
  final target = '$root/intentcall';
  final webmcp = '$target/packages/intentcall_webmcp';
  if (!Directory(webmcp).existsSync()) {
    stderr.writeln(
      'regenerate_cli_gifs: intentcall checkout incomplete (expected $webmcp)',
    );
    exit(1);
  }
  final parent = Directory(root).parent.path;
  final link = '$parent/intentcall';
  if (!Link(link).existsSync() && !File(link).existsSync()) {
    final linkResult = await _runProcess(
      'ln',
      ['-snf', target, link],
      allowFailure: true,
    );
    if (linkResult.exitCode != 0) {
      stderr.writeln('regenerate_cli_gifs: could not link $link -> $target');
      exit(linkResult.exitCode);
    }
  }
  // The showcase resolves intentcall through `../intentcall` (path deps). A
  // pre-existing sibling clone is kept as-is above, so verify it is the pinned
  // ref; otherwise the GIFs record (or fail on) an unpinned intentcall.
  final pinned = File('$root/tool/ci/intentcall_ref.txt')
      .readAsStringSync()
      .trim();
  final head = await _runProcess(
    'git',
    ['-C', link, 'rev-parse', 'HEAD'],
    allowFailure: true,
  );
  final actual = head.exitCode == 0 ? head.stdout.toString().trim() : '';
  if (actual != pinned) {
    stderr.writeln(
      'regenerate_cli_gifs: $link is at ${actual.isEmpty ? '(unknown)' : actual}, '
      'but tool/ci/intentcall_ref.txt pins $pinned. Point $link at $target '
      'or check out the pinned ref there, then rerun.',
    );
    exit(1);
  }
  stdout.writeln(
    'regenerate_cli_gifs: intentcall path ok ($link -> $target @ $pinned)',
  );
}

Future<void> _checkDisplayBeforeVhs() async {
  await _checkDisplayReady();
}

Future<void> _prebuildWeb(String appDir) async {
  stdout.writeln('regenerate_cli_gifs: prebuilding $appDir (web)…');
  await _runProcess(
    'flutter',
    ['build', 'web'],
    workingDirectory: appDir,
  );
  stdout.writeln('regenerate_cli_gifs: web prebuild OK ($appDir)');
}

Future<void> _stopShowcaseProcesses(String root) async {
  final killed = await _killRunnerSessionPids(root);
  if (!killed) {
    await _runProcess('pkill', ['-f', 'flutter run.*flutter_test_app'], allowFailure: true);
  }
}

Future<bool> _killRunnerSessionPids(String root) async {
  var any = false;
  for (final rel in ['showcase/flutter_test_app']) {
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
  // vhs output from the tapes above: 2MB budget warning, 5MB hard cap.
  final vhsGifs = <String>[
    '$root/docs/assets/gifs/harness-flutter.gif',
    '$root/docs/assets/gifs/harness-web.gif',
    '$root/docs/assets/gifs/cli-exec.gif',
  ];
  // Manual legacy recording (not produced by this script; restored in #214 and
  // inlined in the README on purpose). Reported, never a hard failure here:
  // regenerating the vhs GIFs cannot change it, so failing on it would make
  // every regeneration run red. Phase 2 `view-screenshots.tape` replaces it.
  final legacyGifs = <String>['$root/docs/view_screenshots.gif'];

  for (final gif in vhsGifs) {
    final file = File(gif);
    final rel = _rel(root, gif);
    if (!file.existsSync()) {
      stderr.writeln('regenerate_cli_gifs: expected vhs output missing: $rel');
      exit(1);
    }
    final size = file.lengthSync();
    stdout.writeln('regenerate_cli_gifs: $rel $size bytes');
    if (size > _warnBudget) {
      stderr.writeln(
        'regenerate_cli_gifs: warning — $rel is $size bytes (budget 2MB)',
      );
    }
    if (size > _hardCap) {
      stderr.writeln(
        'regenerate_cli_gifs: GIF over 5MB cap: $rel ($size bytes)',
      );
      exit(1);
    }
  }
  for (final gif in legacyGifs) {
    final file = File(gif);
    if (!file.existsSync()) continue;
    final size = file.lengthSync();
    final rel = _rel(root, gif);
    if (size > _warnBudget) {
      stderr.writeln(
        'regenerate_cli_gifs: note — legacy manual recording $rel is $size bytes '
        '(over the 2MB budget; not regenerated by vhs, replace via Phase 2 tape)',
      );
    }
  }
}

String _rel(String root, String path) =>
    path.startsWith(root) ? path.substring(root.length + 1) : path;

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

/// Resolves [name] against the child PATH (the one children actually get,
/// including the prepended workspace build dir). Not `bash -lc`: a login shell
/// re-reads /etc/profile, which on Debian resets PATH and hides both the
/// caller's toolchain and the prepended `mcp_server_dart/build`.
Future<String?> _which(String name) async {
  final path = _childEnv['PATH'] ?? '';
  for (final dir in path.split(':')) {
    if (dir.isEmpty) continue;
    final candidate = File('$dir/$name');
    if (!candidate.existsSync()) continue;
    final stat = candidate.statSync();
    if (stat.type == FileSystemEntityType.directory) continue;
    // Any execute bit (owner/group/other).
    if (stat.mode & 0x49 == 0) continue;
    return candidate.path;
  }
  return null;
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
