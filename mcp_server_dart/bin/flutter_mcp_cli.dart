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

      case 'validate-runtime':
        return _runValidateRuntime(
          command: topLevel,
          executor: executor,
          doctorRunner: doctorRunner,
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

Future<CoreResult> _runValidateRuntime({
  required final ArgResults command,
  required final DefaultCoreCommandExecutor executor,
  required final DoctorRunner doctorRunner,
}) async {
  final timeoutMs = _parsePositiveIntOption(
    command.option('timeout-ms'),
    fallback: _defaultValidateRuntimeTimeoutMs,
  );
  final timeout = Duration(milliseconds: timeoutMs);
  final target = _nonEmptyOption(command.option('target'));
  final errorsCount = _parsePositiveIntOption(
    command.option('errors-count'),
    fallback: _defaultValidateRuntimeErrorsCount,
  );
  final connectRetries = _parseNonNegativeIntOption(
    command.option('connect-retries'),
    fallback: _defaultValidateRuntimeConnectRetries,
  );
  final afterReload = command.flag('after-reload');
  final installSkill = command.flag('install-skill');
  final forceSkillInstall = command.flag('force-skill-install');
  final skillDestination = _nonEmptyOption(command.option('skill-destination'));

  Map<String, Object?>? skillInstallData;
  if (installSkill) {
    final installResult = _installBundledSkill(
      destinationRoot: skillDestination,
      force: forceSkillInstall,
    );
    if (!installResult.ok) {
      return installResult;
    }
    skillInstallData = switch (installResult.data) {
      final Map<String, Object?> value => value,
      final Map value => value.cast<String, Object?>(),
      _ => null,
    };
  }

  final doctorData = await doctorRunner.run(target: target, timeout: timeout);
  if (_doctorHasCriticalFailures(doctorData)) {
    return CoreResult.failure(
      code: CoreErrorCode.doctorCriticalFailed,
      message: 'Runtime validation blocked by critical doctor checks.',
      details: {'doctor': doctorData},
    );
  }

  final toolkitCheck = _doctorCheckById(doctorData, 'mcp_toolkit_extensions');
  if (toolkitCheck != null && toolkitCheck['status'] == 'fail') {
    return CoreResult.failure(
      code: CoreErrorCode.getExtensionRpcsFailed,
      message:
          'Runtime validation blocked: required mcp_toolkit extensions are missing.',
      details: {
        'doctor': doctorData,
        'toolkitCheck': toolkitCheck,
        'fix':
            'Add `mcp_toolkit` to app dependencies and ensure '
            '`MCPToolkitBinding.instance..initialize()..initializeFlutterToolkit();` '
            'runs before `runApp`, then hot restart or rerun the app.',
      },
    );
  }

  final steps = <Map<String, Object?>>[];

  Future<CoreResult?> runStep(
    final String name,
    final CoreCommand coreCommand,
  ) async {
    final executed = await _executeWithRetry(
      run: () => executor.execute(coreCommand),
      maxRetries: connectRetries,
    );
    final result = executed.result;
    steps.add({
      'name': name,
      'attempts': executed.attempts,
      'ok': result.ok,
      'data': result.data,
      'error': result.error?.toJson(),
      'meta': result.meta,
    });
    if (result.ok) {
      return null;
    }
    return result;
  }

  if (target != null) {
    final connectFailure = await runStep(
      'connect_target',
      ConnectCommand(
        mode: CoreConnectionMode.uri,
        uri: target,
        forceReconnect: true,
      ),
    );
    if (connectFailure != null) {
      return CoreResult.failure(
        code: connectFailure.error?.code ?? CoreErrorCode.connectFailed,
        message:
            'Runtime validation failed: unable to connect to explicit target.',
        details: {'doctor': doctorData, 'steps': steps},
      );
    }
  }

  final extensionFailure = await runStep(
    'get_extension_rpcs',
    const GetExtensionRpcsCommand(),
  );
  if (extensionFailure != null) {
    return CoreResult.failure(
      code:
          extensionFailure.error?.code ?? CoreErrorCode.getExtensionRpcsFailed,
      message: 'Runtime validation failed at get_extension_rpcs.',
      details: {'doctor': doctorData, 'steps': steps},
    );
  }

  final extensionStep = steps.last;
  final extensionData = extensionStep['data'];
  final extensionSet = switch (extensionData) {
    final List values => values.map((final value) => '$value').toSet(),
    _ => <String>{},
  };
  final requiredExtensions = <String>{
    'ext.mcp.toolkit.app_errors',
    'ext.mcp.toolkit.view_details',
    'ext.mcp.toolkit.view_screenshots',
    'ext.mcp.toolkit.inspect_widget_at_point',
  };
  final missingExtensions = requiredExtensions.difference(extensionSet).toList()
    ..sort();
  if (missingExtensions.isNotEmpty) {
    return CoreResult.failure(
      code: CoreErrorCode.getExtensionRpcsFailed,
      message:
          'Runtime validation failed: missing required toolkit extensions.',
      details: {
        'doctor': doctorData,
        'missingExtensions': missingExtensions,
        'fix':
            'Install/initialize `mcp_toolkit` in the app, then hot restart or rerun.',
        'steps': steps,
      },
    );
  }

  final screenshotFailure = await runStep(
    'get_screenshots',
    const GetScreenshotsCommand(),
  );
  if (screenshotFailure != null) {
    return CoreResult.failure(
      code: screenshotFailure.error?.code ?? CoreErrorCode.getScreenshotsFailed,
      message: 'Runtime validation failed at get_screenshots.',
      details: {'doctor': doctorData, 'steps': steps},
    );
  }

  final viewDetailsFailure = await runStep(
    'get_view_details',
    const GetViewDetailsCommand(),
  );
  if (viewDetailsFailure != null) {
    return CoreResult.failure(
      code:
          viewDetailsFailure.error?.code ?? CoreErrorCode.getViewDetailsFailed,
      message: 'Runtime validation failed at get_view_details.',
      details: {'doctor': doctorData, 'steps': steps},
    );
  }

  final appErrorsFailure = await runStep(
    'get_app_errors',
    GetAppErrorsCommand(count: errorsCount),
  );
  if (appErrorsFailure != null) {
    return CoreResult.failure(
      code: appErrorsFailure.error?.code ?? CoreErrorCode.getAppErrorsFailed,
      message: 'Runtime validation failed at get_app_errors.',
      details: {'doctor': doctorData, 'steps': steps},
    );
  }

  if (afterReload) {
    final reloadFailure = await runStep(
      'hot_reload_flutter',
      const HotReloadFlutterCommand(),
    );
    if (reloadFailure != null) {
      return CoreResult.failure(
        code: reloadFailure.error?.code ?? CoreErrorCode.hotReloadFailed,
        message: 'Runtime validation failed at hot_reload_flutter.',
        details: {'doctor': doctorData, 'steps': steps},
      );
    }

    final afterReloadScreenshotFailure = await runStep(
      'get_screenshots_after_reload',
      const GetScreenshotsCommand(),
    );
    if (afterReloadScreenshotFailure != null) {
      return CoreResult.failure(
        code:
            afterReloadScreenshotFailure.error?.code ??
            CoreErrorCode.getScreenshotsFailed,
        message: 'Runtime validation failed at post-reload screenshot capture.',
        details: {'doctor': doctorData, 'steps': steps},
      );
    }
  }

  final failedSteps = steps.where((final step) => step['ok'] != true).length;
  final requiredSorted = requiredExtensions.toList()..sort();
  return CoreResult.success(
    data: {
      'doctor': doctorData,
      'steps': steps,
      'summary': {
        'total': steps.length,
        'success': steps.length - failedSteps,
        'failed': failedSteps,
        'target': target,
        'timeoutMs': timeoutMs,
        'connectRetries': connectRetries,
        'afterReload': afterReload,
        'errorsCount': errorsCount,
        'requiredExtensions': requiredSorted,
        'skillInstallation': skillInstallData,
      },
    },
  );
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

int _parseNonNegativeIntOption(
  final String? value, {
  required final int fallback,
}) {
  final parsed = int.tryParse(value ?? '');
  if (parsed == null || parsed < 0) {
    return fallback;
  }
  return parsed;
}

Map<String, Object?>? _doctorCheckById(
  final Map<String, Object?> doctorData,
  final String id,
) {
  final checks = doctorData['checks'];
  if (checks is! List) {
    return null;
  }

  for (final entry in checks) {
    final map = switch (entry) {
      final Map<String, Object?> value => value,
      final Map value => value.cast<String, Object?>(),
      _ => null,
    };
    if (map == null) {
      continue;
    }
    if ('${map['id'] ?? ''}' == id) {
      return map;
    }
  }

  return null;
}

bool _doctorHasCriticalFailures(final Map<String, Object?> doctorData) {
  final summary = doctorData['summary'];
  final summaryMap = switch (summary) {
    final Map<String, Object?> value => value,
    final Map value => value.cast<String, Object?>(),
    _ => null,
  };
  final criticalFailures = summaryMap?['criticalFailures'];
  if (criticalFailures is int) {
    return criticalFailures > 0;
  }
  if (criticalFailures is num) {
    return criticalFailures > 0;
  }
  return false;
}

Future<({CoreResult result, int attempts})> _executeWithRetry({
  required final Future<CoreResult> Function() run,
  required final int maxRetries,
}) async {
  var retriesUsed = 0;
  var result = await run();
  while (!result.ok && retriesUsed < maxRetries) {
    final code = result.error?.code;
    final retryable =
        code == CoreErrorCode.connectFailed ||
        code == CoreErrorCode.vmNotConnected;
    if (!retryable) {
      break;
    }

    retriesUsed += 1;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    result = await run();
  }

  return (result: result, attempts: retriesUsed + 1);
}

CoreResult _installBundledSkill({
  final String skillName = _runtimeValidationSkillName,
  final String? destinationRoot,
  final bool force = false,
}) {
  final sourceDir = _resolveBundledSkillSource(skillName);
  if (sourceDir == null) {
    return CoreResult.failure(
      code: CoreErrorCode.invalidCommand,
      message:
          'Bundled skill "$skillName" was not found in this repository layout.',
      details: {
        'expected': ['mcp_server_dart/skills/$skillName', 'skills/$skillName'],
      },
    );
  }

  final codexHome = destinationRoot ?? _defaultCodexHomePath();
  final destination = io.Directory('$codexHome/skills/$skillName');

  try {
    if (destination.existsSync()) {
      if (!force) {
        return CoreResult.failure(
          code: CoreErrorCode.writeBlocked,
          message:
              'Skill destination already exists. Re-run with --force-skill-install.',
          details: {'destination': destination.path},
        );
      }
      destination.deleteSync(recursive: true);
    }

    destination.createSync(recursive: true);
    final filesCopied = _copyDirectoryContents(
      source: sourceDir,
      destination: destination,
    );

    return CoreResult.success(
      data: {
        'skill': skillName,
        'source': sourceDir.path,
        'destination': destination.path,
        'filesCopied': filesCopied,
      },
    );
  } on Exception catch (error) {
    return CoreResult.failure(
      code: CoreErrorCode.writeBlocked,
      message: 'Failed to install skill "$skillName": $error',
      details: {'destination': destination.path},
    );
  }
}

io.Directory? _resolveBundledSkillSource(final String skillName) {
  final scriptDir = io.File(io.Platform.script.toFilePath()).parent;
  final candidates = <io.Directory>[
    io.Directory('${scriptDir.parent.path}/skills/$skillName'),
    io.Directory('mcp_server_dart/skills/$skillName'),
    io.Directory('skills/$skillName'),
  ];

  for (final candidate in candidates) {
    if (candidate.existsSync()) {
      return candidate;
    }
  }

  return null;
}

String _defaultCodexHomePath() {
  final codeHome = io.Platform.environment['CODEX_HOME']?.trim();
  if (codeHome != null && codeHome.isNotEmpty) {
    return codeHome;
  }

  final home = io.Platform.environment['HOME']?.trim();
  if (home == null || home.isEmpty) {
    return '.codex';
  }

  return '$home/.codex';
}

int _copyDirectoryContents({
  required final io.Directory source,
  required final io.Directory destination,
}) {
  var filesCopied = 0;
  for (final entity in source.listSync(followLinks: false)) {
    final name = _lastPathSegment(entity.path);
    final targetPath = '${destination.path}/$name';

    if (entity is io.Directory) {
      final targetDir = io.Directory(targetPath);
      targetDir.createSync(recursive: true);
      filesCopied += _copyDirectoryContents(
        source: entity,
        destination: targetDir,
      );
      continue;
    }

    if (entity is io.File) {
      io.File(targetPath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(entity.readAsBytesSync());
      filesCopied += 1;
    }
  }

  return filesCopied;
}

String _lastPathSegment(final String path) {
  var normalized = path;
  final separator = io.Platform.pathSeparator;
  while (normalized.endsWith(separator)) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  final parts = normalized.split(separator);
  return parts.isEmpty ? normalized : parts.last;
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
    ..writeln('  validate-runtime')
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
    'validate-runtime' => _usageValidateRuntime(),
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
  )
  ..addCommand(
    'validate-runtime',
    _commandParser()
      ..addOption(
        'target',
        help:
            'Optional explicit websocket target URI '
            '(use exact app.debugPort.wsUri).',
      )
      ..addOption(
        'timeout-ms',
        defaultsTo: '$_defaultValidateRuntimeTimeoutMs',
        help: 'Timeout used by doctor preflight in milliseconds.',
      )
      ..addOption(
        'errors-count',
        defaultsTo: '$_defaultValidateRuntimeErrorsCount',
        help: 'Number of app errors to collect from get_app_errors.',
      )
      ..addOption(
        'connect-retries',
        defaultsTo: '$_defaultValidateRuntimeConnectRetries',
        help:
            'Retries for transient connect/vm_not_connected failures per step.',
      )
      ..addFlag(
        'after-reload',
        defaultsTo: false,
        help:
            'Also run hot_reload_flutter and capture one more screenshot after reload.',
      )
      ..addFlag(
        'install-skill',
        defaultsTo: false,
        help:
            'Install bundled Codex runtime-validation skill before running checks.',
      )
      ..addOption(
        'skill-destination',
        help:
            'Optional destination root for skill install '
            '(defaults to \$CODEX_HOME/skills).',
      )
      ..addFlag(
        'force-skill-install',
        defaultsTo: false,
        help: 'Replace existing skill directory when using --install-skill.',
      ),
  );

const _defaultHost = 'localhost';
const _defaultPort = 8181;
const _defaultLogLevel = 'error';
const _defaultStateFile = '.flutter_mcp/state.json';
const _defaultFlutterDiscoveryTimeoutMs = 2500;
const _defaultDoctorTimeoutMs = 2500;
const _defaultValidateRuntimeTimeoutMs = 10000;
const _defaultValidateRuntimeErrorsCount = 5;
const _defaultValidateRuntimeConnectRetries = 1;
const _runtimeValidationSkillName = 'flutter-mcp-cli-runtime-validation';

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
  1) get_extension_rpcs -> confirm ext.mcp.toolkit.app_errors/view_details/view_screenshots/inspect_widget_at_point
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

String _usageValidateRuntime() =>
    '''
Usage: flutter_mcp_cli validate-runtime [--target <ws_uri>] [--timeout-ms <n>] [--errors-count <n>] [--connect-retries <n>] [--after-reload] [--install-skill] [--skill-destination <dir>] [--force-skill-install]

Two-step agent flow:
  1) Start Flutter app in debug mode
  2) Run this command

Examples:
  flutter_mcp_cli validate-runtime --target ws://127.0.0.1:8181/<token>/ws --timeout-ms 10000
  flutter_mcp_cli --save-images validate-runtime --target ws://127.0.0.1:8181/<token>/ws --after-reload
  flutter_mcp_cli validate-runtime --target ws://127.0.0.1:8181/<token>/ws --install-skill

  What it does:
  - doctor preflight (including mcp_toolkit extension gate)
  - get_extension_rpcs
  - get_screenshots
  - get_view_details
  - get_app_errors
  - optional hot_reload + screenshot

If toolkit extensions are missing, add `mcp_toolkit` to app dependencies and
initialize `MCPToolkitBinding.instance..initialize()..initializeFlutterToolkit();`
before `runApp`, then hot restart or rerun.

Transient first-connect failures are retried automatically for connect/vm_not_connected errors.
Optional skill installation copies mcp_server_dart/skills/$_runtimeValidationSkillName to \$CODEX_HOME/skills.
''';
