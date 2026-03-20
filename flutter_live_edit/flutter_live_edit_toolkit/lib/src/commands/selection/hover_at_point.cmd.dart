import 'package:flutter/widgets.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../../live_edit_context.dart';

final class HoverAtPointCommand {
  HoverAtPointCommand({
    required this.x,
    required this.y,
    this.sessionId,
    this.viewId,
    this.contentRoot,
    this.targetDomain,
    this.deeperMode = false,
  });

  final int x;
  final int y;
  final String? sessionId;
  final int? viewId;
  final Element? contentRoot;
  final LiveEditTargetDomain? targetDomain;
  final bool deeperMode;

  Map<String, Object?> execute(final LiveEditContext context) {
    final result = context.sessionService.hoverAtPoint(
      x: x,
      y: y,
      sessionId: sessionId ?? context.sessionResource.value.activeSessionId,
      viewId: viewId,
      contentRoot: contentRoot,
      targetDomain: targetDomain ?? context.sessionResource.value.targetDomain,
      deeperMode: deeperMode,
    );
    context.applySessionUpdate(context.sessionService.lastUpdate);
    return result;
  }
}
