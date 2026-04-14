import '../../di_live_edit_context/live_edit_context.dart';
import '../../models/models.dart';

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
    const structuredIds = <String>{'codex_exec', 'claude_code'};
    final nextConfig = LiveEditCodexOptions.normalizeConfig(
      LiveEditInferenceConfig(
        model: model?.trim().isNotEmpty == true ? model!.trim() : null,
        reasoningEffort:
            structuredIds.contains(backend.id) &&
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
