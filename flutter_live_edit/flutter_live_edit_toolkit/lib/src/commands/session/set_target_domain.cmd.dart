import '../../di_live_edit_context/live_edit_context.dart';
import '../../models/models.dart';

/// Sets the target domain for the session.
final class SetTargetDomainCommand {
  SetTargetDomainCommand({required this.targetDomain, this.sessionId});

  final String? sessionId;
  final LiveEditTargetDomain targetDomain;

  Map<String, Object?> execute(final LiveEditContext context) {
    final result = context.sessionService.setTargetDomain(
      sessionId: sessionId,
      targetDomain: targetDomain,
    );
    context.applySessionUpdate(context.sessionService.lastUpdate);
    return result;
  }
}
