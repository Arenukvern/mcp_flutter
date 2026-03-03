#!/usr/bin/env dart
// ignore_for_file: do_not_use_environment

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:args/args.dart';
import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/flutter_mcp_core.dart';

Future<void> main(final List<String> args) async {
  final parsed = _argParser.parse(args);
  if (parsed.flag(_help) || parsed.command == null) {
    io.stdout.writeln(_usage());
    io.exit(0);
  }

  final outputJson = parsed.flag(_jsonMode) && !parsed.flag(_humanMode);

  final logLevel = _parseLogLevel(parsed.option(_logLevel));
  final logger = _buildLogger(logLevel);

  final stateStore = StateStore(
    path: parsed.option(_stateFile) ?? _defaultStateFile,
  );
  final bootstrapState = await _readBootstrapState(stateStore);

  final bootstrapStickyEndpoint =
      bootstrapState.activeSession?.endpoint ?? bootstrapState.stickyEndpoint;

  final portScanner = CorePortScanner(logger: logger);

  final connectionContext = ConnectionContext(
    defaultHost: parsed.option(_dartVmHost) ?? _defaultHost,
    defaultPort: int.tryParse(parsed.option(_dartVmPort) ?? '') ?? _defaultPort,
    logger: logger,
    discoverPorts: portScanner.scanForFlutterPorts,
    initialStickyEndpointUri: bootstrapStickyEndpoint,
  );

  final sessionManager = SessionManager(
    connectionContext: connectionContext,
    stateStore: stateStore,
  );
  await sessionManager.load();

  final configuration = CoreRuntimeConfiguration(
    vmHost: parsed.option(_dartVmHost) ?? _defaultHost,
    vmPort: int.tryParse(parsed.option(_dartVmPort) ?? '') ?? _defaultPort,
    resourcesSupported: parsed.flag(_resourcesSupported),
    imagesSupported: parsed.flag(_imagesSupported),
    dumpsSupported: parsed.flag(_dumpsSupported),
    dynamicRegistrySupported: parsed.flag(_dynamicRegistrySupported),
    saveImagesToFiles: parsed.flag(_saveImagesToFiles),
  );

  final executor = DefaultCoreCommandExecutor(
    connectionContext: connectionContext,
    portScanner: portScanner,
    imageFileSaver: CoreImageFileSaver(logger: logger),
    configuration: configuration,
    sessionManager: sessionManager,
  );

  final command = _toCoreCommand(
    parsed.command!,
    globalSessionId: parsed.option(_sessionId),
  );

  final preconnectError = await _preconnectIfNeeded(
    parsed: parsed,
    command: command,
    sessionManager: sessionManager,
    executor: executor,
  );
  if (preconnectError != null) {
    if (outputJson) {
      io.stdout.writeln(jsonEncode(preconnectError.toEnvelopeJson()));
    } else {
      _printHuman('connect', preconnectError);
    }
    await connectionContext.disconnect();
    io.exit(1);
  }

  if (command is WatchCommand) {
    final exitCode = await _runWatch(
      watch: command,
      executor: executor,
      outputJson: outputJson,
    );
    await connectionContext.disconnect();
    io.exit(exitCode);
  }

  final result = await executor.execute(command);

  if (outputJson) {
    io.stdout.writeln(jsonEncode(result.toEnvelopeJson()));
  } else {
    _printHuman(command.name, result);
  }

  await connectionContext.disconnect();
  io.exit(result.ok ? 0 : 1);
}

Future<PersistedState> _readBootstrapState(final StateStore store) async {
  try {
    return await store.read();
  } on Exception {
    return const PersistedState();
  }
}

