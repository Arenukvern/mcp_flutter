import '../../ai/backend/live_edit_backend_utils.dart';
import '../../di_live_edit_context/live_edit_context.dart';
import '../../models/models.dart';

/// Sets available backends and resolves initial global backend id.
final class SetAvailableBackendsCommand {
  SetAvailableBackendsCommand({
    required this.availableBackends,
    this.initialBackendId,
  });

  final List<LiveEditAgentBackend> availableBackends;
  final String? initialBackendId;

  void execute(final LiveEditContext context) {
    final backends = List<LiveEditAgentBackend>.unmodifiable(availableBackends);
    final data = context.backendConfigResource.value;
    final configByBackend = Map<String, LiveEditInferenceConfig>.from(
      data.inferenceConfigByBackendId,
    );
    for (final backend in backends) {
      final config = backendEffectiveConfig(backend);
      if (config != null) {
        configByBackend.putIfAbsent(backend.id, () => config);
      }
    }
    final globalId = resolveInitialBackendId(
      availableBackends: backends,
      backendId: initialBackendId ?? data.globalBackendId,
    );
    context.backendConfigResource.value = data.copyWith(
      availableBackends: backends,
      globalBackendId: globalId,
      inferenceConfigByBackendId: configByBackend,
    );
  }
}
