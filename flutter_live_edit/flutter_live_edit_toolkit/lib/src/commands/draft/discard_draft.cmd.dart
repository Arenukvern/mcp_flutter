import '../../di_live_edit_context/live_edit_context.dart';

/// Discards all draft changes for the session.
final class DiscardDraftCommand {
  DiscardDraftCommand({this.sessionId});

  final String? sessionId;

  Map<String, Object?> execute(final LiveEditContext context) {
    final result = context.sessionService.discardDraft(sessionId: sessionId);
    context.applySessionUpdate(context.sessionService.lastUpdate);
    return result;
  }
}
