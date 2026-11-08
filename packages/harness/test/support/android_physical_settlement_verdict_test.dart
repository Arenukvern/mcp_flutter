import 'android_owned_physical_observations.dart';
import 'package:test/test.dart';

void main() {
  group('physicalSettlementVerdictFromObservation', () {
    test('b241-style survivors => not proven (forwards + app pid)', () {
      final observation = <String, Object?>{
        'adbForwardList': <String, Object?>{
          'lines': <String>[
            'emulator-5554 tcp:35593 tcp:40897',
            'emulator-5554 tcp:42883 tcp:40897',
          ],
          'matchedVmSessionLines': <String>[
            'emulator-5554 tcp:35593 tcp:40897',
            'emulator-5554 tcp:42883 tcp:40897',
          ],
        },
        'fixtureAppProcesses': <String, Object?>{
          'pidList': <String>['2398'],
        },
        'hostSessionOwner': <String, Object?>{
          'alive': false,
          'descendantPids': <int>[],
        },
        'hostSpawnHandle': <String, Object?>{
          'alive': false,
          'descendantPids': <int>[],
        },
      };
      final v = physicalSettlementVerdictFromObservation(observation);
      expect(v['provenPhysicalSettlement'], isFalse);
      expect(v['provenOwnedResourceSettlement'], isFalse);
      expect(v['matchedVmForwardsAtEnd'], hasLength(2));
      expect(v['deviceAppPidsAtEnd'], ['2398']);
    });

    test('cleared forwards, no app pid, quiet host => proven', () {
      final observation = <String, Object?>{
        'adbForwardList': <String, Object?>{
          'lines': <String>[],
          'matchedVmSessionLines': <String>[],
        },
        'fixtureAppProcesses': <String, Object?>{
          'pidList': <String>[],
        },
        'hostSessionOwner': <String, Object?>{
          'alive': false,
          'descendantPids': <int>[],
        },
        'hostSpawnHandle': <String, Object?>{
          'alive': false,
          'descendantPids': <int>[],
        },
      };
      final v = physicalSettlementVerdictFromObservation(observation);
      expect(v['provenPhysicalSettlement'], isTrue);
      expect(v['provenOwnedResourceSettlement'], isFalse);
    });

    test('host owner alive blocks proven even when forwards cleared', () {
      final observation = <String, Object?>{
        'adbForwardList': <String, Object?>{
          'matchedVmSessionLines': <String>[],
        },
        'fixtureAppProcesses': <String, Object?>{
          'pidList': <String>[],
        },
        'hostSessionOwner': <String, Object?>{
          'alive': true,
          'descendantPids': <int>[999],
        },
        'hostSpawnHandle': <String, Object?>{
          'alive': false,
          'descendantPids': <int>[],
        },
      };
      final v = physicalSettlementVerdictFromObservation(observation);
      expect(v['provenPhysicalSettlement'], isFalse);
      expect(v['hostOwnerAliveAtEnd'], isTrue);
    });
  });
}
