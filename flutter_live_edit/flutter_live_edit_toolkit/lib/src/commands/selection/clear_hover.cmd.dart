import '../../live_edit_context.dart';

final class ClearHoverCommand {
  ClearHoverCommand({this.sessionId});

  final String? sessionId;

  void execute(final LiveEditContext context) {
    context.sessionService.clearHover(
      sessionId: sessionId ?? context.sessionResource.value.activeSessionId,
    );
    context.applySessionUpdate(context.sessionService.lastUpdate);
  }
}
