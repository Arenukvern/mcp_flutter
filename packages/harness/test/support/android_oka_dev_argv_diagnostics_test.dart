@TestOn('vm')
library;

import 'package:test/test.dart';

import 'android_oka_dev_argv_diagnostics.dart';

void main() {
  test('hosted AndroidAppTarget child argv includes android and json', () {
    const deviceId = 'emulator-5554';
    final hosted = hostedAndroidAppTargetDevArgv(deviceId: deviceId);
    final legacy = legacyBareOkaDevArgv(deviceId: deviceId);
    final intent = androidOkaDevLaunchIntent(
      okaBin: 'oka',
      projectDir: '/tmp/p',
      deviceId: deviceId,
    );

    expect(
      hosted,
      ['dev', 'android', '--json', '--device', deviceId],
    );
    expect(legacy, ['dev', '--device', deviceId]);
    expect(intent['okaHarnessVersion'], '0.11.0');
    expect(intent['hostedOmitsAndroidPositional'], isFalse);
    expect(intent['hostedAndroidAppTargetChildArgv'], hosted);
    expect(intent['legacyBareOkaDevArgv'], legacy);
  });
}