Future<CoreResult?> _preconnectIfNeeded({
  required final ArgResults parsed,
  required final CoreCommand command,
  required final SessionManager sessionManager,
  required final DefaultCoreCommandExecutor executor,
}) async {
  if (_isPreconnectSkippedCommand(command)) {
    return null;
  }

  CoreResult? lastError;

  final globalVmServiceUri = parsed.option(_vmServiceUri);
  if (globalVmServiceUri != null && globalVmServiceUri.isNotEmpty) {
    final explicit = await executor.execute(
      ConnectCommand(mode: CoreConnectionMode.uri, uri: globalVmServiceUri),
    );
    if (explicit.ok) {
      return null;
    }
    return explicit;
  }

  final requestedSessionId = _sessionIdForCommand(
    parsed.option(_sessionId),
    command,
  );
  final hasAnyKnownSession = sessionManager.state.activeSessionId != null;

  if (requestedSessionId != null || hasAnyKnownSession) {
    final sessionAttach = await sessionManager.attachSession(
      sessionId: requestedSessionId,
    );
    if (sessionAttach.ok) {
      return null;
    }
    lastError = sessionAttach;
  }

  final stickyEndpoint = sessionManager.stickyEndpoint;
  if (stickyEndpoint != null && stickyEndpoint.isNotEmpty) {
    final stickyConnect = await executor.execute(
      ConnectCommand(mode: CoreConnectionMode.uri, uri: stickyEndpoint),
    );
    if (stickyConnect.ok) {
      return null;
    }
    lastError = stickyConnect;
  }

  if (_commandRequiresVmConnection(command)) {
    return lastError;
  }

  return null;
}

Future<int> _runWatch({
  required final WatchCommand watch,
  required final DefaultCoreCommandExecutor executor,
  required final bool outputJson,
}) async {
  var seq = 0;
  var seenError = false;
  var stoppedBySignal = false;

  void emit(final Map<String, Object?> event) {
    if (outputJson) {
      io.stdout.writeln(jsonEncode(event));
      return;
    }
    final eventType = event['event'];
    io.stdout.writeln('[watch] $eventType');
    io.stdout.writeln(const JsonEncoder.withIndent('  ').convert(event));
  }

  Map<String, Object?> baseEvent(final String eventName) => {
    'event': eventName,
    'seq': ++seq,
    'timestamp': DateTime.now().toUtc().toIso8601String(),
    'command': watch.command.name,
    if (watch.sessionId != null) 'sessionId': watch.sessionId,
  };

  final sigSub = io.ProcessSignal.sigint.watch().listen((_) {
    stoppedBySignal = true;
  });

  emit({
    ...baseEvent('watch_started'),
    'intervalMs': watch.intervalMs,
    'maxEvents': watch.maxEvents,
    'stopOnError': watch.stopOnError,
  });

  var emittedResults = 0;
  String stopReason = 'max_events_reached';

  try {
    while (true) {
      if (stoppedBySignal) {
        stopReason = 'signal_sigint';
        break;
      }

      final result = await executor.execute(
        watch.sessionId == null
            ? watch.command
            : SessionExecCommand(
                sessionId: watch.sessionId,
                command: watch.command,
              ),
      );

      emittedResults += 1;

      if (result.ok) {
        emit({
          ...baseEvent('command_result'),
          'result': result.toEnvelopeJson(),
        });
      } else {
        seenError = true;
        emit({...baseEvent('watch_error'), 'result': result.toEnvelopeJson()});
        if (watch.stopOnError) {
          stopReason = 'stop_on_error';
          break;
        }
      }

      if (watch.maxEvents > 0 && emittedResults >= watch.maxEvents) {
        stopReason = 'max_events_reached';
        break;
      }

      await Future<void>.delayed(Duration(milliseconds: watch.intervalMs));
    }
  } finally {
    await sigSub.cancel();
    emit({...baseEvent('watch_stopped'), 'reason': stopReason});
  }

  if (seenError && watch.stopOnError) {
    return 1;
  }
  return 0;
}

void _printHuman(final String commandName, final CoreResult result) {
  if (result.ok) {
    io.stdout.writeln('[$commandName] OK');
    if (result.data != null) {
      io.stdout.writeln(
        const JsonEncoder.withIndent('  ').convert(result.data),
      );
    }
    return;
  }

  io.stdout.writeln('[$commandName] ERROR: ${result.error?.message}');
  if (result.error?.details != null) {
    io.stdout.writeln(
      const JsonEncoder.withIndent('  ').convert(result.error!.details),
    );
  }
}

