import '../../di_live_edit_context/live_edit_context.dart';
import '../../models/models.dart';

/// Marks an in-flight bubble as [LiveEditInFlightStatus.completed] or
/// [LiveEditInFlightStatus.failed], then re-scans
/// [LiveEditInFlightStatus.blockedOnOverlap] records and promotes any that
/// no longer overlap any `running` record to `running` (clearing their
/// `collidesWith` meta).
final class CompleteInFlightBubbleCommand {
  CompleteInFlightBubbleCommand({
    required this.bubbleId,
    required this.success,
  });

  final String bubbleId;
  final bool success;

  void execute(final LiveEditContext context) {
    final data = context.inFlightResource.value;
    final existing = data.recordsByBubbleId[bubbleId];
    if (existing == null) return;

    final updated = Map<String, LiveEditInFlightRecord>.from(
      data.recordsByBubbleId,
    );
    updated[bubbleId] = existing.copyWith(
      status: success
          ? LiveEditInFlightStatus.completed
          : LiveEditInFlightStatus.failed,
    );

    // Re-scan blocked records; a blocked record can be promoted only if its
    // own targetPath no longer overlaps any remaining `running` record.
    for (final entry in updated.entries.toList(growable: false)) {
      final record = entry.value;
      if (record.status != LiveEditInFlightStatus.blockedOnOverlap) continue;
      final candidate = record.targetPath;
      if (candidate == null || candidate.isEmpty) {
        // No target path means no overlap possible; promote.
        updated[entry.key] = record.copyWith(
          status: LiveEditInFlightStatus.running,
          meta: const <String, Object?>{},
        );
        continue;
      }
      String? collidesWith;
      for (final other in updated.values) {
        if (other.bubbleId == record.bubbleId) continue;
        if (other.status != LiveEditInFlightStatus.running) continue;
        final otherPath = other.targetPath;
        if (otherPath == null || otherPath.isEmpty) continue;
        if (candidate == otherPath ||
            candidate.startsWith(otherPath) ||
            otherPath.startsWith(candidate)) {
          collidesWith = other.bubbleId;
          break;
        }
      }
      if (collidesWith == null) {
        updated[entry.key] = record.copyWith(
          status: LiveEditInFlightStatus.running,
          meta: const <String, Object?>{},
        );
      } else if ((record.meta['collidesWith'] as String?) != collidesWith) {
        updated[entry.key] = record.copyWith(
          meta: <String, Object?>{'collidesWith': collidesWith},
        );
      }
    }

    context.inFlightResource.value = data.copyWith(
      recordsByBubbleId: Map<String, LiveEditInFlightRecord>.unmodifiable(
        updated,
      ),
    );
  }
}
