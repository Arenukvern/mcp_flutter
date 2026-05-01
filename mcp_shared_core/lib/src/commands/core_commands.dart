// mcp_shared_core/lib/src/commands/core_commands.dart
// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// Pure CoreCommand sealed hierarchy. No transport, no dart_mcp, no dart:io.

import '../visual_capture/permission_types.dart';

export '../visual_capture/permission_types.dart'
    show
        PermissionPolicy,
        PermissionStatus,
        PermissionKind,
        PermissionOwner,
        CaptureCapability,
        parsePermissionPolicy,
        parsePermissionKind,
        screenshotModeAuto,
        screenshotModeFlutterLayer,
        screenshotModeDesktopWindow,
        PermissionBrokerResult;

typedef CoreCommandFactory = CoreCommand Function(Map<String, Object?> args);

/// Canonical command surface shared by CLI and MCP wrapper.
sealed class CoreCommand {
  const CoreCommand();

  String get name;
}

/// Connection mode used by the shared core runtime.
enum CoreConnectionMode { auto, manual, uri }

// ──────────────────────────────────────────────────────────────────────────────
// Connection commands
// ──────────────────────────────────────────────────────────────────────────────

final class ConnectCommand extends CoreCommand {
  const ConnectCommand({
    this.mode = CoreConnectionMode.auto,
    this.targetId,
    this.uri,
    this.host,
    this.port,
    this.forceReconnect = false,
  });

  final CoreConnectionMode mode;
  final String? targetId;
  final String? uri;
  final String? host;
  final int? port;
  final bool forceReconnect;

  @override
  String get name => 'connect';
}

// ──────────────────────────────────────────────────────────────────────────────
// Session commands
// ──────────────────────────────────────────────────────────────────────────────

final class SessionStartCommand extends CoreCommand {
  const SessionStartCommand({
    this.mode = CoreConnectionMode.auto,
    this.targetId,
    this.uri,
    this.host,
    this.port,
    this.forceReconnect = false,
    this.sessionId,
  });

  final CoreConnectionMode mode;
  final String? targetId;
  final String? uri;
  final String? host;
  final int? port;
  final bool forceReconnect;
  final String? sessionId;

  @override
  String get name => 'session_start';
}

final class SessionEndCommand extends CoreCommand {
  const SessionEndCommand({this.sessionId});

  final String? sessionId;

  @override
  String get name => 'session_end';
}

final class SessionExecCommand extends CoreCommand {
  const SessionExecCommand({required this.command, this.sessionId});

  final String? sessionId;
  final CoreCommand command;

  @override
  String get name => 'session_exec';
}

// ──────────────────────────────────────────────────────────────────────────────
// Basic VM commands
// ──────────────────────────────────────────────────────────────────────────────

final class StatusCommand extends CoreCommand {
  const StatusCommand();

  @override
  String get name => 'status';
}

final class GetVmCommand extends CoreCommand {
  const GetVmCommand();

  @override
  String get name => 'get_vm';
}

final class GetExtensionRpcsCommand extends CoreCommand {
  const GetExtensionRpcsCommand();

  @override
  String get name => 'get_extension_rpcs';
}

final class GetActivePortsCommand extends CoreCommand {
  const GetActivePortsCommand();

  @override
  String get name => 'get_active_ports';
}

final class GetAppErrorsCommand extends CoreCommand {
  const GetAppErrorsCommand({this.count = 4});

  final int count;

  @override
  String get name => 'get_app_errors';
}

final class HotReloadFlutterCommand extends CoreCommand {
  const HotReloadFlutterCommand({this.force = false});

  final bool force;

  @override
  String get name => 'hot_reload_flutter';
}

final class HotRestartFlutterCommand extends CoreCommand {
  const HotRestartFlutterCommand();

  @override
  String get name => 'hot_restart_flutter';
}

final class WatchCommand extends CoreCommand {
  const WatchCommand({
    required this.command,
    this.sessionId,
    this.intervalMs = 1000,
    this.maxEvents = 0,
    this.stopOnError = false,
  });

