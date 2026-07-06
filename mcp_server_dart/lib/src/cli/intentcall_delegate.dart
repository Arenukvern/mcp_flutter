import 'package:args/args.dart';
import 'package:intentcall_cli/intentcall_cli.dart';

ArgParser _platformSyncParser() {
  return ArgParser()
    ..addOption('project-dir', defaultsTo: '.')
    ..addMultiOption(
      'platform',
      abbr: 'p',
      valueHelp: 'LIST',
    )
    ..addFlag('check', negatable: false)
    ..addFlag('dry-run', negatable: false)
    ..addOption('host', defaultsTo: 'flutter');
}

/// Delegates to `intentcall platform sync --host flutter`.
int delegatePlatformSync({
  required final String projectRoot,
  required final List<String> platforms,
  final bool checkOnly = false,
}) {
  final args = <String>[
    '--project-dir',
    projectRoot,
    '--host',
    'flutter',
    for (final platform in platforms) ...['--platform', platform],
    if (checkOnly) '--check',
  ];
  return runPlatformSync(_platformSyncParser().parse(args));
}

/// Delegates to `intentcall platform hooks init --host flutter`.
Future<int> delegatePlatformHooksInit({
  required final String projectRoot,
  final bool checkOnly = false,
}) async {
  final runner = IntentCallCommandRunner();
  final args = <String>[
    'platform',
    'hooks',
    'init',
    '--project-dir',
    projectRoot,
    '--host',
    'flutter',
    if (checkOnly) '--check',
  ];
  return await runner.run(args) ?? 1;
}
