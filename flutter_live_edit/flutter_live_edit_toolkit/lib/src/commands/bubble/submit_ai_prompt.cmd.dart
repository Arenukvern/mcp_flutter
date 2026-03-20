import '../../di_live_edit_context/live_edit_context.dart';
import '../../di_live_edit_context/tools/live_edit_controller_adapter.dart';
import '../../selectors/live_edit_selectors.dart';
import '../draft/apply_draft.cmd.dart';
import '../backend/open_ai_bubble.cmd.dart';

/// Opens AI bubble with default prompt and applies draft with composer text.
final class SubmitAiPromptCommand {
  SubmitAiPromptCommand({required this.controller, this.intentText});

  final LiveEditController controller;
  final String? intentText;

  Future<void> execute(final LiveEditContext context) async {
    final ctrl = controller;
    final presentationDomain = selectPresentedLayer(context);
    final sessionId = context.sessionResource.value.activeSessionId;
    final defaultPrompt = selectDefaultAiPrompt(
      context,
      ctrl,
      intentText: intentText,
      presentationDomain: presentationDomain,
      sessionId: sessionId,
    );
    OpenAiBubbleCommand(defaultPrompt: defaultPrompt).execute(context);
    if (!selectCanSubmitAiPrompt(
      context,
      ctrl,
      presentationDomain: presentationDomain,
      sessionId: sessionId,
    )) {
      return;
    }
    final activeBubbleId = selectActiveBubbleId(
      context,
      ctrl,
      presentationDomain: presentationDomain,
      sessionId: sessionId,
    );
    final message = selectInstructionTextForBubble(context, activeBubbleId);
    await ApplyDraftCommand(
      message: message.trim().isNotEmpty ? message : null,
      globalBackendId: context.backendConfigResource.value.globalBackendId,
    ).execute(context);
  }
}
