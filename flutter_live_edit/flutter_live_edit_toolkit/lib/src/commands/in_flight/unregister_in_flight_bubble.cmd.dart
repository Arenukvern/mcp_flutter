import '../../di_live_edit_context/live_edit_context.dart';
import '../../models/models.dart';

/// Removes an in-flight record entirely. Typically called after the
/// orchestrator has observed a `completed`/`failed` status and is done with
/// any post-run bookkeeping.
final class UnregisterInFlightBubbleCommand {
  UnregisterInFlightBubbleCommand({required this.bubbleId});

  final String bubbleId;

  void execute(final LiveEditContext context) {
    final data = context.inFlightResource.value;
    if (!data.recordsByBubbleId.containsKey(bubbleId)) return;
    final updated = Map<String, LiveEditInFlightRecord>.from(
      data.recordsByBubbleId,
    )..remove(bubbleId);
    context.inFlightResource.value = data.copyWith(
      recordsByBubbleId: Map<String, LiveEditInFlightRecord>.unmodifiable(
        updated,
      ),
    );
  }
}
