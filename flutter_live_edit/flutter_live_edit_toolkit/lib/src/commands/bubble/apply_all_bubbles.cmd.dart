import '../../di_live_edit_context/live_edit_context.dart';
import '../../models/models.dart';
import '../draft/apply_draft.cmd.dart';

/// Applies all bubbles (apply mode apply_all).
final class ApplyAllBubblesCommand {
  ApplyAllBubblesCommand({
    this.workingDirectory,
    this.intentText,
    this.globalBackendId,
  });

  final String? workingDirectory;
  final String? intentText;
  final String? globalBackendId;

  Future<void> execute(final LiveEditContext context) async {
    await ApplyDraftCommand(
      applyMode: LiveEditApplyMode.applyAll,
      workingDirectory: workingDirectory,
      intentText: intentText,
      globalBackendId: globalBackendId,
    ).execute(context);
  }
}