CoreCommand _toCoreCommand(
  final ArgResults commandArgs, {
  final String? globalSessionId,
}) {
  final commandName = commandArgs.name;
  switch (commandName) {
    case 'connect':
      return ConnectCommand(
        mode: _parseConnectionMode(commandArgs.option('mode')),
        uri: commandArgs.option('uri'),
        host: commandArgs.option('host'),
        port: int.tryParse(commandArgs.option('port') ?? ''),
        forceReconnect: commandArgs.flag('force'),
      );
    case 'session_start':
      return SessionStartCommand(
        mode: _parseConnectionMode(commandArgs.option('mode')),
        uri: commandArgs.option('uri'),
        host: commandArgs.option('host'),
        port: int.tryParse(commandArgs.option('port') ?? ''),
        forceReconnect: commandArgs.flag('force'),
        sessionId: _coalesceString(
          commandArgs.option('session-id'),
          globalSessionId,
        ),
      );
    case 'session_exec':
      final targetName = commandArgs.option('command') ?? '';
      final argsMap = _parseArgumentsJson(commandArgs.option('arguments'));
      return SessionExecCommand(
        sessionId: _coalesceString(
          commandArgs.option('session-id'),
          globalSessionId,
        ),
        command: _commandFromNameAndArgs(targetName, argsMap),
      );
    case 'session_end':
      return SessionEndCommand(
        sessionId: _coalesceString(
          commandArgs.option('session-id'),
          globalSessionId,
        ),
      );
    case 'diagnose':
      return DiagnoseCommand(
        includeViewDetails: commandArgs.flag('include-view-details'),
      );
    case 'watch':
      final targetName = commandArgs.option('command') ?? '';
      final argsMap = _parseArgumentsJson(commandArgs.option('arguments'));
      return WatchCommand(
        sessionId: _coalesceString(
          commandArgs.option('session-id'),
          globalSessionId,
        ),
        command: _commandFromNameAndArgs(targetName, argsMap),
        intervalMs:
            int.tryParse(commandArgs.option('interval-ms') ?? '') ?? 1000,
        maxEvents: int.tryParse(commandArgs.option('max-events') ?? '') ?? 0,
        stopOnError: commandArgs.flag('stop-on-error'),
      );
    case 'explain_errors':
      return ExplainErrorsCommand(
        count: int.tryParse(commandArgs.option('count') ?? '') ?? 4,
        includeSummary: commandArgs.flag('include-summary'),
        summaryProvider: commandArgs.option('summary-provider') ?? 'none',
      );
    case 'status':
      return const StatusCommand();
    case 'discover_debug_apps':
      return const DiscoverDebugAppsCommand();
    case 'get_vm':
      return const GetVmCommand();
    case 'get_extension_rpcs':
      return const GetExtensionRpcsCommand();
    case 'hot_reload_flutter':
      return HotReloadFlutterCommand(force: commandArgs.flag('force'));
    case 'hot_restart_flutter':
      return const HotRestartFlutterCommand();
    case 'get_active_ports':
      return const GetActivePortsCommand();
    case 'get_app_errors':
      return GetAppErrorsCommand(
        count: int.tryParse(commandArgs.option('count') ?? '') ?? 4,
      );
    case 'get_screenshots':
      return GetScreenshotsCommand(compress: commandArgs.flag('compress'));
    case 'get_view_details':
      return const GetViewDetailsCommand();
    case 'debug_dump_layer_tree':
      return const DebugDumpLayerTreeCommand();
    case 'debug_dump_semantics_tree':
      return const DebugDumpSemanticsTreeCommand();
    case 'debug_dump_render_tree':
      return const DebugDumpRenderTreeCommand();
    case 'debug_dump_focus_tree':
      return const DebugDumpFocusTreeCommand();
    case 'listClientToolsAndResources':
      return const ListClientToolsAndResourcesCommand();
    case 'runClientTool':
      return RunClientToolCommand(
        toolName: commandArgs.option('tool-name') ?? '',
        arguments: _parseArgumentsJson(commandArgs.option('arguments')),
      );
    case 'runClientResource':
      return RunClientResourceCommand(
        resourceUri: commandArgs.option('resource-uri') ?? '',
      );
    case 'dynamicRegistryStats':
      return DynamicRegistryStatsCommand(
        includeAppDetails: commandArgs.flag('include-app-details'),
      );
    default:
      throw ArgumentError('Unsupported command: $commandName');
  }
}

