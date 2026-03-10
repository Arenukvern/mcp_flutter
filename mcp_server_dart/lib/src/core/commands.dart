// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';
import 'package:flutter_inspector_mcp_server/src/core/visual_capture.dart';

/// Connection mode used by the shared core runtime.
enum CoreConnectionMode { auto, manual, uri }

/// Canonical command surface shared by CLI and MCP wrapper.
sealed class CoreCommand {
  const CoreCommand();

  String get name;
}

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

final class SessionExecCommand extends CoreCommand {
  const SessionExecCommand({this.sessionId, required this.command});

  final String? sessionId;
  final CoreCommand command;

  @override
  String get name => 'session_exec';
}

final class SessionEndCommand extends CoreCommand {
  const SessionEndCommand({this.sessionId});

  final String? sessionId;

  @override
  String get name => 'session_end';
}

final class DiagnoseCommand extends CoreCommand {
  const DiagnoseCommand({this.includeViewDetails = false});

  final bool includeViewDetails;

  @override
  String get name => 'diagnose';
}

final class WatchCommand extends CoreCommand {
  const WatchCommand({
    this.sessionId,
    required this.command,
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

final class StatusCommand extends CoreCommand {
  const StatusCommand();

  @override
  String get name => 'status';
}

final class DiscoverDebugAppsCommand extends CoreCommand {
  const DiscoverDebugAppsCommand();

  @override
  String get name => 'discover_debug_apps';
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

final class GetViewDetailsCommand extends CoreCommand {
  const GetViewDetailsCommand();

  @override
  String get name => 'get_view_details';
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

final class DebugDumpLayerTreeCommand extends CoreCommand {
  const DebugDumpLayerTreeCommand();

  @override
  String get name => 'debug_dump_layer_tree';
}

final class DebugDumpSemanticsTreeCommand extends CoreCommand {
  const DebugDumpSemanticsTreeCommand();

  @override
  String get name => 'debug_dump_semantics_tree';
}

final class DebugDumpRenderTreeCommand extends CoreCommand {
  const DebugDumpRenderTreeCommand();

  @override
  String get name => 'debug_dump_render_tree';
}

final class DebugDumpFocusTreeCommand extends CoreCommand {
  const DebugDumpFocusTreeCommand();

  @override
  String get name => 'debug_dump_focus_tree';
}

final class ListClientToolsAndResourcesCommand extends CoreCommand {
  const ListClientToolsAndResourcesCommand();

  @override
  String get name => 'listClientToolsAndResources';
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

final class RunClientResourceCommand extends CoreCommand {
  const RunClientResourceCommand({required this.resourceUri});

  final String resourceUri;

  @override
  String get name => 'runClientResource';
}

final class DynamicRegistryStatsCommand extends CoreCommand {
  const DynamicRegistryStatsCommand({this.includeAppDetails = true});

  final bool includeAppDetails;

  @override
  String get name => 'dynamicRegistryStats';
}

final class LiveEditStartSessionCommand extends CoreCommand {
  const LiveEditStartSessionCommand({this.sessionId});

  final String? sessionId;

  @override
  String get name => 'live_edit_start_session';
}

final class LiveEditPrepareSessionCommand extends CoreCommand {
  const LiveEditPrepareSessionCommand({
    this.sessionId,
    this.backendId,
    this.workingDirectory,
  });

  final String? sessionId;
  final String? backendId;
  final String? workingDirectory;

  @override
  String get name => 'live_edit_prepare_session';
}

final class LiveEditSetOverlayCommand extends CoreCommand {
  const LiveEditSetOverlayCommand({this.sessionId, required this.enabled});

  final String? sessionId;
  final bool enabled;

  @override
  String get name => 'live_edit_set_overlay';
}

final class LiveEditGetTreeCommand extends CoreCommand {
  const LiveEditGetTreeCommand({this.sessionId});

  final String? sessionId;

  @override
  String get name => 'live_edit_get_tree';
}

final class LiveEditSelectAtPointCommand extends CoreCommand {
  const LiveEditSelectAtPointCommand({
    this.sessionId,
    required this.x,
    required this.y,
    this.viewId,
  });

  final String? sessionId;
  final int x;
  final int y;
  final int? viewId;

  @override
  String get name => 'live_edit_select_at_point';
}

final class LiveEditGetSelectionCommand extends CoreCommand {
  const LiveEditGetSelectionCommand({this.sessionId});

  final String? sessionId;

  @override
  String get name => 'live_edit_get_selection';
}

final class LiveEditGetCapabilitiesCommand extends CoreCommand {
  const LiveEditGetCapabilitiesCommand({this.sessionId});

  final String? sessionId;

  @override
  String get name => 'live_edit_get_capabilities';
}

final class LiveEditGetSelectionCandidatesCommand extends CoreCommand {
  const LiveEditGetSelectionCandidatesCommand({this.sessionId});

  final String? sessionId;

  @override
  String get name => 'live_edit_get_selection_candidates';
}

final class LiveEditSetActiveSelectionCommand extends CoreCommand {
  const LiveEditSetActiveSelectionCommand({
    this.sessionId,
    this.nodeId,
    this.index,
  });

  final String? sessionId;
  final String? nodeId;
  final int? index;

  @override
  String get name => 'live_edit_set_active_selection';
}

final class LiveEditGetPropertyPanelCommand extends CoreCommand {
  const LiveEditGetPropertyPanelCommand({this.sessionId});

  final String? sessionId;

  @override
  String get name => 'live_edit_get_property_panel';
}

final class LiveEditSetEditModeCommand extends CoreCommand {
  const LiveEditSetEditModeCommand({this.sessionId, required this.mode});

  final String? sessionId;
  final String mode;

  @override
  String get name => 'live_edit_set_edit_mode';
}

final class LiveEditGetPreviewStateCommand extends CoreCommand {
  const LiveEditGetPreviewStateCommand({this.sessionId});

  final String? sessionId;

  @override
  String get name => 'live_edit_get_preview_state';
}

final class LiveEditUpdateDraftCommand extends CoreCommand {
  const LiveEditUpdateDraftCommand({this.sessionId, required this.change});

  final String? sessionId;
  final LiveEditDraftChange change;

  @override
  String get name => 'live_edit_update_draft';
}

final class LiveEditGetDraftCommand extends CoreCommand {
  const LiveEditGetDraftCommand({this.sessionId});

  final String? sessionId;

  @override
  String get name => 'live_edit_get_draft';
}

final class LiveEditDiscardDraftCommand extends CoreCommand {
  const LiveEditDiscardDraftCommand({this.sessionId});

  final String? sessionId;

  @override
  String get name => 'live_edit_discard_draft';
}

final class LiveEditEndSessionCommand extends CoreCommand {
  const LiveEditEndSessionCommand({this.sessionId});

  final String? sessionId;

  @override
  String get name => 'live_edit_end_session';
}

final class LiveEditListAgentBackendsCommand extends CoreCommand {
  const LiveEditListAgentBackendsCommand();

  @override
  String get name => 'live_edit_list_agent_backends';
}

final class LiveEditGetAgentBackendCommand extends CoreCommand {
  const LiveEditGetAgentBackendCommand({this.sessionId, this.backendId});

  final String? sessionId;
  final String? backendId;

  @override
  String get name => 'live_edit_get_agent_backend';
}

final class LiveEditSetAgentBackendCommand extends CoreCommand {
  const LiveEditSetAgentBackendCommand({
    required this.sessionId,
    required this.backendId,
  });

  final String sessionId;
  final String backendId;

  @override
  String get name => 'live_edit_set_agent_backend';
}

final class LiveEditResolveDraftCommand extends CoreCommand {
  const LiveEditResolveDraftCommand({
    this.sessionId,
    this.backendId,
    this.workingDirectory,
    this.intentText,
  });

  final String? sessionId;
  final String? backendId;
  final String? workingDirectory;
  final String? intentText;

  @override
  String get name => 'live_edit_resolve_draft';
}

final class LiveEditAcceptResolutionCommand extends CoreCommand {
  const LiveEditAcceptResolutionCommand({
    required this.proposalId,
    this.sessionId,
    this.workingDirectory,
  });

  final String proposalId;
  final String? sessionId;
  final String? workingDirectory;

  @override
  String get name => 'live_edit_accept_resolution';
}

final class LiveEditRejectResolutionCommand extends CoreCommand {
  const LiveEditRejectResolutionCommand({required this.proposalId});

  final String proposalId;

  @override
  String get name => 'live_edit_reject_resolution';
}
