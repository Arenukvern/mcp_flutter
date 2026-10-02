import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart'
    as core;

/// Service-extension names the Flutter MCP toolkit registers in the app
/// (`ext.mcp.toolkit.` + verb).
///
/// Values are DERIVED from `flutter_mcp_toolkit_core`'s
/// [core.ToolkitExtensionNames] — the single source of truth shared with
/// the registering side. A renamed verb is a compile error here instead
/// of a runtime `-32601` on a live app.
abstract final class ToolkitExtensions {
  /// Service-extension prefix (shared with the app side).
  static const String prefix = core.ToolkitExtensionNames.prefix;

  /// Semantic snapshot of the visible widget tree.
  static const String snapshot =
      '$prefix.${core.ToolkitExtensionNames.semanticSnapshot}';

  /// Taps a widget by snapshot ref.
  static const String tap =
      '$prefix.${core.ToolkitExtensionNames.tapWidget}';

  /// Enters text into a widget by snapshot ref.
  static const String enterText =
      '$prefix.${core.ToolkitExtensionNames.enterText}';

  /// Scrolls (by direction or to a ref).
  static const String scroll = '$prefix.${core.ToolkitExtensionNames.scroll}';

  /// Long-presses a widget by snapshot ref.
  static const String longPress =
      '$prefix.${core.ToolkitExtensionNames.longPress}';

  /// Swipes between coordinates.
  static const String swipe = '$prefix.${core.ToolkitExtensionNames.swipe}';

  /// Drags from one widget/point to another.
  static const String drag = '$prefix.${core.ToolkitExtensionNames.drag}';

  /// Presses a keyboard key.
  static const String pressKey =
      '$prefix.${core.ToolkitExtensionNames.pressKey}';

  /// Waits until a condition (label visible, …) holds.
  static const String waitFor =
      '$prefix.${core.ToolkitExtensionNames.waitFor}';

  /// Recent app logs (toolkit-buffered).
  static const String getRecentLogs =
      '$prefix.${core.ToolkitExtensionNames.getRecentLogs}';

  /// Navigates a route.
  static const String navigate =
      '$prefix.${core.ToolkitExtensionNames.navigate}';

  /// Handles a native dialog.
  static const String handleDialog =
      '$prefix.${core.ToolkitExtensionNames.handleDialog}';

  /// Hovers a position (desktop/web).
  static const String hover = '$prefix.${core.ToolkitExtensionNames.hover}';

  /// Focuses a widget by snapshot ref.
  static const String focusWidget =
      '$prefix.${core.ToolkitExtensionNames.focusWidget}';

  /// Reveals the search field.
  static const String revealSearch =
      '$prefix.${core.ToolkitExtensionNames.revealSearch}';

  /// Base64 screenshots of all views; `compress: false` keeps PNG bytes.
  static const String viewScreenshots =
      '$prefix.${core.ToolkitExtensionNames.viewScreenshots}';
}
