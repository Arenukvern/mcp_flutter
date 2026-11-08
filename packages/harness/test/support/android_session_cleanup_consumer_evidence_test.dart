import 'package:oka_android/oka_android.dart';
import 'package:test/test.dart';

import 'android_owned_session_stop.dart';

DevSessionStopReport _minimalReport({
  Map<String, Object?>? sessionCleanup,
  bool? sessionCleanupActionsSucceeded,
}) {
  return DevSessionStopReport(
    disposition: DevSessionStopDisposition.cooperative,
    runnerSessionCleared: true,
    controlQuitAcknowledged: true,
    controlQuitSent: true,
    controlQuitConnectFailed: false,
    controlReplyLost: false,
    stdinQuitWritten: false,
    elapsed: Duration.zero,
    limits: 'test',
    sessionCleanup: sessionCleanup,
    sessionCleanupActionsSucceeded: sessionCleanupActionsSucceeded,
  );
}

void main() {
  test('session cleanup identity match when runnerPid equals owner', () {
    final ev = sessionCleanupConsumerEvidence(
      report: _minimalReport(
        sessionCleanup: {
          'identity': {'runnerPid': 4242},
          'actionsSucceeded': true,
        },
        sessionCleanupActionsSucceeded: true,
      ),
      sessionOwnerPid: 4242,
    );
    expect(ev['sessionCleanupIdentityMatch'], isTrue);
    expect(ev['observationComplete'], isTrue);
  });

  test('identity mismatch is fail-closed incomplete', () {
    final ev = sessionCleanupConsumerEvidence(
      report: _minimalReport(
        sessionCleanup: {
          'identity': {'runnerPid': 1},
          'actionsSucceeded': true,
        },
        sessionCleanupActionsSucceeded: true,
      ),
      sessionOwnerPid: 2,
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
      report: _minimalReport(),
      sessionOwnerPid: 1,
    );
    expect(ev['observationComplete'], isFalse);
    expect(
      (ev['observationUnknownReasons'] as List).cast<String>(),
      contains('session_cleanup_sidecar_missing'),
    );
  });
}
