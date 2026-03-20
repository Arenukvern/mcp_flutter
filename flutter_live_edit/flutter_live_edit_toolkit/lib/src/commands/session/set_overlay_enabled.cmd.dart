import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../../live_edit_context.dart';
import '../../live_edit_types.dart';
import '../panel/collapse_panel.cmd.dart';
import 'set_edit_mode.cmd.dart';
import 'start_session.cmd.dart';

/// Ensures a session exists and enables or disables the overlay.
/// When disabling, also resets edit mode, collapses panel, and clears bubble state.
final class SetOverlayEnabledCommand {
  SetOverlayEnabledCommand({required this.enabled});

  final bool enabled;

  void execute(final LiveEditContext context) {
    if (context.sessionResource.value.activeSessionId == null) {
      StartSessionCommand(
        targetDomain: context.sessionResource.value.targetDomain,
      ).execute(context);
    }
    final sessionId = context.sessionResource.value.activeSessionId!;
    context.sessionService.setOverlay(sessionId: sessionId, enabled: enabled);
    context.applySessionUpdate(context.sessionService.lastUpdate);
    if (!enabled) {
      SetEditModeCommand(editMode: LiveEditEditMode.inspect).execute(context);
      CollapsePanelCommand().execute(context);
      context.bubbleResource.value = context.bubbleResource.value.copyWith(
        globalComposerText: '',
        applyPhase: LiveEditApplyPhase.idle,
      );
      context.panelViewResource.value = context.panelViewResource.value
          .copyWith(toolPresentationArmed: false);
    }
  }
}
