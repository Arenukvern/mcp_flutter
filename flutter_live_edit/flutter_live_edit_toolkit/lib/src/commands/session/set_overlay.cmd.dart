import '../../di_live_edit_context/live_edit_context.dart';

/// Enables or disables the live edit overlay.
final class SetOverlayCommand {
  SetOverlayCommand({required this.enabled, this.sessionId});

  final String? sessionId;
  final bool enabled;

  Map<String, Object?> execute(final LiveEditContext context) {
    final result = context.sessionService.setOverlay(
      sessionId: sessionId,
      enabled: enabled,
    );
    context.applySessionUpdate(context.sessionService.lastUpdate);
    return result;
  }
}
