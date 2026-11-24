import 'semantic_observation_history.dart';
import 'semantic_snapshot_service.dart';
import 'wait_predicate_service.dart';

/// Runs [act] after pinning a public baseline, then blocks on `changed` until
/// the tree moves or [awaitChange] times out.
Future<Map<String, Object?>> runWithAwaitChange(
  Map<String, Object?>? awaitChange,
  Future<void> Function() act,
) async {
  if (awaitChange == null) {
    await act();
    return const <String, Object?>{};
  }

  // `changed` needs a ring observation for `since`. When none exists we must
  // take a public snapshot — that bumps `snapshot_id` and rebinds refs before
  // [act] (only when the caller never built, or the prior id was evicted).
  final ringBaseline =
      SemanticSnapshotService.currentSnapshotId != 0 &&
      SemanticObservationHistory.instance.lookupSince(
            SemanticSnapshotService.currentSnapshotId,
          ) !=
          null;
  if (!ringBaseline) {
    await SemanticSnapshotService.buildSemanticSnapshot();
  }
  final since = SemanticSnapshotService.currentSnapshotId;
  final timeoutMs = (awaitChange['timeoutMs'] as num?)?.toInt() ?? 5000;
  final settleMs = (awaitChange['settleMs'] as num?)?.toInt() ?? 250;

  await act();

  final waitResult = await WaitPredicateService.waitFor(
    predicate: <String, Object?>{
      'kind': 'changed',
      'since': since,
      if (settleMs > 0) 'settleMs': settleMs,
    },
    timeoutMs: timeoutMs,
  );

  final matched = waitResult['matched'] == true;
  final settled = matched && waitResult['settled'] != false;
  final elapsed = (waitResult['elapsedMs'] as num?)?.toInt() ?? 0;

  final observation = <String, Object?>{
    if (waitResult['delta'] != null) 'delta': waitResult['delta'],
    if (waitResult['added'] != null) 'added': waitResult['added'],
    if (waitResult['removed'] != null) 'removed': waitResult['removed'],
    if (waitResult['changed'] != null) 'changed': waitResult['changed'],
    if (waitResult['deltaTruncated'] == true) 'deltaTruncated': true,
    if (waitResult['partial'] == true) 'partial': true,
  };

  return <String, Object?>{
    'settled': settled,
    'observedAfterMs': elapsed,
    'changeBaselineId': since,
    if (matched) ...observation,
    if (!matched) 'changeWait': waitResult,
  };
}