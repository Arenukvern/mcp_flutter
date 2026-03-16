import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../live_edit_context.dart';

/// Sets inference config for the global backend.
final class SetInferenceConfigCommand {
  SetInferenceConfigCommand({this.model, this.reasoningEffort});

  final String? model;
  final String? reasoningEffort;

  void execute(final LiveEditContext context) {
    final data = context.backendConfigResource.value;
    final globalId = data.globalBackendId;
    if (globalId == null || globalId.isEmpty) return;
    final backends = data.availableBackends;
    LiveEditAgentBackend? backend;
    for (final b in backends) {
      if (b.id == globalId) {
        backend = b;
        break;
      }
    }
    if (backend == null) return;
    final nextConfig = LiveEditCodexOptions.normalizeConfig(
      LiveEditInferenceConfig(
        model: model?.trim().isNotEmpty == true ? model!.trim() : null,
        reasoningEffort:
            backend.id == 'codex_exec' &&
                (reasoningEffort?.trim().isNotEmpty == true)
            ? reasoningEffort!.trim()
            : null,
      ),
    );
    final next = Map<String, LiveEditInferenceConfig>.from(
      data.inferenceConfigByBackendId,
    );
    if (nextConfig == null) {
      next.remove(globalId);
    } else {
      next[globalId] = nextConfig;
    }
    context.backendConfigResource.value = data.copyWith(
      inferenceConfigByBackendId: next,
    );
  }
}