CoreCommand _commandFromNameAndArgs(
  final String name,
  final Map<String, Object?> args,
) {
  switch (name) {
    case 'status':
      return const StatusCommand();
    case 'discover_debug_apps':
      return const DiscoverDebugAppsCommand();
    case 'get_vm':
      return const GetVmCommand();
    case 'get_extension_rpcs':
      return const GetExtensionRpcsCommand();
    case 'hot_reload_flutter':
      return HotReloadFlutterCommand(
        force: _boolFrom(args['force'], defaultValue: false),
      );
    case 'hot_restart_flutter':
      return const HotRestartFlutterCommand();
    case 'get_active_ports':
      return const GetActivePortsCommand();
    case 'get_app_errors':
      return GetAppErrorsCommand(
        count: _intFrom(args['count'], defaultValue: 4),
      );
    case 'get_screenshots':
      return GetScreenshotsCommand(
        compress: _boolFrom(args['compress'], defaultValue: true),
      );
    case 'get_view_details':
      return const GetViewDetailsCommand();
    case 'debug_dump_layer_tree':
      return const DebugDumpLayerTreeCommand();
    case 'debug_dump_semantics_tree':
      return const DebugDumpSemanticsTreeCommand();
    case 'debug_dump_render_tree':
      return const DebugDumpRenderTreeCommand();
    case 'debug_dump_focus_tree':
      return const DebugDumpFocusTreeCommand();
    case 'listClientToolsAndResources':
      return const ListClientToolsAndResourcesCommand();
    case 'runClientTool':
      return RunClientToolCommand(
        toolName: '${args['tool-name'] ?? args['toolName'] ?? ''}',
        arguments: _mapFrom(args['arguments']),
      );
    case 'runClientResource':
      return RunClientResourceCommand(
        resourceUri: '${args['resource-uri'] ?? args['resourceUri'] ?? ''}',
      );
    case 'dynamicRegistryStats':
      return DynamicRegistryStatsCommand(
        includeAppDetails: _boolFrom(
          args['include-app-details'] ?? args['includeAppDetails'],
          defaultValue: true,
        ),
      );
    case 'diagnose':
      return DiagnoseCommand(
        includeViewDetails: _boolFrom(
          args['include-view-details'] ?? args['includeViewDetails'],
          defaultValue: false,
        ),
      );
    case 'explain_errors':
      return ExplainErrorsCommand(
        count: _intFrom(args['count'], defaultValue: 4),
        includeSummary: _boolFrom(
          args['include-summary'] ?? args['includeSummary'],
          defaultValue: true,
        ),
        summaryProvider:
            '${args['summary-provider'] ?? args['summaryProvider'] ?? 'none'}',
      );
    case 'connect':
      return ConnectCommand(
        mode: _parseConnectionMode('${args['mode'] ?? 'auto'}'),
        uri: args['uri']?.toString(),
        host: args['host']?.toString(),
        port: _intFromNullable(args['port']),
        forceReconnect: _boolFrom(args['force'], defaultValue: false),
      );
    default:
      throw ArgumentError('Unsupported command: $name');
  }
}

bool _isPreconnectSkippedCommand(final CoreCommand command) {
  return command is ConnectCommand ||
      command is SessionStartCommand ||
      command is SessionEndCommand;
}

String? _sessionIdForCommand(
  final String? globalSessionId,
  final CoreCommand command,
) {
  if (command case final SessionExecCommand c) {
    return _coalesceString(c.sessionId, globalSessionId);
  }
  if (command case final WatchCommand c) {
    return _coalesceString(c.sessionId, globalSessionId);
  }
  if (command case final SessionEndCommand c) {
    return _coalesceString(c.sessionId, globalSessionId);
  }
  if (command case final SessionStartCommand c) {
    return _coalesceString(c.sessionId, globalSessionId);
  }
  return _coalesceString(globalSessionId);
}

bool _commandRequiresVmConnection(final CoreCommand command) {
  if (command is WatchCommand) {
    return _commandRequiresVmConnection(command.command);
  }
  return command is GetVmCommand ||
      command is GetExtensionRpcsCommand ||
      command is HotReloadFlutterCommand ||
      command is HotRestartFlutterCommand ||
      command is GetAppErrorsCommand ||
      command is GetScreenshotsCommand ||
      command is GetViewDetailsCommand ||
      command is DebugDumpLayerTreeCommand ||
      command is DebugDumpSemanticsTreeCommand ||
      command is DebugDumpRenderTreeCommand ||
      command is DebugDumpFocusTreeCommand ||
      command is ListClientToolsAndResourcesCommand ||
      command is RunClientToolCommand ||
      command is RunClientResourceCommand ||
      command is DynamicRegistryStatsCommand ||
      command is ExplainErrorsCommand;
}

