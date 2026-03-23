import '../../di_live_edit_context/live_edit_context.dart';
import '../../models/models.dart';

/// Updates one draft change.
final class UpdateDraftCommand {
  UpdateDraftCommand({required this.change, this.sessionId});

  final String? sessionId;
  final LiveEditDraftChange change;

  Map<String, Object?> execute(final LiveEditContext context) {
    final result = context.sessionService.updateDraft(
      sessionId: sessionId,
      change: change,
    );
    context.applySessionUpdate(context.sessionService.lastUpdate);
    return result;
  }
}
