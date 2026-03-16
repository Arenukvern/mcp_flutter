import '../live_edit_context.dart';
import '../live_edit_types.dart';

/// Sets global composer text or active bubble instruction text.
final class UpdateAiComposerCommand {
  UpdateAiComposerCommand({required this.value});

  final String value;

  void execute(final LiveEditContext context) {
    final domain = context.sessionResource.value.targetDomain;
    final bubbleData = context.bubbleResource.value;
    final layerState = bubbleData.layerViewStateByDomain[domain];
    final activeId = layerState?.activeBubbleId;

    if (activeId != null) {
      final bubble = bubbleData.bubbleRecordsById[activeId];
      if (bubble != null) {
        final records = Map<String, LiveEditBubbleRecord>.from(
          bubbleData.bubbleRecordsById,
        );
        records[activeId] = bubble.copyWith(instructionText: value);
        context.bubbleResource.value = bubbleData.copyWith(
          bubbleRecordsById: records,
        );
        return;
      }
    }
    context.bubbleResource.value =
        bubbleData.copyWith(globalComposerText: value);
  }
}