Map<String, Object?> _parseArgumentsJson(final String? value) {
  if (value == null || value.isEmpty) {
    return const <String, Object?>{};
  }

  final decoded = jsonDecode(value);
  if (decoded is Map<String, Object?>) {
    return decoded;
  }
  if (decoded is Map) {
    return decoded.cast<String, Object?>();
  }
  throw ArgumentError('Expected JSON object for --arguments');
}

Map<String, Object?> _mapFrom(final Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, Object?>();
  }
  return const <String, Object?>{};
}

bool _boolFrom(final Object? value, {required final bool defaultValue}) {
  return switch (value) {
    final bool v => v,
    final num v => v != 0,
    final String v => bool.tryParse(v) ?? defaultValue,
    _ => defaultValue,
  };
}

int _intFrom(final Object? value, {required final int defaultValue}) {
  return switch (value) {
    final int v => v,
    final num v => v.toInt(),
    final String v => int.tryParse(v) ?? defaultValue,
    _ => defaultValue,
  };
}

int? _intFromNullable(final Object? value) {
  return switch (value) {
    null => null,
    final int v => v,
    final num v => v.toInt(),
    final String v => int.tryParse(v),
    _ => null,
  };
}

String? _coalesceString(final String? first, [final String? second]) {
  if (first != null && first.isNotEmpty) {
    return first;
  }
  if (second != null && second.isNotEmpty) {
    return second;
  }
  return null;
}

CoreConnectionMode _parseConnectionMode(final String? mode) {
  return switch (mode) {
    'manual' => CoreConnectionMode.manual,
    'uri' => CoreConnectionMode.uri,
    _ => CoreConnectionMode.auto,
  };
}

LoggingLevel _parseLogLevel(final String? level) {
  return switch (level) {
    'debug' => LoggingLevel.debug,
    'info' => LoggingLevel.info,
    'notice' => LoggingLevel.notice,
    'warning' => LoggingLevel.warning,
    'error' => LoggingLevel.error,
    'critical' => LoggingLevel.critical,
    'alert' => LoggingLevel.alert,
    'emergency' => LoggingLevel.emergency,
    _ => LoggingLevel.error,
  };
}

CoreLogger _buildLogger(final LoggingLevel minimumLevel) {
  return (final level, final message, {final logger = 'core'}) {
    if (level.index < minimumLevel.index) {
      return;
    }
    io.stderr.writeln('[${level.name}] [$logger] $message');
  };
}

String _usage() {
  final buffer = StringBuffer()
    ..writeln('flutter_mcp_cli')
    ..writeln('')
    ..writeln('Usage:')
    ..writeln('  flutter_mcp_cli [global options] <command> [command options]')
    ..writeln('')
    ..writeln('Global options:')
    ..writeln(_argParser.usage);

  return buffer.toString();
}

