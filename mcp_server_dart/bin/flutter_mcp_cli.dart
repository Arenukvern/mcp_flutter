#!/usr/bin/env dart
// ignore_for_file: do_not_use_environment

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

  final logLevel = _parseLogLevel(parsed.option(_logLevel));
  final logger = _buildLogger(logLevel);

  final statePath = parsed.option(_stateFile) ?? _defaultStateFile;
  final stateRoot = _resolveStateRoot(statePath);

  final stateStore = StateStore(path: statePath);
  final bootstrapState = await _readBootstrapState(stateStore);
  final bootstrapStickyEndpoint =
      bootstrapState.activeSession?.endpoint ?? bootstrapState.stickyEndpoint;

  final flutterProjectDir = _nonEmptyOption(parsed.option(_flutterProjectDir));
  final flutterDevice = _nonEmptyOption(parsed.option(_flutterDevice));
  final flutterDiscoveryTimeoutMs = _parsePositiveIntOption(
    parsed.option(_flutterDiscoveryTimeoutMs),
    fallback: _defaultFlutterDiscoveryTimeoutMs,
  );

  final portScanner = CorePortScanner(logger: logger);
  final machineDiscovery = FlutterToolMachineDiscovery(logger: logger);

  final connectionContext = ConnectionContext(
    defaultHost: parsed.option(_dartVmHost) ?? _defaultHost,
    defaultPort: int.tryParse(parsed.option(_dartVmPort) ?? '') ?? _defaultPort,
    logger: logger,
    discoverPorts: portScanner.scanForFlutterPorts,
    discoverMachineTargets: () => machineDiscovery.discover(
      projectDir: flutterProjectDir,
      device: flutterDevice,
      timeout: Duration(milliseconds: flutterDiscoveryTimeoutMs),
    ),
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

  final catalog = CommandCatalog.instance;
  final snapshotStore = SnapshotStore(snapshotsDir: '$stateRoot/snapshots');
  final bundleBuilder = BundleBuilder(
    bundlesDir: '$stateRoot/bundles',
    snapshotStore: snapshotStore,
    stateFilePath: statePath,
  );

  final command = parsed.command!;

  if (command.name == 'serve') {
    final daemon = CliDaemonServer(
      executor: executor,
      sessionManager: sessionManager,
      catalog: catalog,
      snapshotStore: snapshotStore,
      bundleBuilder: bundleBuilder,
      configuration: configuration,
    );
    await daemon.serve();
    await connectionContext.disconnect();
    return;
  }

  final result = await _runOneShot(
    parsed: parsed,
    topLevel: command,
    executor: executor,
    catalog: catalog,
    configuration: configuration,
    sessionManager: sessionManager,
    snapshotStore: snapshotStore,
    bundleBuilder: bundleBuilder,
  );

  io.stdout.writeln(jsonEncode(result.toEnvelopeJson()));
  await connectionContext.disconnect();
  io.exit(result.exitCode);
}

