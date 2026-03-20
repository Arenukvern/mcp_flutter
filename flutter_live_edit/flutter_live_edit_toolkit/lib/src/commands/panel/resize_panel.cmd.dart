import '../../live_edit_context.dart';
import '../../live_edit_types.dart';

/// Updates panel dimensions (expanded or rail based on current mode).
final class ResizePanelCommand {
  ResizePanelCommand({required this.width, required this.height});

  final double width;
  final double height;

  void execute(final LiveEditContext context) {
    final p = context.panelViewResource.value;
    final expanded = p.panelDisplayMode == LiveEditPanelDisplayMode.expanded;
    context.panelViewResource.value = expanded
        ? p.copyWith(
            panelExpandedWidth: width.clamp(240, 640),
            panelExpandedHeight: height.clamp(320, 760),
          )
        : p.copyWith(
            panelRailWidth: width.clamp(56, 160),
            panelRailHeight: height.clamp(220, 760),
          );
  }
}
