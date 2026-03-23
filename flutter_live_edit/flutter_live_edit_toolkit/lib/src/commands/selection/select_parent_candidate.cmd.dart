import '../../di_live_edit_context/live_edit_context.dart';
import '../../di_live_edit_context/tools/live_edit_controller_adapter.dart';
import '../../ui_selectors/ui_selectors.dart';
import '_selection_commands_shared.dart';

final class SelectParentCandidateCommand {
  SelectParentCandidateCommand({required this.controller});

  final LiveEditController controller;

  void execute(final LiveEditContext context) {
    final sessionId = context.sessionResource.value.activeSessionId;
    if (sessionId == null) return;
    final presentationLayer = selectPresentedLayer(context);
    context.sessionService.selectParent(
      sessionId: sessionId,
      targetDomain: presentationLayer,
    );
    context.applySessionUpdate(context.sessionService.lastUpdate);
    runAfterSelectionChange(context, controller);
  }
}
