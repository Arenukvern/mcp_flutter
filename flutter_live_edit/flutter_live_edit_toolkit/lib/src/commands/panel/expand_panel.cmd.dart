import '../../di_live_edit_context/live_edit_context.dart';
import '../../types/live_edit_types.dart';

/// Sets panel display mode to expanded.
final class ExpandPanelCommand {
  void execute(final LiveEditContext context) {
    context.panelViewResource.value = context.panelViewResource.value.copyWith(
      panelDisplayMode: LiveEditPanelDisplayMode.expanded,
    );
  }
}
