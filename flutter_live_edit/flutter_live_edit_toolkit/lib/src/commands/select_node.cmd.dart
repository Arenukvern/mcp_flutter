import 'package:flutter/widgets.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../live_edit_context.dart';
import '../live_edit_controller_adapter.dart';
import '_selection_commands_shared.dart';
import 'open_ai_bubble.cmd.dart';
import 'select_at_point.cmd.dart';
import 'start_session.cmd.dart';

/// Selects at point, syncs bubble state, optionally opens AI bubble.
final class SelectNodeCommand {
  SelectNodeCommand({
    required this.x,
    required this.y,
    required this.controller,
    this.contentRoot,
    this.preferHoverPreview = false,
    this.targetDomain,
    this.openBubbleOnSelect = false,
    this.selectionPolicy = LiveEditSelectionPolicy.nearestProjectAncestor,
  });

  final int x;
  final int y;
  final LiveEditController controller;
  final Element? contentRoot;
  final bool preferHoverPreview;
  final LiveEditTargetDomain? targetDomain;
  final bool openBubbleOnSelect;
  final LiveEditSelectionPolicy selectionPolicy;

  Map<String, Object?> execute(final LiveEditContext context) {
    var sessionId = context.sessionResource.value.activeSessionId;
    if (sessionId == null || sessionId.isEmpty) {
      StartSessionCommand(
        targetDomain:
            targetDomain ?? context.sessionResource.value.targetDomain,
      ).execute(context);
      sessionId = context.sessionResource.value.activeSessionId;
    }
    if (sessionId == null) return <String, Object?>{};
    SelectAtPointCommand(
      x: x,
      y: y,
      sessionId: sessionId,
      targetDomain: targetDomain,
      contentRoot: contentRoot,
      preferHoverPreview: preferHoverPreview,
      selectionPolicy: selectionPolicy,
    ).execute(context);
    runAfterSelectionChange(context, controller);
    if (openBubbleOnSelect &&
        context.sessionResource.value.activeSessionId != null) {
      final domain = targetDomain ?? context.sessionResource.value.targetDomain;
      final selection = controller.selectionForDomain(
        targetDomain: domain,
        sessionId: sessionId,
      );
      if (selection != null) {
        OpenAiBubbleCommand(defaultPrompt: '').execute(context);
      }
    }
    return <String, Object?>{'sessionId': sessionId};
  }
}
