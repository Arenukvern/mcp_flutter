import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../../ai/backend/live_edit_backend_utils.dart';
import '../../di_live_edit_context/live_edit_context.dart';
import '../../di_live_edit_context/tools/live_edit_controller_adapter.dart';
import '../shared/live_edit_selectors_shared.dart';

LiveEditAgentBackend? selectBackendForBubble(
  final LiveEditContext ctx,
  final String? bubbleId,
) {
  final bubbleBackendId = selectBubbleRecord(ctx, bubbleId)?.backendId?.trim();
  final globalId = ctx.backendConfigResource.value.globalBackendId?.trim();
  final backendId = hasText(bubbleBackendId) ? bubbleBackendId : globalId;
  if (!hasText(backendId)) return null;
  for (final b in ctx.backendConfigResource.value.availableBackends) {
    if (b.id == backendId) return b;
  }
  return null;
}

String? selectBackendIdForBubble(
  final LiveEditContext ctx,
  final String? bubbleId,
) {
  final bubbleBackendId = selectBubbleRecord(ctx, bubbleId)?.backendId?.trim();
  if (hasText(bubbleBackendId)) return bubbleBackendId;
  final globalBackendId = ctx.backendConfigResource.value.globalBackendId
      ?.trim();
  return hasText(globalBackendId) ? globalBackendId : null;
}

LiveEditAgentBackend? selectCurrentBackend(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) => selectBackendForBubble(
  ctx,
  selectActiveBubbleId(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  ),
);

String? selectCurrentBackendId(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final bubbleId = selectActiveBubbleId(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  final bid = selectBubbleRecord(ctx, bubbleId)?.backendId?.trim();
  if (hasText(bid)) return bid;
  return ctx.backendConfigResource.value.globalBackendId;
}

LiveEditInferenceConfig? selectInferenceConfigForBubble(
  final LiveEditContext ctx,
  final String? bubbleId,
) {
  final bubble = selectBubbleRecord(ctx, bubbleId);
  if (bubble?.inferenceConfig != null) return bubble!.inferenceConfig;
  final backend = selectBackendForBubble(ctx, bubbleId);
  if (backend == null) return null;
  return ctx.backendConfigResource.value.inferenceConfigByBackendId[backend
          .id] ??
      backendEffectiveConfig(backend);
}

LiveEditInferenceConfig? selectCurrentInferenceConfig(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) => selectInferenceConfigForBubble(
  ctx,
  selectActiveBubbleId(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  ),
);

String? selectCurrentModel(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) => selectCurrentInferenceConfig(
  ctx,
  controller,
  presentationDomain: presentationDomain,
  sessionId: sessionId,
)?.model;

String? selectCurrentBackendLabel(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final backend = selectCurrentBackend(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  if (backend?.label.trim().isNotEmpty == true) return backend!.label;
  final bid = selectCurrentBackendId(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  return hasText(bid) ? fallbackBackendLabel(bid!) : 'AI agent';
}

String? selectCurrentReasoningEffort(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) => selectCurrentInferenceConfig(
  ctx,
  controller,
  presentationDomain: presentationDomain,
  sessionId: sessionId,
)?.reasoningEffort;

bool selectCurrentBackendUsesFreeformModel(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) =>
    selectCurrentBackend(
      ctx,
      controller,
      presentationDomain: presentationDomain,
      sessionId: sessionId,
    )?.id ==
    'cursor_agent';

List<LiveEditCodexModelOption> selectCurrentSupportedModels(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final backend = selectCurrentBackend(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  if (backend == null || backend.id != 'codex_exec') {
    return const <LiveEditCodexModelOption>[];
  }
  final models = backend.meta['supportedModels'];
  if (models is! List) return LiveEditCodexOptions.supportedModels;
  return models
      .whereType<Map>()
      .map(
        (final item) => LiveEditCodexModelOption.fromJson(
          item.map((final key, final value) => MapEntry('$key', value)),
        ),
      )
      .toList(growable: false);
}

List<String> selectCurrentSupportedReasoningEfforts(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final backend = selectCurrentBackend(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  if (backend == null || backend.id != 'codex_exec') {
    return const <String>[];
  }
  final efforts = backend.meta['supportedReasoningEfforts'];
  if (efforts is! List) return LiveEditCodexOptions.supportedReasoningEfforts;
  return efforts.map((final item) => '$item').toList(growable: false);
}
