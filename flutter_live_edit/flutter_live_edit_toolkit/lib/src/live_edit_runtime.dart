import 'live_edit_context.dart';

/// MCP and toolkit accessor for the current [LiveEditContext].
/// Set by the host (e.g. [LiveEditOrchestrator]) when the live-edit subtree is built.
abstract final class LiveEditRuntime {
  LiveEditRuntime._();

  static LiveEditContext? Function()? _contextAccessor;

  /// Returns the current live-edit context, or null if none is registered.
  static LiveEditContext? get currentContext => _contextAccessor?.call();

  /// Registers the accessor that returns the current context (e.g. from [LiveEditOrchestrator]).
  static set contextAccessor(final LiveEditContext? Function()? value) {
    _contextAccessor = value;
  }
}
