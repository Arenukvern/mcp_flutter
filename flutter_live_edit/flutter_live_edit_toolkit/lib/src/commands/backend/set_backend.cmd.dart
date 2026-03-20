import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../../ai/backend/live_edit_backend_utils.dart';
import '../../di_live_edit_context/live_edit_context.dart';

/// Sets the global backend id and optionally stores effective inference config.
final class SetBackendCommand {
  SetBackendCommand({required this.backendId});

  final String backendId;

  void execute(final LiveEditContext context) {
    final normalized = backendId.trim();
    if (normalized.isEmpty) return;
    final data = context.backendConfigResource.value;
    if (normalized == data.globalBackendId) return;
    final backends = data.availableBackends;
    final backend = backends.isEmpty
        ? LiveEditAgentBackend(
            id: normalized,
            label: fallbackBackendLabel(normalized),
            description: '',
            available: true,
          )
        : backends.firstWhere(
            (final b) => b.id == normalized,
            orElse: () => LiveEditAgentBackend(
              id: normalized,
              label: fallbackBackendLabel(normalized),
              description: '',
              available: true,
            ),
          );
    if (!backend.available) return;
    final config = backendEffectiveConfig(backend);
    final nextConfig = Map<String, LiveEditInferenceConfig>.from(
      data.inferenceConfigByBackendId,
    );
    if (config != null) {
      nextConfig.putIfAbsent(normalized, () => config);
    }
    context.backendConfigResource.value = data.copyWith(
      globalBackendId: normalized,
      inferenceConfigByBackendId: nextConfig,
    );
  }
}
