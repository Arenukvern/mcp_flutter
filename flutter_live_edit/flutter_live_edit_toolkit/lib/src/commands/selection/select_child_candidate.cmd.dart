import '../../live_edit_context.dart';
import '../../live_edit_controller_adapter.dart';
import '../../selectors/live_edit_selectors.dart';
import '_selection_commands_shared.dart';

final class SelectChildCandidateCommand {
  SelectChildCandidateCommand({required this.controller});

  final LiveEditController controller;

  void execute(final LiveEditContext context) {
    final sessionId = context.sessionResource.value.activeSessionId;
    if (sessionId == null) return;
    final presentationLayer = selectPresentedLayer(context);
    context.sessionService.selectChild(
      sessionId: sessionId,
      targetDomain: presentationLayer,
    );
    context.applySessionUpdate(context.sessionService.lastUpdate);
    runAfterSelectionChange(context, controller);
  }
}
