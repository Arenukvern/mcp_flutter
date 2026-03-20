import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../../di_live_edit_context/live_edit_context.dart';
import '../../types/live_edit_types.dart';

/// Sets inference config on a specific bubble record.
final class SetBubbleInferenceConfigCommand {
  SetBubbleInferenceConfigCommand({
    required this.bubbleId,
    this.model,
    this.reasoningEffort,
  });

  final String bubbleId;
  final String? model;
  final String? reasoningEffort;

  void execute(final LiveEditContext context) {
    final bubble = context.bubbleResource.value.bubbleRecordsById[bubbleId];
    if (bubble == null) return;
    final backendId = bubble.backendId;
    if (backendId == null || backendId.isEmpty) return;
    final nextConfig = LiveEditCodexOptions.normalizeConfig(
      LiveEditInferenceConfig(
        model: model?.trim().isNotEmpty == true ? model!.trim() : null,
        reasoningEffort:
            backendId == 'codex_exec' &&
                (reasoningEffort?.trim().isNotEmpty == true)
            ? reasoningEffort!.trim()
            : null,
      ),
    );
    final records = Map<String, LiveEditBubbleRecord>.from(
      context.bubbleResource.value.bubbleRecordsById,
    );
    records[bubbleId] = bubble.copyWith(inferenceConfig: nextConfig);
    context.bubbleResource.value = context.bubbleResource.value.copyWith(
      bubbleRecordsById: records,
    );
  }
}
