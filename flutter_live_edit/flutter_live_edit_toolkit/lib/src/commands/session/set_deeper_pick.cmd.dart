import '../../di_live_edit_context/live_edit_context.dart';

/// Sets deeper pick (hover) on/off.
final class SetDeeperPickCommand {
  SetDeeperPickCommand({required this.enabled});

  final bool enabled;

  void execute(final LiveEditContext context) {
    context.panelViewResource.value = context.panelViewResource.value.copyWith(
      deeperPickEnabled: enabled,
    );
  }
}
