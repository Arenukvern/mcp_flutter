import '../live_edit_context.dart';
import '../live_edit_controller_adapter.dart';
import '_selection_commands_shared.dart';

final class CommitMarqueeCommand {
  CommitMarqueeCommand({required this.controller, this.sessionId});

  final LiveEditController controller;
  final String? sessionId;

  void execute(final LiveEditContext context) {
    final sid =
        sessionId ?? context.sessionResource.value.activeSessionId;
    context.sessionService.commitMarquee(sessionId: sid);
    context.applySessionUpdate(context.sessionService.lastUpdate);
    runAfterSelectionChange(context, controller);
  }
}
