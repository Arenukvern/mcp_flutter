import '../../di_live_edit_context/live_edit_context.dart';
import '../../models/models.dart';

/// Starts or reuses a live edit session.
final class StartSessionCommand {
  StartSessionCommand({
    this.requestedSessionId,
    this.targetDomain = LiveEditTargetDomain.appScene,
  });

  final String? requestedSessionId;
  final LiveEditTargetDomain targetDomain;

  /// Runs the command; applies session update to context resources.
  /// Returns the raw result map for MCP callers.
  Map<String, Object?> execute(final LiveEditContext context) {
    final result = context.sessionService.startSession(
      requestedSessionId: requestedSessionId,
      targetDomain: targetDomain,
    );
    context.applySessionUpdate(context.sessionService.lastUpdate);
    return result;
  }
}
