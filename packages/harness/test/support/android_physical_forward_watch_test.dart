import 'android_physical_forward_watch.dart';
import 'package:test/test.dart';

void main() {
  group('classifyAdbForwards', () {
    final lines = [
      'emulator-5554 tcp:34381 tcp:35699',
      'emulator-5554 tcp:35059 tcp:35699',
      'emulator-5554 tcp:36421 tcp:36421',
    ];
    final watch = buildAndroidVmForwardWatch(
      deviceId: 'emulator-5554',
      ownership: {
        'vmServiceUriPort': 34381,
        'controlPort': 36421,
      },
      forwardLines: lines,
      forwardListExitCode: 0,
    );

    test('watch owns only primary host local, not secondary 35059', () {
      expect(watch.hostLocalVmPorts, [34381]);
      expect(watch.deviceRemoteVmPorts, [35699]);
      expect(watch.hostLocalVmPorts, isNot(contains(35059)));
      expect(watch.isUsable, isTrue);
    });

    test('35059→35699 is candidate only, 34381→35699 owned only', () {
      final out = classifyAdbForwards(
        currentLines: lines,
        watch: watch,
        baselineLines: const [],
        forwardListExitCode: 0,
      );
      expect(out['matchedOwnedBaselineLines'], [
        'emulator-5554 tcp:34381 tcp:35699',
      ]);
      expect(out['sameDeviceRemotePortCandidates'], [
        'emulator-5554 tcp:35059 tcp:35699',
      ]);
      expect(out['observationComplete'], isTrue);
    });

    test('nonzero adb exit => unknown incomplete', () {
      final out = classifyAdbForwards(
        currentLines: lines,
        watch: watch,
        baselineLines: const [],
        forwardListExitCode: 1,
      );
      expect(out['observationComplete'], isFalse);
    });
  });
}
