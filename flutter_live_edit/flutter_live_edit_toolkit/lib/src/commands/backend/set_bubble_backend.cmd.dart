import '../../di_live_edit_context/live_edit_context.dart';
import '../../models/models.dart';
import '../../types/live_edit_types.dart';

/// Sets backend id (and optional inference config) on a specific bubble record.
final class SetBubbleBackendCommand {
  SetBubbleBackendCommand({
    required this.bubbleId,
    this.backendId,
    this.inferenceConfig,
  });

  final String bubbleId;
  final String? backendId;
  final LiveEditInferenceConfig? inferenceConfig;

  void execute(final LiveEditContext context) {
    final records = Map<String, LiveEditBubbleRecord>.from(
      context.bubbleResource.value.bubbleRecordsById,
    );
    final bubble =
        records[bubbleId] ??
        LiveEditBubbleRecord(
          bubbleId: bubbleId,
          targetDomain: _targetDomainForBubbleId(bubbleId),
          targetKey: _targetKeyForBubbleId(bubbleId),
        );
    records[bubbleId] = bubble.copyWith(
      backendId: backendId,
      inferenceConfig: inferenceConfig,
    );
    context.bubbleResource.value = context.bubbleResource.value.copyWith(
      bubbleRecordsById: records,
    );
  }
}

LiveEditTargetDomain _targetDomainForBubbleId(final String bubbleId) {
  final separatorIndex = bubbleId.indexOf('::');
  final domainToken = separatorIndex < 0
      ? bubbleId
      : bubbleId.substring(0, separatorIndex);
  return LiveEditTargetDomain.fromWire(domainToken);
}

String _targetKeyForBubbleId(final String bubbleId) {
  final separatorIndex = bubbleId.indexOf('::');
  if (separatorIndex < 0 || separatorIndex + 2 >= bubbleId.length) {
    return bubbleId;
  }
  return bubbleId.substring(separatorIndex + 2);
}