  final String? sessionId;
  final CoreCommand command;
  final int intervalMs;
  final int maxEvents;
  final bool stopOnError;

  @override
  String get name => 'watch';
}

final class ExplainErrorsCommand extends CoreCommand {
  const ExplainErrorsCommand({
    this.count = 4,
    this.includeSummary = true,
    this.summaryProvider = 'none',
  });

  final int count;
  final bool includeSummary;
  final String summaryProvider;

  @override
  String get name => 'explain_errors';
}

// ──────────────────────────────────────────────────────────────────────────────
// Visual / widget commands
// ──────────────────────────────────────────────────────────────────────────────

enum ScreenshotMode {
  auto('auto'),
  flutterLayer('flutter_layer'),
  desktopWindow('desktop_window');

  const ScreenshotMode(this.wireName);

  final String wireName;
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
  const WaitForCommand({required this.predicate, this.timeoutMs = 5000});

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

  final String action;

  @override
  String get name => 'handle_dialog';
}

final class NavigateCommand extends CoreCommand {
  const NavigateCommand({required this.action, this.route, this.arguments});

  final String action;
  final String? route;
  final Map<String, Object?>? arguments;

  @override
  String get name => 'navigate';
}

final class FillFormCommand extends CoreCommand {
  const FillFormCommand({required this.fields, this.snapshotId});

  final List<Map<String, Object?>> fields;
  final int? snapshotId;

  @override
  String get name => 'fill_form';
}

final class HoverCommand extends CoreCommand {
  const HoverCommand({required this.ref, this.snapshotId});

  final String ref;
  final int? snapshotId;

  @override
  String get name => 'hover';
}

// ──────────────────────────────────────────────────────────────────────────────
// Debug commands
// ──────────────────────────────────────────────────────────────────────────────

final class DebugDumpFocusTreeCommand extends CoreCommand {
  const DebugDumpFocusTreeCommand();

  @override
  String get name => 'debug_dump_focus_tree';
}

final class DebugDumpLayerTreeCommand extends CoreCommand {
  const DebugDumpLayerTreeCommand();

  @override
  String get name => 'debug_dump_layer_tree';
}

final class DebugDumpRenderTreeCommand extends CoreCommand {
  const DebugDumpRenderTreeCommand();

  @override
  String get name => 'debug_dump_render_tree';
}

final class DebugDumpSemanticsTreeCommand extends CoreCommand {
  const DebugDumpSemanticsTreeCommand();

  @override
  String get name => 'debug_dump_semantics_tree';
}

final class DiagnoseCommand extends CoreCommand {
  const DiagnoseCommand({this.includeViewDetails = false});

  final bool includeViewDetails;

  @override
  String get name => 'diagnose';
}

final class DiscoverDebugAppsCommand extends CoreCommand {
  const DiscoverDebugAppsCommand();

  @override
  String get name => 'discover_debug_apps';
}

final class DynamicRegistryStatsCommand extends CoreCommand {
  const DynamicRegistryStatsCommand({this.includeAppDetails = true});

  final bool includeAppDetails;

  @override
  String get name => 'dynamicRegistryStats';
}

// ──────────────────────────────────────────────────────────────────────────────
// Dynamic registry commands
// ──────────────────────────────────────────────────────────────────────────────

final class ListClientToolsAndResourcesCommand extends CoreCommand {
  const ListClientToolsAndResourcesCommand();

  @override
  String get name => 'listClientToolsAndResources';
}

final class RunClientResourceCommand extends CoreCommand {
  const RunClientResourceCommand({required this.resourceUri});

  final String resourceUri;

  @override
  String get name => 'runClientResource';
}

final class RunClientToolCommand extends CoreCommand {
  const RunClientToolCommand({
    required this.toolName,
    this.arguments = const <String, Object?>{},
  });

  final String toolName;
  final Map<String, Object?> arguments;

  @override
  String get name => 'runClientTool';
}