Future<CoreResult> _runOneShot({
  required final ArgResults parsed,
  required final ArgResults topLevel,
  required final DefaultCoreCommandExecutor executor,
  required final CommandCatalog catalog,
  required final CoreRuntimeConfiguration configuration,
  required final SessionManager sessionManager,
  required final SnapshotStore snapshotStore,
  required final BundleBuilder bundleBuilder,
}) async {
  try {
    switch (topLevel.name) {
      case 'exec':
        final name = topLevel.option('name');
        if (name == null || name.isEmpty) {
          return CoreResult.failure(
            code: CoreErrorCode.invalidCommand,
            message: 'Missing required --name for exec',
          );
        }

        final rawArgs = _parseArgumentsJson(topLevel.option('args'));
        final argsResolution = resolveCommandArgumentsForExecution(
          commandName: name,
          arguments: rawArgs,
        );
        final argsResolutionError = argsResolution.error;
        if (argsResolutionError != null) {
          return argsResolutionError;
        }

        final command = catalog.buildCommand(
          name,
          argsResolution.sanitizedArgs,
        );

        final preconnectError = await _preconnectIfNeeded(
          parsed: parsed,
          command: command,
          sessionManager: sessionManager,
          executor: executor,
          explicitConnectionOverride: argsResolution.preconnectCommand,
        );
        if (preconnectError != null) {
          return preconnectError;
        }

        return executor.execute(command);

      case 'schema':
        final name = topLevel.option('name');
        final data = catalog.schema(name: name);
        return CoreResult.success(
          data: data,
          meta: {'schemaVersion': 'command-catalog/v1'},
        );

      case 'capabilities':
        final data = catalog
            .capabilities(configuration: configuration)
            .toJson();
        return CoreResult.success(
          data: data,
          meta: {'schemaVersion': 'command-catalog/v1'},
        );

      case 'snapshot':
        final snapshotCommand = topLevel.command;
        if (snapshotCommand == null) {
          return CoreResult.failure(
            code: CoreErrorCode.invalidCommand,
            message: 'Missing snapshot subcommand (create|diff)',
          );
        }

        return _runSnapshotCommand(
          snapshotCommand: snapshotCommand,
          snapshotStore: snapshotStore,
          executor: executor,
          catalog: catalog,
        );

      case 'bundle':
        final bundleCommand = topLevel.command;
        if (bundleCommand == null || bundleCommand.name != 'create') {
          return CoreResult.failure(
            code: CoreErrorCode.invalidCommand,
            message: 'Missing bundle subcommand create',
          );
        }

        final fromSnapshot = bundleCommand.option('from-snapshot');
        if (fromSnapshot == null || fromSnapshot.isEmpty) {
          return CoreResult.failure(
            code: CoreErrorCode.invalidCommand,
            message: 'Missing required --from-snapshot for bundle create',
          );
        }

        try {
          final bundle = await bundleBuilder.createBundle(
            fromSnapshot: fromSnapshot,
            outputDirectory: bundleCommand.option('output'),
          );
          return CoreResult.success(data: bundle);
        } on ArgumentError catch (e) {
          return CoreResult.failure(
            code: CoreErrorCode.snapshotNotFound,
            message: '$e',
          );
        } on Exception catch (e) {
          return CoreResult.failure(
            code: CoreErrorCode.bundleBuildFailed,
            message: 'Failed to create bundle: $e',
          );
        }

      default:
        return CoreResult.failure(
          code: CoreErrorCode.invalidCommand,
          message: 'Unsupported top-level command: ${topLevel.name}',
        );
    }
  } on ArgumentError catch (e) {
    return CoreResult.failure(
      code: CoreErrorCode.invalidCommand,
      message: '$e',
    );
  } on FormatException catch (e) {
    return CoreResult.failure(
      code: CoreErrorCode.invalidCommand,
      message: '$e',
    );
  } on Exception catch (e) {
    return CoreResult.failure(
      code: CoreErrorCode.unexpectedExecutorError,
      message: 'Unexpected CLI error: $e',
    );
  }
}

