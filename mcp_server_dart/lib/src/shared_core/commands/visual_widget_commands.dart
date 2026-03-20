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
