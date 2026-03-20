import '../../di_live_edit_context/live_edit_context.dart';
import '../../types/live_edit_types.dart';

/// Toggles panel between rail and expanded.
final class TogglePanelDisplayModeCommand {
  void execute(final LiveEditContext context) {
    final current = context.panelViewResource.value.panelDisplayMode;
    final next = current == LiveEditPanelDisplayMode.expanded
        ? LiveEditPanelDisplayMode.rail
        : LiveEditPanelDisplayMode.expanded;
    context.panelViewResource.value = context.panelViewResource.value.copyWith(
      panelDisplayMode: next,
    );
  }
}
