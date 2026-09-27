/// IntentCall doors for a running MCP Flutter showcase, as a checked-in Dart
/// composition root (replaces the former runtime-generated
/// `.showcase/intentcall_examples.sh`).
///
/// The macOS/web showcase (`tool/showcase.dart`) only *launches* the app and
/// prints its VM service URI; this tool is the second-terminal half. It
/// resolves the target VM from `--vm-service-uri` or by scraping the
/// showcase log (fresh token wins — a hot restart re-announces), and the
/// IntentCall CLI from `INTENTCALL_ROOT`, a sibling checkout, or `PATH`.
///
/// Modes (mirrors the app's published link, scheme
/// `mcpfluttertest` — `flutter_test_app/lib/intentcall_showcase_entries.dart`):
///   demo                 discover the link + call app_intentcall_bridge_ping
///   serve-link           `intentcall mcp serve --scheme` (production door)
///   serve-debug          same, pinned to this showcase's VM service
///
/// Usage:
///   dart run packages/harness/tool/intentcall_session.dart
///       [demo|serve-link|serve-debug]
///       [--vm-service-uri ws://127.0.0.1:PORT/TOKEN/ws]
///       [--log .showcase/flutter_app.log] [--web] [--scheme mcpfluttertest]
library;

import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:path/path.dart' as p;

const String defaultScheme = 'mcpfluttertest';

final String repoRoot = p.normalize(
  p.join(p.dirname(Platform.script.toFilePath()), '..', '..', '..'),
);

final String showcaseDir = p.join(repoRoot, '.showcase');

void log(final String message) {
  // ignore: avoid_print
  print('[intentcall-session] $message');
}

Future<Never> quit(final int code) async {
  await stdout.flush();
  await stderr.flush();
  exit(code);
}

Future<void> main(final List<String> arguments) async {
  const modes = <String>['demo', 'serve-link', 'serve-debug'];
  var mode = 'demo';
  String? explicitUri;
  var scheme = defaultScheme;
  String? logPath;
  for (var i = 0; i < arguments.length; i++) {
    final arg = arguments[i];
    switch (arg) {
      case '-h' || '--help':
        _printUsage();
        await quit(0);
      case '--vm-service-uri' when i + 1 < arguments.length:
        explicitUri = arguments[++i];
      case '--log' when i + 1 < arguments.length:
        logPath = arguments[++i];
      case '--scheme' when i + 1 < arguments.length:
        scheme = arguments[++i];
      case '--web':
        logPath ??= p.join(showcaseDir, 'web_app.log');
      case _ when modes.contains(arg):
        mode = arg;
      default:
        stderr.writeln('unknown argument: $arg');
        _printUsage();
        await quit(64);
    }
  }

  final wsUri = await _resolveWsUri(explicit: explicitUri, logPath: logPath);
  if (wsUri == null) {
    stderr.writeln(
      'no VM service URI. Pass --vm-service-uri, or start the showcase '
      'first (make showcase / make web-showcase) so the log exists.',
    );
    await quit(64);
  }
  final intentcall = IntentcallCommand.resolve();
  log('mode: $mode');
  log('ws:   $wsUri');
  log('cli:  ${intentcall.describe()}');

  switch (mode) {
    case 'demo':
      await _run(intentcall, <String>['link', 'discover', '--scheme', scheme]);
      await _run(intentcall, <String>[
        'link',
        'call',
        '--scheme',
        scheme,
        '--name',
        'app_intentcall_bridge_ping',
        '--args',
        '{"echo":"hello"}',
      ]);
      stdout.writeln();
      log('MCP doors (both block until interrupted):');
      log('  dart run packages/harness/tool/intentcall_session.dart serve-link');
      log('  dart run packages/harness/tool/intentcall_session.dart serve-debug');
    case 'serve-link':
      await _run(
        intentcall,
        <String>['mcp', 'serve', '--scheme', scheme],
      );
    case 'serve-debug':
      await _run(intentcall, <String>[
        'mcp',
        'serve',
        '--auto',
        '--vm-service-uri',
        '$wsUri',
        '--scheme',
        scheme,
      ]);
  }
  await quit(0);
}

void _printUsage() {
  log('usage: dart run packages/harness/tool/intentcall_session.dart '
      '[demo|serve-link|serve-debug] '
      '[--vm-service-uri WS_URI] [--log PATH] [--web] [--scheme SCHEME]');
}

/// Explicit arg wins (http form is canonicalized); otherwise scrape the
/// showcase log — the `ws://` web form first, then the desktop http form.
Future<Uri?> _resolveWsUri({
  required final String? explicit,
  required final String? logPath,
}) async {
  final explicitUri = explicit == null ? null : Uri.parse(explicit);
  if (explicitUri != null && explicitUri.scheme == 'ws') return explicitUri;
  if (explicitUri != null) return canonicalVmServiceWsUri(explicitUri);

  final file = File(logPath ?? p.join(showcaseDir, 'flutter_app.log'));
  if (!file.existsSync()) return null;
  final contents = file.readAsStringSync();
  return lastVmServiceWsUriIn(contents) ?? lastVmServiceUriIn(contents);
}

/// How to invoke the IntentCall CLI, preferring a checkout (dogfood path)
/// over `PATH`.
final class IntentcallCommand {
  IntentcallCommand.checkout(this.cliDir)
      : executable = 'dart',
        prefix = const <String>['run', 'bin/intentcall.dart'];

  IntentcallCommand.onPath()
      : cliDir = null,
        executable = 'intentcall',
        prefix = const <String>[];

  /// Directory of the `intentcall_cli` checkout, or null for the PATH binary.
  final String? cliDir;
  final String executable;
  final List<String> prefix;

  /// `INTENTCALL_ROOT` beats sibling checkouts (`intentcall`, `agentkit`)
  /// beats whatever `intentcall` is on PATH.
  static IntentcallCommand resolve() {
    final fromEnv = Platform.environment['INTENTCALL_ROOT'];
    if (fromEnv != null && fromEnv.isNotEmpty) {
      return IntentcallCommand.checkout(
        p.join(fromEnv, 'packages', 'intentcall_cli'),
      );
    }
    for (final sibling in <String>['intentcall', 'agentkit']) {
      final candidate = p.join(
        repoRoot,
        '..',
        sibling,
        'packages',
        'intentcall_cli',
      );
      if (Directory(candidate).existsSync()) {
        return IntentcallCommand.checkout(candidate);
      }
    }
    return IntentcallCommand.onPath();
  }

  String describe() => cliDir == null
      ? 'intentcall (PATH)'
      : 'dart run bin/intentcall.dart in $cliDir';
}

/// Runs the CLI with stdio inherited (the serve modes are interactive and
/// blocking by design) and forwards its exit code.
Future<void> _run(
  final IntentcallCommand command,
  final List<String> arguments,
) async {
  final process = await Process.start(
    command.executable,
    [...command.prefix, ...arguments],
    workingDirectory: command.cliDir,
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await process.exitCode;
  if (code != 0) await quit(code);
}
