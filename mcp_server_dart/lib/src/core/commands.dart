// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

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
    this.uri,
    this.host,
    this.port,
    this.forceReconnect = false,
  });

  final CoreConnectionMode mode;
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
    this.uri,
    this.host,
    this.port,
    this.forceReconnect = false,
    this.sessionId,
  });

  final CoreConnectionMode mode;
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

final class GetScreenshotsCommand extends CoreCommand {
  const GetScreenshotsCommand({this.compress = true});

  final bool compress;

  @override
  String get name => 'get_screenshots';
}

final class GetViewDetailsCommand extends CoreCommand {
  const GetViewDetailsCommand();

  @override
  String get name => 'get_view_details';
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
