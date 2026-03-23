import '../../di_live_edit_context/live_edit_context.dart';
import '../../models/models.dart';

/// Returns the widget tree for the session/domain.
final class GetTreeCommand {
  GetTreeCommand({this.sessionId, this.targetDomain});

  final String? sessionId;
  final LiveEditTargetDomain? targetDomain;

  Map<String, Object?> execute(final LiveEditContext context) => context
      .sessionService
      .getTree(sessionId: sessionId, targetDomain: targetDomain);
}
