import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../live_edit_context.dart';
import '../live_edit_types.dart';
import 'expand_panel.cmd.dart';
import 'set_overlay_enabled.cmd.dart';
import 'set_target_domain.cmd.dart';
import 'start_session.cmd.dart';

/// Prefills overlay, panel, and one demo bubble for
/// [live_edit_tooling_ui_kit]. Run once when scope is ready.
final class PrefillToolingShowcaseCommand {
  const PrefillToolingShowcaseCommand();

  void execute(final LiveEditContext context) {
    StartSessionCommand(
      targetDomain: LiveEditTargetDomain.toolScene,
    ).execute(context);
    final sessionId = context.sessionResource.value.activeSessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    SetOverlayEnabledCommand(enabled: true).execute(context);
    ExpandPanelCommand().execute(context);

    const bubbleId = 'showcase:tool-layer';
    final selection = LiveEditSelection(
      sessionId: sessionId,
      nodeId: 'showcase_bubble',
      widgetType: 'SelectionBubble',
      propertiesForWire: const <Object?>[],
      rawNode: const <String, Object?>{'surfaceId': 'ai_bubble'},
      targetDomain: LiveEditTargetDomain.toolScene,
      bounds: const LiveEditBounds(
        left: 24,
        top: 100,
        right: 324,
        bottom: 340,
        width: 300,
        height: 240,
      ),
    );
    final record = LiveEditBubbleRecord(
      bubbleId: bubbleId,
      targetDomain: LiveEditTargetDomain.toolScene,
      targetKey: 'SelectionBubble',
      primarySelection: selection,
      selectedWidgets: <LiveEditSelection>[selection],
      instructionText: 'Prefilled prompt for tooling UI development.',
    );
    final records = Map<String, LiveEditBubbleRecord>.from(
      context.bubbleResource.value.bubbleRecordsById,
    );
    records[bubbleId] = record;
    final layerMap = Map<LiveEditTargetDomain, LiveEditLayerViewState>.from(
      context.bubbleResource.value.layerViewStateByDomain,
    );
    layerMap[LiveEditTargetDomain.toolScene] =
        (layerMap[LiveEditTargetDomain.toolScene] ?? LiveEditLayerViewState())
            .copyWith(activeBubbleId: bubbleId, editMode: LiveEditEditMode.ai);
    context.bubbleResource.value = context.bubbleResource.value.copyWith(
      bubbleRecordsById: records,
      layerViewStateByDomain: layerMap,
    );

    SetTargetDomainCommand(
      targetDomain: LiveEditTargetDomain.appScene,
      sessionId: sessionId,
    ).execute(context);
  }
}
