/// Canonical names of the `ext.mcp.toolkit.*` VM service extensions the
/// toolkit registers in a running app.
///
/// Single source of truth for both sides of the wire: `mcp_toolkit`
/// registers every entry under these exact verbs, and harness/agent
/// clients call them by the same constants. Hand-mirroring the names in
/// a second package was the drift risk this file exists to kill — a
/// typo here is a compile error there, not a runtime -32601.
abstract final class ToolkitExtensionNames {
  /// Service-extension prefix; each verb is registered as
  /// `$prefix.$verb`.
  static const String prefix = 'ext.mcp.toolkit';

  /// Semantic snapshot of the visible widget tree.
  static const String semanticSnapshot = 'semantic_snapshot';

  /// Taps a widget by snapshot ref.
  static const String tapWidget = 'tap_widget';

  /// Enters text into a widget by snapshot ref.
  static const String enterText = 'enter_text';

  /// Scrolls (by direction or to a ref).
  static const String scroll = 'scroll';

  /// Long-presses a widget by snapshot ref.
  static const String longPress = 'long_press';

  /// Swipes between coordinates.
  static const String swipe = 'swipe';

  /// Drags from one widget/point to another.
  static const String drag = 'drag';

  /// Presses a keyboard key.
  static const String pressKey = 'press_key';

  /// Waits until a condition (label visible, …) holds.
  static const String waitFor = 'wait_for';

  /// Recent app logs (toolkit-buffered).
  static const String getRecentLogs = 'get_recent_logs';

  /// Navigates a route.
  static const String navigate = 'navigate';

  /// Handles a native dialog.
  static const String handleDialog = 'handle_dialog';

  /// Hovers a position (desktop/web).
  static const String hover = 'hover';

  /// Focuses a widget by snapshot ref.
  static const String focusWidget = 'focus_widget';

  /// Reveals the search field.
  static const String revealSearch = 'reveal_search';

  /// Base64 screenshots of all views.
  static const String viewScreenshots = 'view_screenshots';

  /// Detailed information for Flutter views and widget tree.
  static const String viewDetails = 'view_details';

  /// Recent app errors with stack traces.
  static const String appErrors = 'app_errors';

  /// App identity metadata.
  static const String appIdentity = 'app_identity';

  /// Inspects the widget at a screen point.
  static const String inspectWidgetAtPoint = 'inspect_widget_at_point';
}
