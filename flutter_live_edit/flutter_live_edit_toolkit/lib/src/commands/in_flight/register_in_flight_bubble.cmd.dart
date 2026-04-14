import '../../di_live_edit_context/live_edit_context.dart';
import '../../models/models.dart';

/// Registers a bubble as in-flight.
///
/// If [targetPath] prefix-overlaps any existing `running` bubble (in either
/// direction), the new record is inserted with status
/// [LiveEditInFlightStatus.blockedOnOverlap] and its `meta` carries
/// `{'collidesWith': <bubbleId>}`. Otherwise the record is inserted as
/// [LiveEditInFlightStatus.running]. Re-registering an existing bubble
/// re-evaluates overlap against the remaining records.
final class RegisterInFlightBubbleCommand {
  RegisterInFlightBubbleCommand({
    required this.bubbleId,
    this.targetPath,
    this.filePaths = const <String>[],
  });

  final String bubbleId;
  final String? targetPath;
  final List<String> filePaths;

  void execute(final LiveEditContext context) {
    final data = context.inFlightResource.value;
    final updated = Map<String, LiveEditInFlightRecord>.from(
      data.recordsByBubbleId,
    )..remove(bubbleId);

    String? collidesWith;
    final candidate = targetPath;
    if (candidate != null && candidate.isNotEmpty) {
      for (final record in updated.values) {
        if (record.status != LiveEditInFlightStatus.running) continue;
        final other = record.targetPath;
        if (other == null || other.isEmpty) continue;
        if (candidate == other ||
            candidate.startsWith(other) ||
            other.startsWith(candidate)) {
          collidesWith = record.bubbleId;
          break;
        }
      }
    }

    final record = LiveEditInFlightRecord(
      bubbleId: bubbleId,
      targetPath: targetPath,
      filePaths: List<String>.unmodifiable(filePaths),
      status: collidesWith == null
          ? LiveEditInFlightStatus.running
          : LiveEditInFlightStatus.blockedOnOverlap,
      meta: collidesWith == null
          ? const <String, Object?>{}
          : <String, Object?>{'collidesWith': collidesWith},
    );

    updated[bubbleId] = record;
    context.inFlightResource.value = data.copyWith(
      recordsByBubbleId: Map<String, LiveEditInFlightRecord>.unmodifiable(
        updated,
      ),
    );
  }
}
