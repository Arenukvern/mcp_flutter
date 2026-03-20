import 'package:flutter/widgets.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../../live_edit_context.dart';
import '../../live_edit_controller_adapter.dart';
import '_selection_commands_shared.dart';
import '../backend/open_ai_bubble.cmd.dart';
import 'select_at_point.cmd.dart';
import '../session/start_session.cmd.dart';

bool _sameSelectionIdentity(
  final LiveEditSelection? left,
  final LiveEditSelection? right,
) {
  if (identical(left, right)) return true;
  if (left == null || right == null) return left == right;
  final leftIds = List<String>.from(left.selectedNodeIds)..sort();
  final rightIds = List<String>.from(right.selectedNodeIds)..sort();
  return left.targetDomain == right.targetDomain &&
      left.nodeId == right.nodeId &&
      left.selectionMode == right.selectionMode &&
      leftIds.length == rightIds.length &&
      !leftIds.asMap().entries.any(
        (final entry) => rightIds[entry.key] != entry.value,
      );
}

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
    final resolvedDomain =
        targetDomain ?? context.sessionResource.value.targetDomain;
    final previousSelection = controller.selectionForDomain(
      targetDomain: resolvedDomain,
      sessionId: sessionId,
    );
    SelectAtPointCommand(
      x: x,
      y: y,
      sessionId: sessionId,
      targetDomain: targetDomain,
      contentRoot: contentRoot,
      preferHoverPreview: preferHoverPreview,
      selectionPolicy: selectionPolicy,
    ).execute(context);
    final nextSelection = controller.selectionForDomain(
      targetDomain: resolvedDomain,
      sessionId: sessionId,
    );
    if (_sameSelectionIdentity(previousSelection, nextSelection)) {
      return <String, Object?>{
        'sessionId': sessionId,
        'selectionChanged': false,
      };
    }
    runAfterSelectionChange(context, controller);
    if (openBubbleOnSelect &&
        context.sessionResource.value.activeSessionId != null) {
      final selection = controller.selectionForDomain(
        targetDomain: resolvedDomain,
        sessionId: sessionId,
      );
      if (selection != null) {
        OpenAiBubbleCommand(defaultPrompt: '').execute(context);
      }
    }
    return <String, Object?>{'sessionId': sessionId, 'selectionChanged': true};
  }
}
