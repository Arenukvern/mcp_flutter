import '../../live_edit_context.dart';
import '../../live_edit_types.dart';

/// Sets instruction text for a given bubble id.
final class UpdateBubbleComposerCommand {
  UpdateBubbleComposerCommand({required this.bubbleId, required this.value});

  final String bubbleId;
  final String value;

  void execute(final LiveEditContext context) {
    final bubble = context.bubbleResource.value.bubbleRecordsById[bubbleId];
    if (bubble == null) return;
    final records = Map<String, LiveEditBubbleRecord>.from(
      context.bubbleResource.value.bubbleRecordsById,
    );
    records[bubbleId] = bubble.copyWith(instructionText: value);
    context.bubbleResource.value = context.bubbleResource.value.copyWith(
      bubbleRecordsById: records,
    );
  }
}
