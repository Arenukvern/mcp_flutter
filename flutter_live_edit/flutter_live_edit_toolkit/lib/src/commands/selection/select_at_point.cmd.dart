import 'package:flutter/widgets.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../../di_live_edit_context/live_edit_context.dart';
import '../../di_live_edit_context/tools/live_edit_controller_adapter.dart';
import '_selection_commands_shared.dart';

/// Selects a widget at the given point.
final class SelectAtPointCommand {
  SelectAtPointCommand({
    required this.x,
    required this.y,
    this.sessionId,
    this.viewId,
    this.contentRoot,
    this.preferHoverPreview = false,
    this.selectionPolicy = LiveEditSelectionPolicy.deepest,
    this.targetDomain,
  });

  final String? sessionId;
  final int x;
  final int y;
  final int? viewId;
  final Element? contentRoot;
  final bool preferHoverPreview;
  final LiveEditSelectionPolicy selectionPolicy;
  final LiveEditTargetDomain? targetDomain;

  Map<String, Object?> execute(final LiveEditContext context) {
    final domain = targetDomain ?? context.sessionResource.value.targetDomain;
    final result = context.sessionService.selectAtPoint(
      sessionId: sessionId,
      x: x,
      y: y,
      viewId: viewId,
      contentRoot: contentRoot,
      preferHoverPreview: preferHoverPreview,
      selectionPolicy: selectionPolicy,
      targetDomain: targetDomain,
    );
    context.applySessionUpdate(context.sessionService.lastUpdate);
    runAfterSelectionChange(context, LiveEditController(context));
    if (domain == LiveEditTargetDomain.toolScene) {
      context.panelViewResource.value = context.panelViewResource.value
          .copyWith(toolPresentationArmed: true);
    }
    return result;
  }
}
