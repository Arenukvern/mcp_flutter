/// Service-extension names the Flutter MCP toolkit registers in the app
/// (prefix `ext.mcp.toolkit.` + verb).
///
/// Source of truth: `mcp_toolkit/lib/src/toolkits/interaction_toolkit.dart`
/// — the app side registers these verbs at binding time, and this driver
/// calls them over the VM service. Keep the two lists in lockstep; follow-up
/// work routes the toolkit's registration literals through a shared core
/// constants file so the compiler enforces it.
abstract final class ToolkitExtensions {
  static const String prefix = 'ext.mcp.toolkit';

  /// Semantic snapshot of the visible widget tree.
  static const String snapshot = '$prefix.semantic_snapshot';

  /// Taps a widget by snapshot ref.
  static const String tap = '$prefix.tap_widget';

  /// Enters text into a widget by snapshot ref.
  static const String enterText = '$prefix.enter_text';

  /// Scrolls (by direction or to a ref).
  static const String scroll = '$prefix.scroll';

  /// Long-presses a widget by snapshot ref.
  static const String longPress = '$prefix.long_press';

  /// Swipes between coordinates.
  static const String swipe = '$prefix.swipe';

  /// Drags from one widget/point to another.
  static const String drag = '$prefix.drag';

  /// Presses a keyboard key.
  static const String pressKey = '$prefix.press_key';

  /// Waits until a condition (label visible, …) holds.
  static const String waitFor = '$prefix.wait_for';

  /// Recent app logs (toolkit-buffered).
  static const String getRecentLogs = '$prefix.get_recent_logs';

  /// Navigates a route.
  static const String navigate = '$prefix.navigate';

  /// Handles a native dialog.
  static const String handleDialog = '$prefix.handle_dialog';

  /// Hovers a position (desktop/web).
  static const String hover = '$prefix.hover';

  /// Focuses a widget by snapshot ref.
  static const String focusWidget = '$prefix.focus_widget';

  /// Reveals the search field.
  static const String revealSearch = '$prefix.reveal_search';
}
