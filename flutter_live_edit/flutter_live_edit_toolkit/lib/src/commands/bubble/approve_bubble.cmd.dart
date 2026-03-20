import '../../di_live_edit_context/live_edit_context.dart';
import '../draft/apply_draft.cmd.dart';

/// Applies draft with approve flag (approval flow).
final class ApproveBubbleCommand {
  ApproveBubbleCommand({
    this.bubbleId,
    this.message,
    this.workingDirectory,
    this.intentText,
    this.globalBackendId,
  });

  final String? bubbleId;
  final String? message;
  final String? workingDirectory;
  final String? intentText;
  final String? globalBackendId;

  Future<void> execute(final LiveEditContext context) async {
    await ApplyDraftCommand(
      bubbleId: bubbleId,
      message: message,
      approve: true,
      workingDirectory: workingDirectory,
      intentText: intentText,
      globalBackendId: globalBackendId,
    ).execute(context);
  }
}
