// Regenerate committed CLI/harness GIFs (vhs). Replaces regenerate_cli_gifs.sh.
//
// Usage (from repo root):
//   dart run docs/assets/gifs/regenerate.dart
library;

import 'dart:io';

const _warnBudget = 2097152;
const _hardCap = 5242880;

Future<void> main(List<String> args) async {
  final root = File(Platform.script.toFilePath())
      .parent
      .parent
      .parent
      .parent
      .absolute
      .path;
  final gifsDir = '$root/docs/assets/gifs';
  Directory.current = root;

  await _requireOnPath('vhs');
  await _requireOnPath('flutter');
  await _compileWorkspaceCli(root);
  await _checkDisplay();
  await _checkoutIntentcall(root);
  await _prebuildWeb('$root/showcase/flutter_demo');
  await _prebuildWeb('$root/showcase/flutter_test_app');
  await _stopShowcaseProcesses();

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

Future<void> _compileWorkspaceCli(String root) async {
  stdout.writeln('regenerate_cli_gifs: compiling workspace flutter-mcp-toolkit…');
  await _run('make', ['compile'], workingDirectory: '$root/mcp_server_dart');
  final build = '$root/mcp_server_dart/build';
  Platform.environment['PATH'] =
      '$build:${Platform.environment['HOME']}/.local/bin:${Platform.environment['PATH'] ?? ''}';
  if (await _which('flutter-mcp-toolkit') == null) {
    stderr.writeln('regenerate_cli_gifs: flutter-mcp-toolkit missing after compile');
    exit(1);
  }
}

Future<void> _checkDisplay() async {
  final display = Platform.environment['DISPLAY'] ?? ':99';
  Platform.environment['DISPLAY'] = display;
  if (await _which('xdpyinfo') == null) return;
  final r = await Process.run('xdpyinfo', ['-display', display]);
  if (r.exitCode != 0) {
    stderr.writeln('regenerate_cli_gifs: DISPLAY=$display is not ready (start Xvfb)');
    exit(1);
  }
}

Future<void> _checkoutIntentcall(String root) async {
  final script = '$root/tool/ci/checkout_intentcall.sh';
  if (!File(script).existsSync()) return;
  await _run('bash', [script]);
  final parent = Directory(root).parent.path;
  final link = '$parent/intentcall';
  final target = '$root/intentcall';
  if (!File(target).existsSync()) return;
  if (File(link).existsSync() || Link(link).existsSync()) return;
  if (Link.isLinkSupported()) {
    await Link(link).create(target, recursive: true);
  }
}

Future<void> _prebuildWeb(String appDir) async {
  stdout.writeln('regenerate_cli_gifs: prebuilding $appDir (web)…');
  await _run('flutter', ['build', 'web'], workingDirectory: appDir);
}

Future<void> _stopShowcaseProcesses() async {
  await Process.run('pkill', ['-f', 'flutter run.*flutter_demo']);
  await Process.run('pkill', ['-f', 'flutter run.*flutter_test_app']);
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

Future<void> _requireOnPath(String name) async {
  if (await _which(name) == null) {
    stderr.writeln('$name not on PATH');
    exit(1);
  }
}

Future<String?> _which(String name) async {
  final r = await Process.run('bash', ['-lc', 'command -v $name']);
  if (r.exitCode != 0) return null;
  return (r.stdout as String).trim();
}

Future<void> _run(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  bool allowFailure = false,
}) async {
  final r = await Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: Platform.environment,
  );
  if (!allowFailure && r.exitCode != 0) {
    stderr.write(r.stderr);
    stdout.write(r.stdout);
    exit(r.exitCode);
  }
}