Future<CoreResult> _runSnapshotCommand({
  required final ArgResults snapshotCommand,
  required final SnapshotStore snapshotStore,
  required final DefaultCoreCommandExecutor executor,
  required final CommandCatalog catalog,
}) async {
  switch (snapshotCommand.name) {
    case 'create':
      final name = snapshotCommand.option('name');
      if (name == null || name.isEmpty) {
        return CoreResult.failure(
          code: CoreErrorCode.invalidCommand,
          message: 'Missing required --name for snapshot create',
        );
      }

      final args = _parseArgumentsJson(snapshotCommand.option('args'));
      try {
        final snapshot = await snapshotStore.createSnapshot(
          id: name,
          executor: executor,
          catalog: catalog,
          args: args,
        );
        return CoreResult.success(data: snapshot);
      } on Exception catch (e) {
        return CoreResult.failure(
          code: CoreErrorCode.snapshotInvalid,
          message: 'Failed to create snapshot: $e',
        );
      }

    case 'diff':
      final from = snapshotCommand.option('from');
      final to = snapshotCommand.option('to');

      if (from == null || from.isEmpty || to == null || to.isEmpty) {
        return CoreResult.failure(
          code: CoreErrorCode.invalidCommand,
          message: 'snapshot diff requires --from and --to',
        );
      }

      try {
        final diff = await snapshotStore.diffSnapshots(fromId: from, toId: to);
        return CoreResult.success(data: diff);
      } on ArgumentError catch (e) {
        return CoreResult.failure(
          code: CoreErrorCode.snapshotNotFound,
          message: '$e',
        );
      } on Exception catch (e) {
        return CoreResult.failure(
          code: CoreErrorCode.snapshotInvalid,
          message: 'Failed to diff snapshots: $e',
        );
      }

    default:
      return CoreResult.failure(
        code: CoreErrorCode.invalidCommand,
        message: 'Unsupported snapshot command: ${snapshotCommand.name}',
      );
  }
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
  final ConnectCommand? explicitConnectionOverride,
}) {
  return preconnectForExecution(
    command: command,
    executor: executor,
    sessionManager: sessionManager,
    explicitConnectionOverride: explicitConnectionOverride,
    explicitVmServiceUri: parsed.option(_vmServiceUri),
  );
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
  throw const FormatException('Expected JSON object for --args');
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

int _parsePositiveIntOption(
  final String? value, {
  required final int fallback,
}) {
  final parsed = int.tryParse(value ?? '');
  if (parsed == null || parsed <= 0) {
    return fallback;
  }
  return parsed;
}

String? _nonEmptyOption(final String? value) {
  if (value == null) {
    return null;
  }

  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

CoreLogger _buildLogger(final LoggingLevel minimumLevel) {
  return (final level, final message, {final logger = 'core'}) {
    if (level.index < minimumLevel.index) {
      return;
    }
    io.stderr.writeln('[${level.name}] [$logger] $message');
  };
}

String _resolveStateRoot(final String statePath) {
  final file = io.File(statePath);
  final parent = file.parent.path;
  if (parent.isEmpty || parent == '.') {
    return '.flutter_mcp';
  }
  return parent;
}

String _usage() {
  final buffer = StringBuffer()
    ..writeln('flutter_mcp_cli v2')
    ..writeln('')
    ..writeln('Usage:')
    ..writeln('  flutter_mcp_cli [global options] <command> [command options]')
    ..writeln('')
    ..writeln('Commands:')
    ..writeln(
      '  exec --name <command> --args <json> (optional args.connection for per-request target)',
    )
    ..writeln('  schema [--name <command>]')
    ..writeln('  capabilities')
    ..writeln('  serve')
    ..writeln('  snapshot create --name <id> [--args <json>]')
    ..writeln('  snapshot diff --from <id> --to <id>')
    ..writeln('  bundle create --from-snapshot <id> [--output <dir>]')
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
        'Applied after args.connection and before session attach.',
  )
  ..addOption(
    _flutterProjectDir,
    help:
        'Optional Flutter project directory used by machine discovery '
        '(flutter attach --machine)',
  )
  ..addOption(
    _flutterDevice,
    help:
        'Optional Flutter device for machine discovery '
        '(for example: chrome)',
  )
  ..addOption(
    _flutterDiscoveryTimeoutMs,
    defaultsTo: '$_defaultFlutterDiscoveryTimeoutMs',
    help:
        'Timeout in milliseconds for machine discovery '
        '(flutter attach --machine)',
  )
  ..addOption(
    _stateFile,
    defaultsTo: _defaultStateFile,
    help: 'Path to persisted CLI state file',
  )
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
  ..addFlag(_help, abbr: 'h', help: 'Show usage text')
  ..addCommand(
    'exec',
    ArgParser()
      ..addOption('name', help: 'Core command name from schema catalog')
      ..addOption(
        'args',
        defaultsTo: '{}',
        help:
            'Command args as JSON object. VM-dependent commands also accept '
            'optional args.connection: '
            '{"connection":{"targetId":"ws://127.0.0.1:8181/<token>/ws"}}',
      ),
  )
  ..addCommand('schema', ArgParser()..addOption('name'))
  ..addCommand('capabilities')
  ..addCommand('serve')
  ..addCommand(
    'snapshot',
    ArgParser()
      ..addCommand(
        'create',
        ArgParser()
          ..addOption('name')
          ..addOption('args', defaultsTo: '{}'),
      )
      ..addCommand(
        'diff',
        ArgParser()
          ..addOption('from')
          ..addOption('to'),
      ),
  )
  ..addCommand(
    'bundle',
    ArgParser()..addCommand(
      'create',
      ArgParser()
        ..addOption('from-snapshot')
        ..addOption('output'),
    ),
  );

const _defaultHost = 'localhost';
const _defaultPort = 8181;
const _defaultLogLevel = 'error';
const _defaultStateFile = '.flutter_mcp/state.json';
const _defaultFlutterDiscoveryTimeoutMs = 2500;

const _dartVmHost = 'dart-vm-host';
const _dartVmPort = 'dart-vm-port';
const _vmServiceUri = 'vm-service-uri';
const _flutterProjectDir = 'flutter-project-dir';
const _flutterDevice = 'flutter-device';
const _flutterDiscoveryTimeoutMs = 'flutter-discovery-timeout-ms';
const _stateFile = 'state-file';
const _resourcesSupported = 'resources';
const _imagesSupported = 'images';
const _dumpsSupported = 'dumps';
const _dynamicRegistrySupported = 'dynamics';
const _saveImagesToFiles = 'save-images';
const _logLevel = 'log-level';
const _help = 'help';
