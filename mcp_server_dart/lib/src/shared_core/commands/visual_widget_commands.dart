part of 'commands.dart';

final class InspectWidgetAtPointCommand extends CoreCommand {
  const InspectWidgetAtPointCommand({
    required this.x,
    required this.y,
    this.viewId,
  });

  final int x;
  final int y;
  final int? viewId;

  @override
  String get name => 'inspect_widget_at_point';
}

final class ListClientToolsAndResourcesCommand extends CoreCommand {
  const ListClientToolsAndResourcesCommand();

  @override
  String get name => 'listClientToolsAndResources';
}

enum ScreenshotMode {
  auto('auto'),
  flutterLayer('flutter_layer'),
  desktopWindow('desktop_window');

  const ScreenshotMode(this.wireName);

  final String wireName;
}

final class GetViewDetailsCommand extends CoreCommand {
  const GetViewDetailsCommand();

  @override
  String get name => 'get_view_details';
}

final class GetScreenshotsCommand extends CoreCommand {
  const GetScreenshotsCommand({
    this.compress = true,
    this.mode = ScreenshotMode.auto,
    this.permissionPolicy = PermissionPolicy.checkOnly,
  });

  final bool compress;
  final ScreenshotMode mode;
  final PermissionPolicy permissionPolicy;

  @override
  String get name => 'get_screenshots';
}

ScreenshotMode parseScreenshotMode(
  final Object? value, {
  final ScreenshotMode fallback = ScreenshotMode.auto,
}) {
  final normalized = '$value'.trim().toLowerCase();
  for (final mode in ScreenshotMode.values) {
    if (mode.wireName == normalized) {
      return mode;
    }
  }
  return fallback;
}

final class CaptureUiSnapshotCommand extends CoreCommand {
  const CaptureUiSnapshotCommand({
    this.errorsCount = 4,
    this.compress = true,
    this.includeViewDetails = true,
    this.includeErrors = true,
    this.screenshotMode = ScreenshotMode.auto,
    this.permissionPolicy = PermissionPolicy.checkOnly,
  });

  final int errorsCount;
  final bool compress;
  final bool includeViewDetails;
  final bool includeErrors;
  final ScreenshotMode screenshotMode;
  final PermissionPolicy permissionPolicy;

  @override
  String get name => 'capture_ui_snapshot';
}

final class SemanticSnapshotCommand extends CoreCommand {
  const SemanticSnapshotCommand();

  @override
  String get name => 'semantic_snapshot';
}

final class TapWidgetCommand extends CoreCommand {
  const TapWidgetCommand({required this.ref, this.snapshotId});

  final String ref;
  final int? snapshotId;

  @override
  String get name => 'tap_widget';
}

final class EnterTextCommand extends CoreCommand {
  const EnterTextCommand({
    required this.ref,
    required this.text,
    this.snapshotId,
  });

  final String ref;
  final String text;
  final int? snapshotId;

  @override
  String get name => 'enter_text';
}

final class ScrollCommand extends CoreCommand {
  const ScrollCommand({
    required this.direction,
    this.ref,
    this.distance = 300,
    this.snapshotId,
  });

  final String? ref;
  final String direction;
  final double distance;
  final int? snapshotId;

  @override
  String get name => 'scroll';
}

final class LongPressCommand extends CoreCommand {
  const LongPressCommand({required this.ref, this.snapshotId});

  final String ref;
  final int? snapshotId;

  @override
  String get name => 'long_press';
}

final class SwipeCommand extends CoreCommand {
  const SwipeCommand({
    required this.direction,
    this.ref,
    this.distance = 300,
    this.snapshotId,
  });

  final String direction;
  final String? ref;
  final double distance;
  final int? snapshotId;

  @override
  String get name => 'swipe';
}

final class DragCommand extends CoreCommand {
  const DragCommand({
    required this.fromRef,
    required this.toRef,
    this.snapshotId,
  });

  final String fromRef;
  final String toRef;
  final int? snapshotId;

  @override
  String get name => 'drag';
}

final class HotReloadAndCaptureCommand extends CoreCommand {
  const HotReloadAndCaptureCommand({
    this.compress = true,
    this.includeSemantics = true,
    this.includeErrors = true,
    this.errorsCount = 4,
  });

  final bool compress;
  final bool includeSemantics;
  final bool includeErrors;
  final int errorsCount;

  @override
  String get name => 'hot_reload_and_capture';
}

final class EvaluateDartExpressionCommand extends CoreCommand {
  const EvaluateDartExpressionCommand({required this.expression});

  final String expression;

  @override
  String get name => 'evaluate_dart_expression';
}

final class GetRecentLogsCommand extends CoreCommand {
  const GetRecentLogsCommand({this.count = 50});

  final int count;

  @override
  String get name => 'get_recent_logs';
}

final class WaitForCommand extends CoreCommand {
  const WaitForCommand({
    required this.predicate,
    this.timeoutMs = 5000,
  });

  /// Free-form map echoed back to the toolkit. Shape per `kind`:
  ///   {kind: 'time', ms: int}
  ///   {kind: 'text', text: String}
  ///   {kind: 'noText', text: String}
  ///   {kind: 'stable', stableWindowMs: int}
  final Map<String, Object?> predicate;
  final int timeoutMs;

  @override
  String get name => 'wait_for';
}

final class PressKeyCommand extends CoreCommand {
  const PressKeyCommand({
    required this.key,
    this.ctrl = false,
    this.shift = false,
    this.alt = false,
    this.meta = false,
  });

  /// Key name. Accepted: Enter, Escape, Tab, Backspace, Delete, Space,
  /// ArrowUp/Down/Left/Right, single ASCII chars (a..z, 0..9).
  final String key;
  final bool ctrl;
  final bool shift;
  final bool alt;
  final bool meta;

  @override
  String get name => 'press_key';
}

final class HandleDialogCommand extends CoreCommand {
  const HandleDialogCommand({required this.action});

  /// Currently only `'dismiss'` is supported.
  final String action;

  @override
  String get name => 'handle_dialog';
}

final class NavigateCommand extends CoreCommand {
  const NavigateCommand({
    required this.action,
    this.route,
    this.arguments,
  });

  /// One of: `'push'`, `'pop'`, `'popUntil'`.
  final String action;

  /// Required for `'push'` and `'popUntil'`. Ignored for `'pop'`.
  final String? route;

  /// Optional. Used only for `'push'`.
  final Map<String, Object?>? arguments;

  @override
  String get name => 'navigate';
}
