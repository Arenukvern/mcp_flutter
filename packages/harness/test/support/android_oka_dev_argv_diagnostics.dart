/// Documented argv mismatch: hosted [AndroidAppTarget] vs oka 0.9.1 CLI routing.
library;

/// Args hosted `AndroidAppTarget` passes to `Process.start` (oka_harness 0.9.1).
///
/// Confirmed against hosted `packages/oka_harness/lib/src/android_app_target.dart`
/// and `oka` 0.9.1 `DevCommand`: without positional `android`, `oka dev` routes
/// to `delegateToKernelStack` (kernel live-update stack), **not** the ADR-0011
/// android daemon that writes `.flutter_mcp/runner-session.json`.
List<String> hostedAndroidAppTargetDevArgv({
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

/// Supported diagnostic invocation (manifest parity with hosted target).
List<String> supportedOkaDevAndroidArgv({
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
    'android',
    if (deviceId != null) ...['--device', deviceId],
    ...defineArgs,
  ];
}

Map<String, Object?> androidOkaDevLaunchIntent({
  required String okaBin,
  required String projectDir,
  String? deviceId,
  Map<String, String> dartDefines = const {},
}) {
  final hostedChild = hostedAndroidAppTargetDevArgv(
    deviceId: deviceId,
    dartDefines: dartDefines,
  );
  final supported = supportedOkaDevAndroidArgv(
    deviceId: deviceId,
    dartDefines: dartDefines,
  );
  return {
    'okaHarnessVersion': '0.9.1',
    'hostedAndroidAppTargetChildArgv': hostedChild,
    'supportedOkaCliArgv': supported,
    'hostedOmitsAndroidPositional': !hostedChild.contains('android'),
    'okaBinConfigured': okaBin,
    'projectDir': projectDir,
    'publicAndroidAppTargetKnobs': const [
      'projectDir',
      'deviceId',
      'dartDefines',
      'environment',
      'name',
      'okaBin',
      'logcat',
      'sessionTimeout',
    ],
    'hostedWaitForSessionBehavior': {
      'pollsRunnerSessionFile': true,
      'racesChildExitCode': false,
      'timeoutTailLines': 15,
    },
    'routingReference': 'oka 0.9.1 DevCommand: args.first != android → kernel stack',
    'consumerNote':
        'Await immutable oka SDK PR commit (OKA_BIN + OKA_CONSUMER_PIN_SHA). '
        'No shell argv rewrite; hosted fix must emit dev android child argv.',
  };
}
