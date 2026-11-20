/// Documented oka_harness [AndroidAppTarget] child argv (consumer boundary).
library;

/// Args hosted `AndroidAppTarget` passes to `Process.start` (oka_harness 0.11.0).
///
/// From `packages/oka_harness/lib/src/android_app_target.dart` on the v0.11.0
/// train (ADR-0011 android daemon: `oka dev android` writes runner-session.json).
List<String> hostedAndroidAppTargetDevArgv({
  String? deviceId,
  Map<String, String> dartDefines = const {},
  bool jsonControl = true,
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
    if (jsonControl) '--json',
    if (deviceId != null) ...['--device', deviceId],
    ...defineArgs,
  ];
}

/// Legacy bare `oka dev` argv (oka_harness 0.9.1; oka ADR-0011 routing bug).
List<String> legacyBareOkaDevArgv({
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
  final legacyBare = legacyBareOkaDevArgv(
    deviceId: deviceId,
    dartDefines: dartDefines,
  );
  return {
    'okaHarnessVersion': '0.11.0',
    'hostedAndroidAppTargetChildArgv': hostedChild,
    'legacyBareOkaDevArgv': legacyBare,
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
      'jsonControl',
      'sessionTimeout',
      'requirePlausibleSpawnOwnership',
    ],
    'hostedWaitForSessionBehavior': {
      'pollsRunnerSessionFile': true,
      'racesChildExitCode': false,
      'usesSpawnBindingVerification': true,
    },
    'routingReference':
        'oka dev android → ADR-0011 android daemon (runner-session.json)',
    'historicalNote':
        'oka_harness 0.9.1 omitted android positional; fixed in oka 0.10.x+.',
  };
}