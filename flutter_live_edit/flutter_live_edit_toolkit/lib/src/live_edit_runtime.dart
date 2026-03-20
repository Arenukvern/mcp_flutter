import 'di_live_edit_context/live_edit_context.dart';
import 'services/services.dart';

/// MCP and toolkit accessor for the current [LiveEditContext].
/// Set by the host (e.g. [LiveEditOrchestrator]) or [LiveEditScope] when built.
abstract final class LiveEditRuntime {
  LiveEditRuntime._();

  static LiveEditContext? Function()? _contextAccessor;

  /// Optional registration: when a [LiveEditSessionService] is created (by host
  /// or scope), this is called so the property-edit plugin can set its provider.
  static void Function(LiveEditSessionService)? onSessionServiceCreated;

  /// Returns the current live-edit context, or null if none is registered.
  static LiveEditContext? get currentContext => _contextAccessor?.call();

  /// Registers the accessor that returns the current context.
  static set contextAccessor(final LiveEditContext? Function()? value) {
    _contextAccessor = value;
  }
}
