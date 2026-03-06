#!/usr/bin/env dart
// ignore_for_file: do_not_use_environment

import 'dart:convert';
import 'dart:io' as io;

import 'package:args/args.dart';
import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/flutter_mcp_core.dart';

Future<void> main(final List<String> args) async {
  late final ArgResults parsed;
  try {
    parsed = _argParser.parse(args);
  } on FormatException catch (error) {
    final result = CoreResult.failure(
      code: CoreErrorCode.invalidCommand,
      message: 'Failed to parse arguments: ${error.message}',
    );
    io.stdout.writeln(jsonEncode(result.toEnvelopeJson()));
    io.exit(result.exitCode);
  }

  final helpPath = _helpCommandPath(parsed);
  final showGlobalHelp =
      (parsed.wasParsed(_help) && parsed.flag(_help) && helpPath == null) ||
      parsed.command == null;
  if (showGlobalHelp) {
    io.stdout.writeln(_globalUsage());
    io.exit(0);
  }

  if (helpPath != null) {
    io.stdout.writeln(_usageForCommand(helpPath));
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
  final doctorRunner = DoctorRunner(
    connectionContext: connectionContext,
    executor: executor,
    stateFilePath: statePath,
    dynamicRegistrySupported: configuration.dynamicRegistrySupported,
    logger: logger,
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
    doctorRunner: doctorRunner,
  );

  io.stdout.writeln(jsonEncode(result.toEnvelopeJson()));
  await connectionContext.disconnect();
  io.exit(_resolveExitCode(topLevel: command, result: result));
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
  required final DoctorRunner doctorRunner,
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
          meta: {'schemaVersion': kCommandCatalogSchemaVersion},
        );

      case 'capabilities':
        final data = catalog
            .capabilities(configuration: configuration)
            .toJson();
        return CoreResult.success(
          data: data,
          meta: {'schemaVersion': kCommandCatalogSchemaVersion},
        );

      case 'doctor':
        final timeoutMs = _parsePositiveIntOption(
          topLevel.option('timeout-ms'),
          fallback: _defaultDoctorTimeoutMs,
        );
        final data = await doctorRunner.run(
          target: _nonEmptyOption(topLevel.option('target')),
          timeout: Duration(milliseconds: timeoutMs),
        );
        return CoreResult.success(data: data);

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
          final writeOptions = _safeWriteOptionsFrom(bundleCommand);
          final bundle = await bundleBuilder.createBundle(
            fromSnapshot: fromSnapshot,
            outputDirectory: bundleCommand.option('output'),
            writeOptions: writeOptions,
          );
          if (_containsBlockedWrite(bundle)) {
            return CoreResult.failure(
              code: CoreErrorCode.writeBlocked,
              message:
                  'Bundle output already exists and is blocked by --no-overwrite',
              details: bundle,
            );
          }
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
      final writeOptions = _safeWriteOptionsFrom(snapshotCommand);
      try {
        final snapshot = await snapshotStore.createSnapshot(
          id: name,
          executor: executor,
          catalog: catalog,
          args: args,
          writeOptions: writeOptions,
        );
        if (_containsBlockedWrite(snapshot)) {
          return CoreResult.failure(
            code: CoreErrorCode.writeBlocked,
            message:
                'Snapshot target already exists and is blocked by --no-overwrite',
            details: snapshot,
          );
        }
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

SafeWriteOptions _safeWriteOptionsFrom(final ArgResults command) {
  return SafeWriteOptions(
    check: command.flag(_check),
    diff: command.flag(_diff),
    backup: command.flag(_backup),
    noOverwrite: command.flag(_noOverwrite),
  );
}

bool _containsBlockedWrite(final Object? payload) {
  final map = switch (payload) {
    final Map<String, Object?> value => value,
    final Map value => value.cast<String, Object?>(),
    _ => null,
  };
  if (map == null) {
    return false;
  }

  final writeResults = map['writeResults'];
  if (writeResults is! List) {
    return false;
  }

  for (final entry in writeResults) {
    if (entry is! Map) {
      continue;
    }
    if ('${entry['status'] ?? ''}' == SafeWriteStatus.blocked) {
      return true;
    }
  }
  return false;
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

String _globalUsage() {
  final buffer = StringBuffer()
    ..writeln('$kFlutterMcpCliName v$kFlutterMcpVersion')
    ..writeln('')
    ..writeln('Usage:')
    ..writeln('  flutter_mcp_cli [global options] <command> [command options]')
    ..writeln('')
    ..writeln('Commands:')
    ..writeln('  exec')
    ..writeln('  schema')
    ..writeln('  capabilities')
    ..writeln('  serve')
    ..writeln('  snapshot create')
    ..writeln('  snapshot diff')
    ..writeln('  bundle create')
    ..writeln('  doctor')
    ..writeln('')
    ..writeln('Global options:')
    ..writeln(_argParser.usage)
    ..writeln('')
    ..writeln(
      'Use `flutter_mcp_cli <command> --help` for contextual examples.',
    );
  return buffer.toString();
}

String _usageForCommand(final List<String> commandPath) {
  final key = commandPath.join(' ');
  return switch (key) {
    'exec' => _usageExec(),
    'schema' => _usageSchema(),
    'capabilities' => _usageCapabilities(),
    'serve' => _usageServe(),
    'snapshot' => _usageSnapshot(),
    'snapshot create' => _usageSnapshotCreate(),
    'snapshot diff' => _usageSnapshotDiff(),
    'bundle' => _usageBundle(),
    'bundle create' => _usageBundleCreate(),
    'doctor' => _usageDoctor(),
    _ => _globalUsage(),
  };
}

List<String>? _helpCommandPath(final ArgResults parsed) {
  final path = <String>[];
  List<String>? selectedPath;
  var cursor = parsed.command;
  while (cursor != null) {
    if (cursor.name != null && cursor.name!.isNotEmpty) {
      path.add(cursor.name!);
    }
    if (cursor.wasParsed(_help) && cursor.flag(_help)) {
      selectedPath = List<String>.from(path);
    }
    cursor = cursor.command;
  }
  return selectedPath;
}

int _resolveExitCode({
  required final ArgResults topLevel,
  required final CoreResult result,
}) {
  if (topLevel.name != 'doctor') {
    return result.exitCode;
  }

  final data = result.data;
  if (data is! Map) {
    return result.exitCode;
  }

  final checks = data['checks'];
  if (checks is! List) {
    return result.exitCode;
  }

  final hasCriticalFailure = checks.any((final check) {
    if (check is! Map) {
      return false;
    }
    return check['critical'] == true && check['status'] == 'fail';
  });

  return hasCriticalFailure
      ? exitCodeForErrorCode(CoreErrorCode.doctorCriticalFailed)
      : result.exitCode;
}

ArgParser _commandParser() => ArgParser()..addFlag(_help, abbr: 'h');

final _argParser = ArgParser(allowTrailingOptions: false)
  ..addOption(
    _dartVmHost,
    defaultsTo: _defaultHost,
    help:
        'Fallback host for manual VM connection (prefer args.connection.uri for explicit targeting)',
  )
  ..addOption(
    _dartVmPort,
    defaultsTo: '$_defaultPort',
    help:
        'Fallback port for manual VM connection (prefer args.connection.uri for explicit targeting)',
  )
  ..addOption(
    _vmServiceUri,
    help:
        'Optional full VM service websocket URI '
        '(e.g. ws://127.0.0.1:8181/<token>/ws). '
        'Paste app.debugPort.wsUri exactly. '
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
    _commandParser()
      ..addOption('name', help: 'Core command name from schema catalog')
      ..addOption(
        'args',
        defaultsTo: '{}',
        help:
            'Command args as JSON object. VM-dependent commands also accept '
            'optional args.connection. Safest form: '
            '{"connection":{"uri":"ws://127.0.0.1:8181/<token>/ws"}}. '
            'targetId also works when copied from discover_debug_apps/availableTargets. '
            'Never pass host:port as targetId.',
      ),
  )
  ..addCommand('schema', _commandParser()..addOption('name'))
  ..addCommand('capabilities', _commandParser())
  ..addCommand('serve', _commandParser())
  ..addCommand(
    'snapshot',
    _commandParser()
      ..addCommand(
        'create',
        _commandParser()
          ..addOption('name')
          ..addOption('args', defaultsTo: '{}')
          ..addFlag(
            _check,
            defaultsTo: false,
            help: 'Evaluate changes without writing files',
          )
          ..addFlag(
            _diff,
            defaultsTo: false,
            help: 'Attach unified diff metadata per changed target',
          )
          ..addFlag(
            _backup,
            defaultsTo: false,
            help: 'Create timestamped backups before replacing targets',
          )
          ..addFlag(
            _noOverwrite,
            defaultsTo: false,
            help: 'Block writes when target already exists',
          ),
      )
      ..addCommand(
        'diff',
        _commandParser()
          ..addOption('from')
          ..addOption('to'),
      ),
  )
  ..addCommand(
    'bundle',
    _commandParser()..addCommand(
      'create',
      _commandParser()
        ..addOption('from-snapshot')
        ..addOption('output')
        ..addFlag(
          _check,
          defaultsTo: false,
          help: 'Evaluate changes without writing files',
        )
        ..addFlag(
          _diff,
          defaultsTo: false,
          help: 'Attach unified diff metadata per changed target',
        )
        ..addFlag(
          _backup,
          defaultsTo: false,
          help: 'Create timestamped backups before replacing targets',
        )
        ..addFlag(
          _noOverwrite,
          defaultsTo: false,
          help: 'Block writes when target already exists',
        ),
    ),
  )
  ..addCommand(
    'doctor',
    _commandParser()
      ..addFlag('json', defaultsTo: false, help: 'Emit machine-readable JSON')
      ..addOption(
        'target',
        help:
            'Optional explicit websocket target URI to test reachability '
            '(use exact app.debugPort.wsUri).',
      )
      ..addOption(
        'timeout-ms',
        defaultsTo: '$_defaultDoctorTimeoutMs',
        help: 'Per-check timeout in milliseconds',
      ),
  );

const _defaultHost = 'localhost';
const _defaultPort = 8181;
const _defaultLogLevel = 'error';
const _defaultStateFile = '.flutter_mcp/state.json';
const _defaultFlutterDiscoveryTimeoutMs = 2500;
const _defaultDoctorTimeoutMs = 2500;

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
const _check = 'check';
const _diff = 'diff';
const _backup = 'backup';
const _noOverwrite = 'no-overwrite';

String _usageExec() => '''
Usage: flutter_mcp_cli exec --name <command> [--args <json>]

Examples:
  flutter_mcp_cli exec --name status --args '{}'
  flutter_mcp_cli exec --name get_vm --args '{"connection":{"uri":"ws://127.0.0.1:8181/<token>/ws"}}'
  flutter_mcp_cli exec --name get_extension_rpcs --args '{}'
  flutter_mcp_cli exec --name get_screenshots --args '{}'
  flutter_mcp_cli exec --name get_view_details --args '{}'

CLI-first runtime validation sequence:
  1) get_extension_rpcs -> confirm ext.mcp.toolkit.app_errors/view_details/view_screenshots
  2) get_screenshots + get_view_details -> visual/layout baseline
  3) get_app_errors -> runtime error context

If connection_selection_required appears:
  retry with args.connection.targetId or args.connection.uri (exact app.debugPort.wsUri).
''';

String _usageSchema() => '''
Usage: flutter_mcp_cli schema [--name <command>]

Examples:
  flutter_mcp_cli schema
  flutter_mcp_cli schema --name get_vm
''';

String _usageCapabilities() => '''
Usage: flutter_mcp_cli capabilities

Examples:
  flutter_mcp_cli capabilities
''';

String _usageServe() => '''
Usage: flutter_mcp_cli serve

Examples:
  flutter_mcp_cli serve
''';

String _usageSnapshot() => '''
Usage:
  flutter_mcp_cli snapshot create ...
  flutter_mcp_cli snapshot diff ...

Examples:
  flutter_mcp_cli snapshot create --name baseline --args '{"commands":[{"name":"status","args":{}}]}'
  flutter_mcp_cli snapshot diff --from baseline --to current
''';

String _usageSnapshotCreate() => '''
Usage: flutter_mcp_cli snapshot create --name <id> [--args <json>] [--check] [--diff] [--backup] [--no-overwrite]

Examples:
  flutter_mcp_cli snapshot create --name baseline --args '{"commands":[{"name":"status","args":{}}]}'
  flutter_mcp_cli snapshot create --name baseline --check --diff
''';

String _usageSnapshotDiff() => '''
Usage: flutter_mcp_cli snapshot diff --from <id> --to <id>

Examples:
  flutter_mcp_cli snapshot diff --from baseline --to after_fix
''';

String _usageBundle() => '''
Usage:
  flutter_mcp_cli bundle create ...

Examples:
  flutter_mcp_cli bundle create --from-snapshot baseline --output .flutter_mcp/bundles/baseline
''';

String _usageBundleCreate() => '''
Usage: flutter_mcp_cli bundle create --from-snapshot <id> [--output <dir>] [--check] [--diff] [--backup] [--no-overwrite]

Examples:
  flutter_mcp_cli bundle create --from-snapshot baseline --output ./bundle_out
  flutter_mcp_cli bundle create --from-snapshot baseline --check --diff
''';

String _usageDoctor() => '''
Usage: flutter_mcp_cli doctor [--json] [--target <ws_uri>] [--timeout-ms <n>]

Examples:
  flutter_mcp_cli doctor
  flutter_mcp_cli doctor --json --target ws://127.0.0.1:8181/<token>/ws --timeout-ms 4000

Doctor checks include:
  - VM reachability
  - required mcp_toolkit extensions for app inspection
  - dynamic registry availability

If mcp_toolkit_extensions fails, screenshot/layout/error inspection is not reliable
until app instrumentation is fixed and app is hot restarted or rerun.
''';
