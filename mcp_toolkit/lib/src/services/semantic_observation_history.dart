import 'package:universal_automation_semantics/universal_automation_semantics.dart';

/// One public snapshot observation retained for `changed` waits and baselines.
final class ObservationHistoryRecord {
  const ObservationHistoryRecord({
    required this.snapshotId,
    required this.filterKey,
    required this.observation,
    required this.publicSequence,
  });

  final int snapshotId;
  final String filterKey;
  final Observation observation;

  /// Monotonic index assigned when this record entered the ring.
  final int publicSequence;
}

/// Why [lookupSince] missed a [snapshotId].
final class BaselineEvictionInfo {
  const BaselineEvictionInfo.neverRecorded()
    : publicSnapshotsSince = null,
      neverRecorded = true;

  const BaselineEvictionInfo.evicted({required this.publicSnapshotsSince})
    : neverRecorded = false;

  final int? publicSnapshotsSince;
  final bool neverRecorded;
}

/// Ring buffer of recent public [Observation]s keyed by [snapshotId].
final class SemanticObservationHistory {
  SemanticObservationHistory._();

  static final SemanticObservationHistory instance =
      SemanticObservationHistory._();

  /// Capacity of the public-snapshot ring (documented in agent-facing hints).
  static const int publicObservationRingCapacity = 32;

  final List<ObservationHistoryRecord> _entries = <ObservationHistoryRecord>[];
  int _publicSequence = 0;

  void record(Observation observation, int snapshotId, String filterKey) {
    _publicSequence++;
    _entries.add(
      ObservationHistoryRecord(
        snapshotId: snapshotId,
        filterKey: filterKey,
        observation: observation,
        publicSequence: _publicSequence,
      ),
    );
    while (_entries.length > publicObservationRingCapacity) {
      _entries.removeAt(0);
    }
  }

  ObservationHistoryRecord? lookupSince(int snapshotId) {
    for (final entry in _entries) {
      if (entry.snapshotId == snapshotId) return entry;
    }
    return null;
  }

  /// Diagnostics when [lookupSince] returns null.
  BaselineEvictionInfo? evictionInfoFor(int snapshotId) {
    if (lookupSince(snapshotId) != null) return null;
    if (_entries.isEmpty) {
      return const BaselineEvictionInfo.neverRecorded();
    }
    final oldest = _entries.first;
    if (snapshotId > _entries.last.snapshotId) {
      return const BaselineEvictionInfo.neverRecorded();
    }
    if (snapshotId < oldest.snapshotId) {
      final since =
          _publicSequence - oldest.publicSequence + 1;
      return BaselineEvictionInfo.evicted(publicSnapshotsSince: since);
    }
    return const BaselineEvictionInfo.neverRecorded();
  }

  int get latestPublicSequence => _publicSequence;
}