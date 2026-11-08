import 'dart:convert';
import 'dart:io';

import 'android_oka_dev_argv_diagnostics.dart';
import 'oka_consumer_pin.dart';

const _historicalBareDevDiagnosis = {
  'label': 'historical_diagnosis_oka_0_9_1_hosted_bare_dev',
  'symptom':
      'Hosted oka_harness 0.9.1 AndroidAppTarget omitted positional android; '
      'oka dev routed to kernel stack instead of ADR-0011 android daemon.',
  'hostedOmitsAndroidPositional': true,
  'supportedOkaCliArgv': <String>['dev', 'android', '...'],
  'routingReference': 'oka 0.9.1 DevCommand: args.first != android → kernel stack',
  'supersededBy': 'actualResolvedChildArgvFromWorkspace (pin-provisioned oka_harness)',
};

/// Mirrors [AndroidAppTarget] `Process.start` argv from resolved oka_harness source.
List<String> mirrorAndroidAppTargetDevChildArgv({
  String? deviceId,
  Map<String, String> dartDefines = const {},
}) {
  final defineArgs = [
    for (final entry in dartDefines.entries) ...[
      '--dart-define',
      '${entry.key}=${entry.value}',
    ],
  ];
  return <String>[
    'dev',
    if (deviceId != null) ...['--device', deviceId],
    ...defineArgs,
  ];
}

Future<Map<String, Object?>?> _readPackageConfigEntry(
  Directory repoRoot,
  String packageName,
) async {
  final paths = [
    File('${repoRoot.path}/packages/harness/.dart_tool/package_config.json'),
    File('${repoRoot.path}/.dart_tool/package_config.json'),
  ];
  for (final file in paths) {
    if (!file.existsSync()) continue;
    final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final packages = decoded['packages'] as List<dynamic>;
    for (final raw in packages) {
      final entry = raw as Map<String, dynamic>;
      if (entry['name'] != packageName) continue;
      return {
        'name': packageName,
        'rootUri': entry['rootUri'],
        'packageUri': entry['packageUri'],
        'version': entry['version'],
        'packageConfigPath': file.path,
      };
    }
  }
  return null;
}

/// CI / integration launch-intent artifact: pin SHA + resolved packages + actual argv.
Future<Map<String, Object?>> buildAndroidOkaDevLaunchIntentReport({
  required Directory repoRoot,
  required String okaBin,
  required String projectDir,
  String? deviceId,
  Map<String, String> dartDefines = const {},
}) async {
  final pinSha = readOkaConsumerPinSha(repoRoot: repoRoot);
  final okaHarness = await _readPackageConfigEntry(repoRoot, 'oka_harness');
  final okaAndroid = await _readPackageConfigEntry(repoRoot, 'oka_android');
  final which = await Process.run('bash', ['-lc', 'command -v $okaBin']);
  final version = await Process.run(okaBin, ['--version']);
  final actualChildArgv = mirrorAndroidAppTargetDevChildArgv(
    deviceId: deviceId,
    dartDefines: dartDefines,
  );
  return {
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'okaConsumerPinSha': pinSha,
    'okaBinConfigured': okaBin,
    'okaResolvedPath': '${which.stdout}'.trim(),
    'okaVersionStdout': '${version.stdout}'.trim(),
    'okaVersionExitCode': version.exitCode,
    'projectDir': projectDir,
    'actualResolvedChildArgv': actualChildArgv,
    'actualOmitsAndroidPositional':
        !actualChildArgv.contains('android'),
    'resolvedPackages': {
      'oka_harness': okaHarness,
      'oka_android': okaAndroid,
    },
    'historicalDiagnosis': _historicalBareDevDiagnosis,
    if (!actualChildArgv.contains('android'))
      'routingWarning':
          'Resolved AndroidAppTarget still emits bare `oka dev` child argv; '
          'await pin bump to oka_harness with `dev android` (SDK worker).',
    'legacyArgvComparison': androidOkaDevLaunchIntent(
      okaBin: okaBin,
      projectDir: projectDir,
      deviceId: deviceId,
      dartDefines: dartDefines,
    ),
  };
}
