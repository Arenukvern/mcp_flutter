import 'android_owned_physical_observations.dart';
import 'package:test/test.dart';

void main() {
  group('physicalSettlementVerdictFromObservation', () {
    test('b241 survivors + candidates => not proven', () {
      final observation = <String, Object?>{
        'observationComplete': true,
        'observationUnknownReasons': <String>[],
        'forwardClassification': <String, Object?>{
          'observationComplete': true,
          'matchedOwnedBaselineLines': <String>[
            'emulator-5554 tcp:34381 tcp:35699',
          ],
          'sameDeviceRemotePortCandidates': <String>[
            'emulator-5554 tcp:35059 tcp:35699',
          ],
        },
        'fixtureAppProcesses': <String, Object?>{
          'observationComplete': true,
          'fixtureAppState': 'running',
          'pidList': <String>['2398'],
        },
        'trackedHostIdentityEval': <String, Object?>{
          'observationComplete': true,
          'trackedHostIdentitiesQuiet': true,
        },
      };
      final v = physicalSettlementVerdictFromObservation(observation);
      expect(v['provenPhysicalSettlement'], isFalse);
      expect(v['observationComplete'], isTrue);
      expect(v['remotePortCandidatesPresentAtEnd'], isTrue);
    });

    test('unknown fixture => not proven, incomplete', () {
      final observation = <String, Object?>{
        'observationComplete': false,
        'observationUnknownReasons': <String>['adb'],
        'forwardClassification': <String, Object?>{
          'observationComplete': true,
          'matchedOwnedBaselineLines': <String>[],
          'sameDeviceRemotePortCandidates': <String>[],
        },
        'fixtureAppProcesses': <String, Object?>{
          'observationComplete': false,
          'fixtureAppState': 'unknown',
        },
        'trackedHostIdentityEval': <String, Object?>{
          'observationComplete': true,
          'trackedHostIdentitiesQuiet': true,
        },
      };
      final v = physicalSettlementVerdictFromObservation(observation);
      expect(v['provenPhysicalSettlement'], isFalse);
      expect(v['observationComplete'], isFalse);
    });

    test('cleared owned, not_running, quiet => proven', () {
      final observation = <String, Object?>{
        'observationComplete': true,
        'observationUnknownReasons': <String>[],
        'forwardClassification': <String, Object?>{
          'observationComplete': true,
          'matchedOwnedBaselineLines': <String>[],
          'sameDeviceRemotePortCandidates': <String>[],
        },
        'fixtureAppProcesses': <String, Object?>{
          'observationComplete': true,
          'fixtureAppState': 'not_running',
          'pidList': <String>[],
        },
        'trackedHostIdentityEval': <String, Object?>{
          'observationComplete': true,
          'trackedHostIdentitiesQuiet': true,
        },
      };
      final v = physicalSettlementVerdictFromObservation(observation);
      expect(v['provenPhysicalSettlement'], isTrue);
    });
  });
}
