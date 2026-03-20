// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

part of 'commands.dart';

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

final class GetExtensionRpcsCommand extends CoreCommand {
  const GetExtensionRpcsCommand();

  @override
  String get name => 'get_extension_rpcs';
}

final class GetVmCommand extends CoreCommand {
  const GetVmCommand();

  @override
  String get name => 'get_vm';
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

final class StatusCommand extends CoreCommand {
  const StatusCommand();

  @override
  String get name => 'status';
}
