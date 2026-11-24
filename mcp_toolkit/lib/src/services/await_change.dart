import 'semantic_snapshot_service.dart';

/// Runs [act] after capturing a baseline observation; optional [awaitChange]
/// `settleMs` waits before the closing diff.
Future<Map<String, Object?>> runWithAwaitChange(
  Map<String, Object?>? awaitChange,
  Future<void> Function() act,
) async {
  if (awaitChange == null) {
    await act();
    return const <String, Object?>{};
  }

  final baseline = await SemanticSnapshotService.captureBaselineObservation();
  await act();

  final settleMs = (awaitChange['settleMs'] as num?)?.toInt() ?? 0;
  if (settleMs > 0) {
    await Future<void>.delayed(Duration(milliseconds: settleMs));
  }

  return SemanticSnapshotService.deltaAgainstBaseline(baseline);
}