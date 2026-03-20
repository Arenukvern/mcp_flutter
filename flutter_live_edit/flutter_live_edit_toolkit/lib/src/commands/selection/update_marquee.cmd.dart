import 'package:flutter/widgets.dart';

import '../../live_edit_context.dart';

final class UpdateMarqueeCommand {
  UpdateMarqueeCommand({
    required this.x,
    required this.y,
    this.sessionId,
    this.viewId,
    this.contentRoot,
  });

  final int x;
  final int y;
  final String? sessionId;
  final int? viewId;
  final Element? contentRoot;

  void execute(final LiveEditContext context) {
    context.sessionService.updateMarquee(
      x: x,
      y: y,
      sessionId: sessionId ?? context.sessionResource.value.activeSessionId,
      viewId: viewId,
      contentRoot: contentRoot,
    );
    context.applySessionUpdate(context.sessionService.lastUpdate);
  }
}
