import '../../di_live_edit_context/live_edit_context.dart';
import '../../models/models.dart';

/// Returns current draft changes for the session/domain.
final class GetDraftCommand {
  GetDraftCommand({this.sessionId, this.targetDomain});

  final String? sessionId;
  final LiveEditTargetDomain? targetDomain;

  Map<String, Object?> execute(final LiveEditContext context) => context
      .sessionService
      .getDraft(sessionId: sessionId, targetDomain: targetDomain);
}
