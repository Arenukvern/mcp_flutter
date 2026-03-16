import '../live_edit_context.dart';

final class StartMarqueeCommand {
  StartMarqueeCommand({required this.x, required this.y, this.sessionId});

  final int x;
  final int y;
  final String? sessionId;

  void execute(final LiveEditContext context) {
    context.sessionService.startMarquee(
      x: x,
      y: y,
      sessionId: sessionId ?? context.sessionResource.value.activeSessionId,
    );
    context.applySessionUpdate(context.sessionService.lastUpdate);
  }
}
