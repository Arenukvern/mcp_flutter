import '../../live_edit_context.dart';
import '../../live_edit_controller_adapter.dart';
import '../../selectors/live_edit_selectors.dart';
import '_selection_commands_shared.dart';

final class SelectCandidateAtCommand {
  SelectCandidateAtCommand({required this.controller, required this.index});

  final LiveEditController controller;
  final int index;

  void execute(final LiveEditContext context) {
    final sessionId = context.sessionResource.value.activeSessionId;
    if (sessionId == null) return;
    final presentationLayer = selectPresentedLayer(context);
    final candidates = controller.selectionCandidatesForDomain(
      targetDomain: presentationLayer,
      sessionId: sessionId,
    );
    if (index < 0 || index >= candidates.length) return;
    context.sessionService.selectCandidate(
      sessionId: sessionId,
      index: index,
      targetDomain: presentationLayer,
    );
    context.applySessionUpdate(context.sessionService.lastUpdate);
    runAfterSelectionChange(context, controller);
  }
}
