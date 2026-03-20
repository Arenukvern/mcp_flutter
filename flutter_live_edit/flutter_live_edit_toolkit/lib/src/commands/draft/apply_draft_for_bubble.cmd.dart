import '../../di_live_edit_context/live_edit_context.dart';
import 'apply_draft.cmd.dart';

/// Applies draft for a specific bubble id.
final class ApplyDraftForBubbleCommand {
  ApplyDraftForBubbleCommand({
    required this.bubbleId,
    this.message,
    this.approve = false,
    this.workingDirectory,
    this.intentText,
    this.globalBackendId,
  });

  final String bubbleId;
  final String? message;
  final bool approve;
  final String? workingDirectory;
  final String? intentText;
  final String? globalBackendId;

  Future<void> execute(final LiveEditContext context) async {
    await ApplyDraftCommand(
      bubbleId: bubbleId,
      message: message,
      approve: approve,
      workingDirectory: workingDirectory,
      intentText: intentText,
      globalBackendId: globalBackendId,
    ).execute(context);
  }
}
