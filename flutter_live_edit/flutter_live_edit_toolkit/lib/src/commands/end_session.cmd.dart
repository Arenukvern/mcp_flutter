import '../live_edit_context.dart';

/// Ends a live edit session.
final class EndSessionCommand {
  EndSessionCommand({this.sessionId});

  final String? sessionId;

  Map<String, Object?> execute(final LiveEditContext context) {
    final result = context.sessionService.endSession(sessionId: sessionId);
    context.applySessionUpdate(context.sessionService.lastUpdate);
    return result;
  }
}
