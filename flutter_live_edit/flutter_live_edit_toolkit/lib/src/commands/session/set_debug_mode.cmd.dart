import '../../live_edit_context.dart';

/// Sets debug mode on/off.
final class SetDebugModeCommand {
  SetDebugModeCommand({required this.enabled});

  final bool enabled;

  void execute(final LiveEditContext context) {
    context.panelViewResource.value = context.panelViewResource.value.copyWith(
      debugModeEnabled: enabled,
    );
  }
}
