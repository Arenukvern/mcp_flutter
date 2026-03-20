import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../../di_live_edit_context/live_edit_context.dart';
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
    final bubble = context.bubbleResource.value.bubbleRecordsById[bubbleId];
    if (bubble == null) return;
    final records = Map<String, LiveEditBubbleRecord>.from(
      context.bubbleResource.value.bubbleRecordsById,
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
