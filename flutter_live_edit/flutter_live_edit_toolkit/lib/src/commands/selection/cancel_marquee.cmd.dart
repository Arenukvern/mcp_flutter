import '../../di_live_edit_context/live_edit_context.dart';

final class CancelMarqueeCommand {
  CancelMarqueeCommand({this.sessionId});

  final String? sessionId;

  void execute(final LiveEditContext context) {
    context.sessionService.cancelMarquee(
      sessionId: sessionId ?? context.sessionResource.value.activeSessionId,
    );
    context.applySessionUpdate(context.sessionService.lastUpdate);
  }
}
