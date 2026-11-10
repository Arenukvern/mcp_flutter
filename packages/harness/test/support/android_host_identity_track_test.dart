import 'android_host_identity_track.dart';
import 'package:test/test.dart';

void main() {
  group('evaluateTrackedHostIdentities', () {
    test('null start at capture + alive now => unknown, not quiet', () {
      final eval = evaluateTrackedHostIdentities([
        {
          'pid': 42,
          'identityObservabilityNow': 'unknown',
          'trackedProcessSurviving': true,
          'pidReuseSuspect': null,
        },
      ]);
      expect(eval['trackedHostIdentitiesQuiet'], isFalse);
      expect(eval['observationComplete'], isFalse);
    });

    test('confirmed start mismatch => pid reuse, not quiet', () {
      final eval = evaluateTrackedHostIdentities([
        {
          'pid': 42,
          'identityObservabilityNow': 'known',
          'trackedProcessSurviving': true,
          'pidReuseSuspect': true,
        },
      ]);
      expect(eval['trackedHostIdentitiesQuiet'], isFalse);
      expect(eval['observationComplete'], isTrue);
    });

    test('known absent => quiet', () {
      final eval = evaluateTrackedHostIdentities([
        {
          'pid': 42,
          'identityObservabilityNow': 'known_absent',
          'trackedProcessSurviving': false,
          'pidReuseSuspect': false,
        },
      ]);
      expect(eval['trackedHostIdentitiesQuiet'], isTrue);
      expect(eval['observationComplete'], isTrue);
    });
  });
}