final _argParser = ArgParser(allowTrailingOptions: false)
  ..addOption(
    _dartVmHost,
    defaultsTo: _defaultHost,
    help: 'Host for Dart VM connection',
  )
  ..addOption(
    _dartVmPort,
    defaultsTo: '$_defaultPort',
    help: 'Port for Dart VM connection',
  )
  ..addOption(
    _vmServiceUri,
    help:
        'Optional full VM service websocket URI '
        '(e.g. ws://127.0.0.1:8181/<token>/ws). '
        'Applied as first-precedence connection source.',
  )
  ..addOption(
    _stateFile,
    defaultsTo: _defaultStateFile,
    help: 'Path to persisted CLI state file',
  )
  ..addOption(_sessionId, help: 'Session identifier for session-aware commands')
  ..addFlag(
    _resourcesSupported,
    defaultsTo: true,
    help: 'Enable resources support',
  )
  ..addFlag(_imagesSupported, defaultsTo: true, help: 'Enable images support')
  ..addFlag(
    _dynamicRegistrySupported,
    defaultsTo: true,
    help: 'Enable dynamic registry support',
  )
  ..addFlag(_dumpsSupported, defaultsTo: false, help: 'Enable dump commands')
  ..addFlag(
    _saveImagesToFiles,
    defaultsTo: false,
    help: 'Save screenshots to files and return file URLs',
  )
  ..addOption(
    _logLevel,
    defaultsTo: _defaultLogLevel,
    help:
        'Logging level (debug|info|notice|warning|error|critical|alert|emergency)',
  )
  ..addFlag(_jsonMode, defaultsTo: true, help: 'Print JSON output (default)')
  ..addFlag(
    _humanMode,
    defaultsTo: false,
    help: 'Print human-readable output instead of JSON envelope',
  )
  ..addFlag(_help, abbr: 'h', help: 'Show usage text')
  ..addCommand(
    'connect',
    ArgParser()
      ..addOption(
        'mode',
        defaultsTo: 'auto',
        allowed: ['auto', 'manual', 'uri'],
      )
      ..addOption('uri')
      ..addOption('host')
      ..addOption('port')
      ..addFlag('force', defaultsTo: false),
  )
  ..addCommand(
    'session_start',
    ArgParser()
      ..addOption(
        'mode',
        defaultsTo: 'auto',
        allowed: ['auto', 'manual', 'uri'],
      )
      ..addOption('uri')
      ..addOption('host')
      ..addOption('port')
      ..addOption('session-id')
      ..addFlag('force', defaultsTo: false),
  )
  ..addCommand(
    'session_exec',
    ArgParser()
      ..addOption('session-id')
      ..addOption('command')
      ..addOption('arguments', defaultsTo: '{}'),
  )
  ..addCommand('session_end', ArgParser()..addOption('session-id'))
  ..addCommand(
    'diagnose',
    ArgParser()..addFlag('include-view-details', defaultsTo: false),
  )
  ..addCommand(
    'watch',
    ArgParser()
      ..addOption('session-id')
      ..addOption('command')
      ..addOption('arguments', defaultsTo: '{}')
      ..addOption('interval-ms', defaultsTo: '1000')
      ..addOption('max-events', defaultsTo: '0')
      ..addFlag('stop-on-error', defaultsTo: false),
  )
  ..addCommand(
    'explain_errors',
    ArgParser()
      ..addOption('count', defaultsTo: '4')
      ..addFlag('include-summary', defaultsTo: true)
      ..addOption(
        'summary-provider',
        defaultsTo: 'none',
        allowed: ['none', 'openai'],
      ),
  )
  ..addCommand('status')
  ..addCommand('discover_debug_apps')
  ..addCommand('get_vm')
  ..addCommand('get_extension_rpcs')
  ..addCommand(
    'hot_reload_flutter',
    ArgParser()..addFlag('force', defaultsTo: false),
  )
  ..addCommand('hot_restart_flutter')
  ..addCommand('get_active_ports')
  ..addCommand(
    'get_app_errors',
    ArgParser()..addOption('count', defaultsTo: '4'),
  )
  ..addCommand(
    'get_screenshots',
    ArgParser()..addFlag('compress', defaultsTo: true),
  )
  ..addCommand('get_view_details')
  ..addCommand('debug_dump_layer_tree')
  ..addCommand('debug_dump_semantics_tree')
  ..addCommand('debug_dump_render_tree')
  ..addCommand('debug_dump_focus_tree')
  ..addCommand('listClientToolsAndResources')
  ..addCommand(
    'runClientTool',
    ArgParser()
      ..addOption('tool-name')
      ..addOption('arguments'),
  )
  ..addCommand('runClientResource', ArgParser()..addOption('resource-uri'))
  ..addCommand(
    'dynamicRegistryStats',
    ArgParser()..addFlag('include-app-details', defaultsTo: true),
  );

const _defaultHost = 'localhost';
const _defaultPort = 8181;
const _defaultLogLevel = 'error';
const _defaultStateFile = '.flutter_mcp/state.json';

const _dartVmHost = 'dart-vm-host';
const _dartVmPort = 'dart-vm-port';
const _vmServiceUri = 'vm-service-uri';
const _stateFile = 'state-file';
const _sessionId = 'session-id';
const _resourcesSupported = 'resources';
const _imagesSupported = 'images';
const _dumpsSupported = 'dumps';
const _dynamicRegistrySupported = 'dynamics';
const _saveImagesToFiles = 'save-images';
const _logLevel = 'log-level';
const _jsonMode = 'json';
const _humanMode = 'human';
const _help = 'help';
