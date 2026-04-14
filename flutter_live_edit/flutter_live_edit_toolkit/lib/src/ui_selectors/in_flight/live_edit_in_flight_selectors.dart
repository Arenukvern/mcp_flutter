import '../../di_live_edit_context/live_edit_context.dart';
import '../../models/models.dart';

/// Returns, for every currently tracked in-flight bubble, the id of the
/// bubble it collides with — or `null` if no collision.
///
/// Useful to drive a panel chip indicator ("waiting for <label>…"). Bubbles
/// with [LiveEditInFlightStatus.running], [LiveEditInFlightStatus.completed],
/// or [LiveEditInFlightStatus.failed] status map to `null`. Bubbles with
/// [LiveEditInFlightStatus.blockedOnOverlap] map to the colliding bubble id
/// as recorded in [LiveEditInFlightRecord.meta] under `collidesWith`.
Map<String, String?> selectInFlightOverlaps(final LiveEditContext ctx) {
  final records = ctx.inFlightResource.value.recordsByBubbleId;
  final result = <String, String?>{};
  for (final entry in records.entries) {
    final record = entry.value;
    if (record.status == LiveEditInFlightStatus.blockedOnOverlap) {
      final collidesWith = record.meta['collidesWith'];
      result[entry.key] = collidesWith is String ? collidesWith : null;
    } else {
      result[entry.key] = null;
    }
  }
  return result;
}
