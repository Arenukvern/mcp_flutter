import 'package:test/test.dart';

import 'android_owned_session_stop.dart';

void main() {
  test('session cleanup identity match when runnerPid equals owner', () {
    final ev = sessionCleanupConsumerEvidence(
      sessionOwnerPid: 4242,
      sessionCleanupSidecar: {
        'identity': {'runnerPid': 4242},
        'actionsSucceeded': true,
      },
    );
    expect(ev['sessionCleanupIdentityMatch'], isTrue);
    expect(ev['observationComplete'], isTrue);
  });

  test('identity mismatch is fail-closed incomplete', () {
    final ev = sessionCleanupConsumerEvidence(
      sessionOwnerPid: 2,
      sessionCleanupSidecar: {
        'identity': {'runnerPid': 1},
        'actionsSucceeded': true,
      },
    );
    expect(ev['sessionCleanupIdentityMatch'], isFalse);
    expect(ev['observationComplete'], isFalse);
    expect(
      (ev['observationUnknownReasons'] as List).cast<String>(),
      contains('session_cleanup_identity_mismatch'),
    );
  });

  test('missing sidecar is incomplete', () {
    final ev = sessionCleanupConsumerEvidence(
      sessionOwnerPid: 1,
    );
    expect(ev['observationComplete'], isFalse);
    expect(
      (ev['observationUnknownReasons'] as List).cast<String>(),
      contains('session_cleanup_sidecar_missing'),
    );
  });
}
