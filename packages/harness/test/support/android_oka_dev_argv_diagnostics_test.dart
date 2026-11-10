@TestOn('vm')
library;

import 'package:test/test.dart';

import 'android_oka_dev_argv_diagnostics.dart';

void main() {
  test('hosted target argv omits android positional', () {
    final hosted = hostedAndroidAppTargetDevArgv(deviceId: 'emulator-5554');
    final supported = supportedOkaDevAndroidArgv(deviceId: 'emulator-5554');
    final intent = androidOkaDevLaunchIntent(
      okaBin: 'oka',
      projectDir: '/tmp/p',
      deviceId: 'emulator-5554',
    );
    final childArgv = intent['hostedAndroidAppTargetChildArgv'] as List;
    if (childArgv.contains('android')) {
      expect(hosted, supported);
      expect(intent['hostedOmitsAndroidPositional'], isFalse);
    } else {
      expect(hosted, ['dev', '--device', 'emulator-5554']);
      expect(supported, ['dev', 'android', '--device', 'emulator-5554']);
      expect(intent['hostedOmitsAndroidPositional'], isTrue);
    }
    expect(intent['hostedAndroidAppTargetChildArgv'], hosted);
    expect(intent['supportedOkaCliArgv'], supported);
  });
}
