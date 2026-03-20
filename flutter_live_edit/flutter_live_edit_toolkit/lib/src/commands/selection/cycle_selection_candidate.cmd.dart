import '../../live_edit_context.dart';
import '../../live_edit_controller_adapter.dart';
import '../../selectors/live_edit_selectors.dart';
import '_selection_commands_shared.dart';

final class CycleSelectionCandidateCommand {
  CycleSelectionCandidateCommand({
    required this.controller,
    required this.delta,
  });

  final LiveEditController controller;
  final int delta;

  void execute(final LiveEditContext context) {
    final sessionId = context.sessionResource.value.activeSessionId;
    if (sessionId == null) return;
    final presentationLayer = selectPresentedLayer(context);
    final candidates = controller.selectionCandidatesForDomain(
      targetDomain: presentationLayer,
      sessionId: sessionId,
    );
    if (candidates.isEmpty) return;
    final activeIndex = candidates.indexWhere((final c) => c.active);
    final nextIndex = activeIndex < 0
        ? 0
        : (activeIndex + delta + candidates.length) % candidates.length;
    context.sessionService.selectCandidate(
      sessionId: sessionId,
      index: nextIndex,
      targetDomain: presentationLayer,
    );
    context.applySessionUpdate(context.sessionService.lastUpdate);
    runAfterSelectionChange(context, controller);
  }
}
