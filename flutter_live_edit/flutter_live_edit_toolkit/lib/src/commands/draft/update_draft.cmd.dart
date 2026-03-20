import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../../live_edit_context.dart';

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
