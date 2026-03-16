import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import 'live_edit_context.dart';

/// Returns effective inference config from backend meta, or null.
LiveEditInferenceConfig? backendEffectiveConfig(
  final LiveEditAgentBackend backend,
) {
  final effective = backend.meta['effectiveInferenceConfig'];
  if (effective is Map) {
    return LiveEditCodexOptions.normalizeConfig(
      LiveEditInferenceConfig.fromJson(
        effective.map((final key, final value) => MapEntry('$key', value)),
      ),
    );
  }
  final defaults = backend.meta['defaultInferenceConfig'];
  if (defaults is Map) {
    return LiveEditCodexOptions.normalizeConfig(
      LiveEditInferenceConfig.fromJson(
        defaults.map((final key, final value) => MapEntry('$key', value)),
      ),
    );
  }
  return null;
}

/// Resolves initial global backend id from available backends and optional requested id.
String? resolveInitialBackendId({
  required final List<LiveEditAgentBackend> availableBackends,
  required final String? backendId,
}) {
  final requested = backendId?.trim();
  if (requested != null && requested.isNotEmpty) {
    if (availableBackends.isEmpty ||
        availableBackends.any((final b) => b.id == requested)) {
      return requested;
    }
  }
  if (availableBackends.isEmpty) return requested;
  return availableBackends
      .firstWhere(
        (final b) => b.isDefault,
        orElse: () => availableBackends.first,
      )
      .id;
}

/// Returns backend label for [bubbleId] using [ctx] resources.
String backendLabelFromContext(
  final LiveEditContext ctx,
  final String? bubbleId,
) {
  final bubbleBackendId = bubbleId != null
      ? ctx.bubbleResource.value.bubbleRecordsById[bubbleId]?.backendId?.trim()
      : null;
  final globalId = ctx.backendConfigResource.value.globalBackendId?.trim();
  final backendId = (bubbleBackendId != null && bubbleBackendId.isNotEmpty)
      ? bubbleBackendId
      : globalId;
  if (backendId == null || backendId.isEmpty) return 'AI agent';
  for (final b in ctx.backendConfigResource.value.availableBackends) {
    if (b.id == backendId) {
      if (b.label.trim().isNotEmpty) return b.label;
      break;
    }
  }
  return fallbackBackendLabel(backendId);
}

String fallbackBackendLabel(final String backendId) =>
    backendId
        .split(RegExp(r'[_\-\s]+'))
        .where((final part) => part.isNotEmpty)
        .map(
          (final part) =>
              '${part.substring(0, 1).toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
