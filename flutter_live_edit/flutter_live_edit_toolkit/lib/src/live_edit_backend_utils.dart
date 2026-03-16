import 'dart:ui' show Offset, Size;

import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import 'live_edit_context.dart';

double _maxDouble(final double left, final double right) =>
    left > right ? left : right;

double _minDouble(final double left, final double right) =>
    left < right ? left : right;

/// Computes default bubble placement from bounds and viewport.
Offset autoBubblePlacement({
  required final LiveEditBounds bounds,
  required final Size viewport,
  required final double bubbleWidth,
  required final double bubbleHeight,
}) {
  const gap = 12.0;
  final rightSpace = viewport.width - bounds.right - 16;
  final leftSpace = bounds.left - 16;
  double left;
  double top = _maxDouble(16, bounds.top);

  if (rightSpace >= bubbleWidth) {
    left = bounds.right + gap;
  } else if (leftSpace >= bubbleWidth) {
    left = bounds.left - bubbleWidth - gap;
  } else {
    left = _minDouble(
      viewport.width - bubbleWidth - 16,
      _maxDouble(16, bounds.left),
    );
    top = _minDouble(viewport.height - bubbleHeight - 16, bounds.bottom + gap);
  }

  top = _minDouble(top, viewport.height - bubbleHeight - 16);
  return Offset(left, _maxDouble(16, top));
}

/// Clamps bubble placement to viewport.
Offset clampBubblePlacement({
  required final Offset placement,
  required final Size viewport,
  required final double bubbleWidth,
  required final double bubbleHeight,
}) {
  final maxLeft = _maxDouble(16, viewport.width - bubbleWidth - 16);
  final maxTop = _maxDouble(16, viewport.height - bubbleHeight - 16);
  return Offset(
    placement.dx.clamp(16, maxLeft),
    placement.dy.clamp(16, maxTop),
  );
}

/// Clamps panel placement to viewport. Used by host/selectors.
Offset clampPanelPlacement({
  required final Offset placement,
  required final Size viewport,
  required final double panelWidth,
  required final double panelHeight,
}) {
  final maxLeft = _maxDouble(16, viewport.width - panelWidth - 16);
  final maxTop = _maxDouble(16, viewport.height - panelHeight - 16);
  return Offset(
    placement.dx.clamp(16, maxLeft),
    placement.dy.clamp(16, maxTop),
  );
}

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

String fallbackBackendLabel(final String backendId) => backendId
    .split(RegExp(r'[_\-\s]+'))
    .where((final part) => part.isNotEmpty)
    .map(
      (final part) =>
          '${part.substring(0, 1).toUpperCase()}${part.substring(1).toLowerCase()}',
    )
    .join(' ');
