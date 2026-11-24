import 'package:universal_automation_semantics/universal_automation_semantics.dart';

/// One public snapshot observation retained for `changed` waits and baselines.
final class ObservationHistoryRecord {
  const ObservationHistoryRecord({
    required this.snapshotId,
    required this.filterKey,
    required this.observation,
  });

  final int snapshotId;
  final String filterKey;
  final Observation observation;
}

/// Ring buffer of recent public [Observation]s keyed by [snapshotId].
final class SemanticObservationHistory {
  SemanticObservationHistory._();

  static final SemanticObservationHistory instance =
      SemanticObservationHistory._();

  static const int capacity = 8;

  final List<ObservationHistoryRecord> _entries = <ObservationHistoryRecord>[];

  void record(Observation observation, int snapshotId, String filterKey) {
    _entries.add(
      ObservationHistoryRecord(
        snapshotId: snapshotId,
        filterKey: filterKey,
        observation: observation,
      ),
    );
    while (_entries.length > capacity) {
      _entries.removeAt(0);
    }
  }

  /// Returns the record whose [ObservationHistoryRecord.snapshotId] matches
  /// [snapshotId], or `null` when it has been evicted from the ring.
  ObservationHistoryRecord? lookupSince(int snapshotId) {
    for (final entry in _entries) {
      if (entry.snapshotId == snapshotId) return entry;
    }
    return null;
  }
}