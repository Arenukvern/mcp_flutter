import 'android_owned_physical_observations.dart';
import 'android_physical_forward_watch.dart';
import 'package:test/test.dart';

void main() {
  group('physicalSettlementVerdictFromObservation', () {
    test('b241-style survivors => not proven (owned forwards + app pid)', () {
      final observation = <String, Object?>{
        'forwardClassification': <String, Object?>{
          'matchedOwnedBaselineLines': <String>[
            'emulator-5554 tcp:34381 tcp:35699',
          ],
          'sameDeviceRemotePortCandidates': <String>[
            'emulator-5554 tcp:35059 tcp:35699',
          ],
        },
        'fixtureAppProcesses': <String, Object?>{
          'pidList': <String>['2398'],
        },
        'trackedHostIdentitiesQuiet': true,
      };
      final v = physicalSettlementVerdictFromObservation(observation);
      expect(v['provenPhysicalSettlement'], isFalse);
      expect(v['matchedOwnedBaselineLinesAtEnd'], hasLength(1));
      expect(v['sameDeviceRemotePortCandidatesAtEnd'], hasLength(1));
    });

    test('cleared owned forwards, no app, quiet identities => proven', () {
      final observation = <String, Object?>{
        'forwardClassification': <String, Object?>{
          'matchedOwnedBaselineLines': <String>[],
        },
        'fixtureAppProcesses': <String, Object?>{
          'pidList': <String>[],
        },
        'trackedHostIdentitiesQuiet': true,
      };
      final v = physicalSettlementVerdictFromObservation(observation);
      expect(v['provenPhysicalSettlement'], isTrue);
    });

    test('tracked orphan still alive blocks proven', () {
      final observation = <String, Object?>{
        'forwardClassification': <String, Object?>{
          'matchedOwnedBaselineLines': <String>[],
        },
        'fixtureAppProcesses': <String, Object?>{
          'pidList': <String>[],
        },
        'trackedHostIdentitiesQuiet': false,
      };
      final v = physicalSettlementVerdictFromObservation(observation);
      expect(v['provenPhysicalSettlement'], isFalse);
    });
  });

  group('buildAndroidVmForwardWatch', () {
    test('includes secondary host local sharing device remote, excludes control', () {
      final lines = <String>[
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
      );
      expect(watch.hostLocalVmPorts, containsAll([34381, 35059]));
      expect(watch.hostLocalVmPorts, isNot(contains(36421)));
      expect(watch.deviceRemoteVmPorts, contains(35699));
      final classified = classifyAdbForwards(
        currentLines: lines,
        watch: watch,
        baselineLines: lines,
      );
      expect(classified['matchedOwnedBaselineLines'], hasLength(2));
      expect(classified['sameDeviceRemotePortCandidates'], isEmpty);
    });
  });
}
