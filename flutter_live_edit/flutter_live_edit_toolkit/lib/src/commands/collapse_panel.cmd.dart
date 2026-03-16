import '../live_edit_context.dart';
import '../live_edit_types.dart';

/// Sets panel display mode to rail.
final class CollapsePanelCommand {
  void execute(final LiveEditContext context) {
    context.panelViewResource.value = context.panelViewResource.value
        .copyWith(panelDisplayMode: LiveEditPanelDisplayMode.rail);
  }
}
