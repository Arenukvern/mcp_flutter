import 'package:flutter/material.dart';

import 'live_edit_context.dart';
import 'live_edit_scope.dart';

/// Extension to obtain [LiveEditContext] from [BuildContext] and run commands.
extension LiveEditContextExtension on BuildContext {
  /// Current live-edit context from [LiveEditScope], or null if no scope.
  LiveEditContext? get liveEditContext => LiveEditScope.maybeOf(this)?.context;

  /// Runs [run] with the current [LiveEditContext]. No-op if no scope.
  void runLiveEdit(void Function(LiveEditContext ctx) run) {
    final ctx = liveEditContext;
    if (ctx != null) run(ctx);
  }
}
