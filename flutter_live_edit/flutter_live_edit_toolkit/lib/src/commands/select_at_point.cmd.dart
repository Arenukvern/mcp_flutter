import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../live_edit_context.dart';

/// Selects a widget at the given point.
final class SelectAtPointCommand {
  SelectAtPointCommand({
    required this.x,
    required this.y,
    this.sessionId,
    this.viewId,
    this.selectionPolicy = LiveEditSelectionPolicy.deepest,
    this.targetDomain,
  });

  final String? sessionId;
  final int x;
  final int y;
  final int? viewId;
  final LiveEditSelectionPolicy selectionPolicy;
  final LiveEditTargetDomain? targetDomain;

  Map<String, Object?> execute(final LiveEditContext context) {
    final result = context.sessionService.selectAtPoint(
      sessionId: sessionId,
      x: x,
      y: y,
      viewId: viewId,
      selectionPolicy: selectionPolicy,
      targetDomain: targetDomain,
    );
    context.applySessionUpdate(context.sessionService.lastUpdate);
    return result;
  }
}
