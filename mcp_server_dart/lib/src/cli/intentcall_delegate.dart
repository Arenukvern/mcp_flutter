import 'dart:io';

import 'package:path/path.dart' as p;

/// How to invoke the IntentCall CLI without a compile-time dependency on
/// `intentcall_cli` (ADR-0016: adapters discover tools, they do not import
/// them). `INTENTCALL_ROOT` beats a sibling checkout beats `intentcall` on
/// PATH (`dart pub global activate intentcall_cli`).
final class IntentcallCli {
  IntentcallCli.checkout(this.cliDir)
    : executable = 'dart',
      prefix = const <String>['run', 'bin/intentcall.dart'];

  IntentcallCli.onPath()
    : cliDir = null,
      executable = 'intentcall',
      prefix = const <String>[];

  /// Directory of the `intentcall_cli` checkout, or null for the PATH binary.
  final String? cliDir;
  final String executable;
  final List<String> prefix;

  /// Resolves the CLI, or null when nothing usable is installed.
  /// [environment] and [cwd] are injectable for tests.
  static IntentcallCli? tryResolve({
    final Map<String, String>? environment,
    final String? cwd,
  }) {
    final env = environment ?? Platform.environment;
    final fromEnv = env['INTENTCALL_ROOT'];
    if (fromEnv != null && fromEnv.isNotEmpty) {
      final candidate = p.join(fromEnv, 'packages', 'intentcall_cli');
      if (Directory(candidate).existsSync()) {
        return IntentcallCli.checkout(candidate);
      }
    }
    final base = cwd ?? Directory.current.path;
    for (final sibling in const <String>['intentcall', 'agentkit']) {
      final candidate = p.normalize(
        p.join(base, '..', sibling, 'packages', 'intentcall_cli'),
      );
      if (Directory(candidate).existsSync()) {
        return IntentcallCli.checkout(candidate);
      }
    }
    final onPath = Process.runSync('which', const <String>['intentcall']);
    if (onPath.exitCode == 0) return IntentcallCli.onPath();
    return null;
  }

  /// Runs `intentcall <arguments>` with stdio inherited and returns the
  /// delegate's exit code. Fresh checkouts get `dart pub get` first —
  /// `dart run bin/<file>` needs the package's own resolution.
  Future<int> run(final List<String> arguments) async {
    if (cliDir != null &&
        !Directory(p.join(cliDir!, '.dart_tool')).existsSync()) {
      final get = await Process.run(
        executable,
        const <String>['pub', 'get'],
        workingDirectory: cliDir,
      );
      if (get.exitCode != 0) {
        stderr.write(get.stderr);
        return get.exitCode;
      }
    }
    stderr.writeln(
      '» delegating to ${cliDir ?? 'intentcall (PATH)'}',
    );
    final process = await Process.start(
      executable,
      <String>[...prefix, ...arguments],
      workingDirectory: cliDir,
      mode: ProcessStartMode.inheritStdio,
    );
    return process.exitCode;
  }
}

void _printInstallHint() {
  stderr.writeln(
    'This command delegates to the IntentCall CLI, which was not found.\n'
    'Install it with:\n'
    '  dart pub global activate intentcall_cli\n'
    'or point INTENTCALL_ROOT at an intentcall checkout.',
  );
}

/// Delegates `flutter-mcp-toolkit codegen sync` to
/// `intentcall platform sync --host flutter`, discovered at runtime.
/// [cli] overrides resolution (tests inject a fake).
Future<int> delegatePlatformSync({
  required final String projectRoot,
  required final List<String> platforms,
  final bool checkOnly = false,
  final IntentcallCli? cli,
}) async {
  final resolved = cli ?? IntentcallCli.tryResolve();
  if (resolved == null) {
    _printInstallHint();
    return 69; // EX_UNAVAILABLE
  }
  return resolved.run(<String>[
    'platform',
    'sync',
    '--project-dir',
    projectRoot,
    '--host',
    'flutter',
    for (final platform in platforms) ...<String>['--platform', platform],
    if (checkOnly) '--check',
  ]);
}

/// Delegates `flutter-mcp-toolkit init intentcall-platform` to
/// `intentcall platform hooks init --host flutter`, discovered at runtime.
/// [cli] overrides resolution (tests inject a fake).
Future<int> delegatePlatformHooksInit({
  required final String projectRoot,
  final bool checkOnly = false,
  final IntentcallCli? cli,
}) async {
  final resolved = cli ?? IntentcallCli.tryResolve();
  if (resolved == null) {
    _printInstallHint();
    return 69; // EX_UNAVAILABLE
  }
  return resolved.run(<String>[
    'platform',
    'hooks',
    'init',
    '--project-dir',
    projectRoot,
    '--host',
    'flutter',
    if (checkOnly) '--check',
  ]);
}
