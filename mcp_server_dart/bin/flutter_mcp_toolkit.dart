#!/usr/bin/env dart
// ignore_for_file: do_not_use_environment

import 'dart:convert';
import 'dart:io' as io;

import 'package:args/args.dart';
import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_server/flutter_mcp_core.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/desktop_capture_recovery.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/platform_view_hints.dart';
import 'package:flutter_mcp_toolkit_server/src/cli/codegen_init_command.dart';
import 'package:flutter_mcp_toolkit_server/src/cli/codegen_sync_command.dart';
import 'package:flutter_mcp_toolkit_server/src/cli/init_command.dart';
import 'package:flutter_mcp_toolkit_server/src/cli/init_mode.dart';
import 'package:flutter_mcp_toolkit_server/src/cli/init_target.dart';
import 'package:flutter_mcp_toolkit_server/src/cli/migrate_agent_entries_command.dart';

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

  if (parsed.command?.name == 'init') {
    io.exit(await _runInitSubcommand(parsed.command!));
  }
  if (parsed.command?.name == 'codegen-init') {
    io.exit(await _runCodegenInitSubcommand(parsed.command!));
  }
  if (parsed.command?.name == 'migrate') {
    io.exit(await _runMigrateSubcommand(parsed.command!));
  }
  if (parsed.command?.name == 'codegen') {
    io.exit(await _runCodegenSubcommand(parsed.command!));
  }
  final logLevel = _parseLogLevel(parsed.option(_logLevel));
  final logger = _buildLogger(logLevel);

  final statePath = parsed.option(_stateFile) ?? _defaultStateFile;
  final stateRoot = _resolveStateRoot(statePath);
  final outputDir = _resolveOutputDir(parsed.option(_outputDir));

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
    flutterProjectDir: flutterProjectDir,
    flutterDevice: flutterDevice,
    stateRootDir: stateRoot,
    outputDir: outputDir,
    webBrowserDebuggingPort: int.tryParse(
      parsed.option(_webBrowserDebuggingPort) ?? '',
    ),
    webPort: int.tryParse(parsed.option(_webPort) ?? ''),
  );

  final executor = DefaultCoreCommandExecutor(
    connectionContext: connectionContext,
    portScanner: portScanner,
    imageFileSaver: CoreImageFileSaver(
      logger: logger,
      baseDirectory: outputDir ?? stateRoot,
    ),
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

  _printInteractiveNarrativeIfNeeded(topLevel: command, result: result);
  await _writeResultArtifactIfNeeded(
    topLevel: command,
    result: result,
    outputDir: outputDir,
  );
  final prettyPrintEnvelope = command.name == 'exec' && command.flag('pretty');
  final envelopeJson = result.toEnvelopeJson();
  io.stdout.writeln(
    prettyPrintEnvelope
        ? const JsonEncoder.withIndent('  ').convert(envelopeJson)
        : jsonEncode(envelopeJson),
  );
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

        return _executeExecCommand(
          parsed: parsed,
          executor: executor,
          catalog: catalog,
          sessionManager: sessionManager,
          name: name,
          rawArgs: _parseArgumentsJson(topLevel.option('args')),
        );

      case 'batch':
        return _runBatchCommand(
          parsed: parsed,
          command: topLevel,
          executor: executor,
          catalog: catalog,
          sessionManager: sessionManager,
        );

      case 'schema':
        final name = topLevel.option('name');
        final data = catalog.schema(name: name);
        return CoreResult.success(
          data: data,
          meta: const {'schemaVersion': kCommandCatalogSchemaVersion},
        );

      case 'capabilities':
        final data = catalog
            .capabilities(configuration: configuration)
            .toJson();
        return CoreResult.success(
          data: data,
          meta: const {'schemaVersion': kCommandCatalogSchemaVersion},
        );

      case 'doctor':
        final timeoutMs = _parsePositiveIntOption(
          topLevel.option('timeout-ms'),
          fallback: _defaultDoctorTimeoutMs,
        );
        final data = await doctorRunner.run(
          target: _resolveVmTargetUri(command: topLevel, parsed: parsed),
          timeout: Duration(milliseconds: timeoutMs),
        );
        return CoreResult.success(data: data);

      case 'permissions':
        return _runPermissionsCommand(
          parsed: parsed,
          command: topLevel,
          configuration: configuration,
          executor: executor,
          sessionManager: sessionManager,
        );

      case 'validate-runtime':
        return _runValidateRuntime(
          parsed: parsed,
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
          // ignore: avoid_catching_errors
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
    // ignore: avoid_catching_errors
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

Future<CoreResult> _runBatchCommand({
  required final ArgResults parsed,
  required final ArgResults command,
  required final DefaultCoreCommandExecutor executor,
  required final CommandCatalog catalog,
  required final SessionManager sessionManager,
}) async {
  final steps = _parseBatchStepsJson(command.option('steps'));
  if (steps.isEmpty) {
    return CoreResult.failure(
      code: CoreErrorCode.invalidCommand,
      message: 'Batch requires at least one step.',
    );
  }

  final continueOnError = command.flag('continue-on-error');
  final stepResults = <Map<String, Object?>>[];
  CoreResult? firstFailure;

  for (var index = 0; index < steps.length; index += 1) {
    final step = steps[index];
    final result = await _executeExecCommand(
      parsed: parsed,
      executor: executor,
      catalog: catalog,
      sessionManager: sessionManager,
      name: step.name,
      rawArgs: step.args,
    );
    stepResults.add({
      'index': index,
      'name': step.name,
      'args': step.args,
      'ok': result.ok,
      'data': result.data,
      'error': result.error?.toJson(),
      'meta': result.meta,
    });
    if (result.ok) {
      continue;
    }
    firstFailure ??= result;
    if (!continueOnError) {
      break;
    }
  }

  final failureCount = stepResults
      .where((final result) => result['ok'] != true)
      .length;
  final summary = <String, Object?>{
    'total': steps.length,
    'executed': stepResults.length,
    'success': stepResults.length - failureCount,
    'failed': failureCount,
    'continueOnError': continueOnError,
  };
  final payload = <String, Object?>{'steps': stepResults, 'summary': summary};
  if (firstFailure == null) {
    return CoreResult.success(data: payload);
  }

  return CoreResult.failure(
    code: firstFailure.error?.code ?? CoreErrorCode.unexpectedExecutorError,
    message: continueOnError
        ? 'Batch completed with failed steps.'
        : 'Batch stopped after a failed step.',
    details: payload,
  );
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
        // ignore: avoid_catching_errors
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
  required final ArgResults parsed,
  required final ArgResults command,
  required final DefaultCoreCommandExecutor executor,
  required final DoctorRunner doctorRunner,
}) async {
  final timeoutMs = _parsePositiveIntOption(
    command.option('timeout-ms'),
    fallback: _defaultValidateRuntimeTimeoutMs,
  );
  final timeout = Duration(milliseconds: timeoutMs);
  final target = _resolveVmTargetUri(command: command, parsed: parsed);
  final errorsCount = _parsePositiveIntOption(
    command.option('errors-count'),
    fallback: _defaultValidateRuntimeErrorsCount,
  );
  final connectRetries = _parseNonNegativeIntOption(
    command.option('connect-retries'),
    fallback: _defaultValidateRuntimeConnectRetries,
  );
  final postReloadDelayMs = _parseNonNegativeIntOption(
    command.option('post-reload-delay-ms'),
    fallback: _defaultValidateRuntimePostReloadDelayMs,
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
  final resolvedTarget = <String, Object?>{
    'requestedUri': target,
    'selectedUri':
        target ??
        executor.connectionContext.activeEndpoint?.display ??
        executor.connectionContext.stickyEndpoint?.display,
  };

  Future<CoreResult?> runStep(
    final String name,
    final CoreCommand coreCommand, {
    final bool Function(CoreResult result)? shouldRetry,
  }) async {
    final executed = await _executeWithRetry(
      run: () => executor.execute(coreCommand),
      maxRetries: connectRetries,
      shouldRetry: shouldRetry,
    );
    final result = executed.result;
    steps.add({
      'name': name,
      'attempts': executed.attempts,
      'retries': executed.attempts - 1,
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
        details: {
          'doctor': doctorData,
          'steps': steps,
          'target': resolvedTarget,
          'failureKind': 'bad_target_uri_or_unreachable_vm_service',
        },
      );
    }
    resolvedTarget['selectedUri'] =
        executor.connectionContext.activeEndpoint?.display ??
        resolvedTarget['selectedUri'];
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
      details: {'doctor': doctorData, 'steps': steps, 'target': resolvedTarget},
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
        'target': resolvedTarget,
        'missingExtensions': missingExtensions,
        'failureKind': 'missing_mcp_toolkit_wiring',
        'fix':
            'Install/initialize `mcp_toolkit` in the app, then hot restart or rerun.',
        'steps': steps,
      },
    );
  }

  var capturePlatformViewsDetected = false;
  var captureFocusAttempted = false;

  final viewDetailsProbe = await runStep(
    'get_view_details_capture_probe',
    const GetViewDetailsCommand(),
  );
  if (viewDetailsProbe == null) {
    final probeData = _stepPayloadIfOk(steps, 'get_view_details_capture_probe');
    capturePlatformViewsDetected = _platformViewsDetectedInPayload(probeData);
  }

  CoreResult? snapshotFailure = await runStep(
    'capture_ui_snapshot',
    const CaptureUiSnapshotCommand(
      includeViewDetails: false,
      includeErrors: false,
      permissionPolicy: PermissionPolicy.autoRequestOnce,
    ),
  );
  capturePlatformViewsDetected =
      capturePlatformViewsDetected || _captureHintsPlatformViewsDetected(steps);
  captureFocusAttempted = _desktopCaptureRetriedInSteps(steps);
  if (snapshotFailure != null &&
      !shouldSkipFlutterLayerFallback(
        _platformViewHintsFromDetected(capturePlatformViewsDetected),
      ) &&
      _eligibleForFlutterLayerCaptureRetry(snapshotFailure)) {
    snapshotFailure = await runStep(
      'capture_ui_snapshot_flutter_layer',
      const CaptureUiSnapshotCommand(
        includeViewDetails: false,
        includeErrors: false,
        permissionPolicy: PermissionPolicy.autoRequestOnce,
        screenshotMode: ScreenshotMode.flutterLayer,
      ),
    );
  }
  if (snapshotFailure != null) {
    return CoreResult.failure(
      code: snapshotFailure.error?.code ?? CoreErrorCode.getScreenshotsFailed,
      message: 'Runtime validation failed at capture_ui_snapshot.',
      details: {
        'doctor': doctorData,
        'steps': steps,
        'target': resolvedTarget,
        'failureKind': _captureFailureKind(snapshotFailure),
      },
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
      details: {'doctor': doctorData, 'steps': steps, 'target': resolvedTarget},
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
      details: {'doctor': doctorData, 'steps': steps, 'target': resolvedTarget},
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
        details: {
          'doctor': doctorData,
          'steps': steps,
          'target': resolvedTarget,
        },
      );
    }

    if (postReloadDelayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: postReloadDelayMs));
    }

    CoreResult? afterReloadSnapshotFailure = await runStep(
      'capture_ui_snapshot_after_reload',
      const CaptureUiSnapshotCommand(
        includeViewDetails: false,
        includeErrors: false,
        permissionPolicy: PermissionPolicy.autoRequestOnce,
      ),
      shouldRetry: _shouldRetryPostReloadCapture,
    );
    captureFocusAttempted =
        captureFocusAttempted || _desktopCaptureRetriedInSteps(steps);
    if (afterReloadSnapshotFailure != null &&
        !shouldSkipFlutterLayerFallback(
          _platformViewHintsFromDetected(capturePlatformViewsDetected),
        ) &&
        _eligibleForFlutterLayerCaptureRetry(afterReloadSnapshotFailure)) {
      afterReloadSnapshotFailure = await runStep(
        'capture_ui_snapshot_after_reload_flutter_layer',
        const CaptureUiSnapshotCommand(
          includeViewDetails: false,
          includeErrors: false,
          permissionPolicy: PermissionPolicy.autoRequestOnce,
          screenshotMode: ScreenshotMode.flutterLayer,
        ),
        shouldRetry: _shouldRetryPostReloadCapture,
      );
    }
    if (afterReloadSnapshotFailure != null) {
      return CoreResult.failure(
        code:
            afterReloadSnapshotFailure.error?.code ??
            CoreErrorCode.getScreenshotsFailed,
        message:
            'Runtime validation failed at post-reload capture_ui_snapshot.',
        details: {
          'doctor': doctorData,
          'steps': steps,
          'target': resolvedTarget,
          'failureKind': _captureFailureKind(afterReloadSnapshotFailure),
        },
      );
    }
  }

  final failedSteps = steps.where((final step) => step['ok'] != true).length;
  final requiredSorted = requiredExtensions.toList()..sort();
  final primaryCapture = _effectiveValidateRuntimeCaptureData(
    steps,
    primary: 'capture_ui_snapshot',
    flutterLayerFallback: 'capture_ui_snapshot_flutter_layer',
  );
  final postReloadCapture = _effectiveValidateRuntimeCaptureData(
    steps,
    primary: 'capture_ui_snapshot_after_reload',
    flutterLayerFallback: 'capture_ui_snapshot_after_reload_flutter_layer',
  );
  final captureFallbackUsed = _validateRuntimeUsedFlutterLayerFallback(steps);
  return CoreResult.success(
    data: {
      'doctor': doctorData,
      'steps': steps,
      'summary': {
        'total': steps.length,
        'success': steps.length - failedSteps,
        'failed': failedSteps,
        'target': resolvedTarget,
        'timeoutMs': timeoutMs,
        'connectRetries': connectRetries,
        'postReloadDelayMs': postReloadDelayMs,
        'afterReload': afterReload,
        'errorsCount': errorsCount,
        'visualCaptureCommand': 'capture_ui_snapshot',
        'requiredExtensions': requiredSorted,
        'captureFallbackUsed': captureFallbackUsed,
        'capturePlatformViewsDetected': capturePlatformViewsDetected,
        'captureFocusAttempted': captureFocusAttempted,
        'captureBackend':
            _captureBackend(primaryCapture) ??
            _captureBackend(postReloadCapture),
        'captureMode':
            _captureMode(primaryCapture) ?? _captureMode(postReloadCapture),
        'screenshotFiles': _screenshotFiles(steps),
        'retryCounts': {
          for (final step in steps) '${step['name']}': step['retries'] ?? 0,
        },
        'skillInstallation': skillInstallData,
      },
    },
  );
}

Future<CoreResult> _runPermissionsCommand({
  required final ArgResults parsed,
  required final ArgResults command,
  required final CoreRuntimeConfiguration configuration,
  required final DefaultCoreCommandExecutor executor,
  required final SessionManager sessionManager,
}) async {
  final actionCommand = command.command;
  if (actionCommand == null) {
    return CoreResult.failure(
      code: CoreErrorCode.invalidCommand,
      message: 'Missing permissions action (status|request|open-settings)',
    );
  }

  final broker = VisualCaptureBroker(
    configuration: configuration,
    dynamicGateway: configuration.dynamicRegistrySupported
        ? VmExtensionDynamicGateway(
            connectionContext: executor.connectionContext,
          )
        : null,
    adapters: executor.visualCaptureAdapters,
  );
  if (broker.adapter.owner == PermissionOwner.app) {
    final preconnectError = await _preconnectIfNeeded(
      parsed: parsed,
      command: const GetVmCommand(),
      sessionManager: sessionManager,
      executor: executor,
    );
    if (preconnectError != null) {
      return preconnectError;
    }
  }
  final kind = parsePermissionKind(actionCommand.option('kind'));
  final result = switch (actionCommand.name) {
    'status' => await broker.status(kind: kind),
    'request' => await broker.request(kind: kind),
    'open-settings' => await broker.openSettings(kind: kind),
    _ => null,
  };
  if (result == null) {
    return CoreResult.failure(
      code: CoreErrorCode.invalidCommand,
      message: 'Unsupported permissions action: ${actionCommand.name}',
    );
  }
  return CoreResult.success(data: result.toJson());
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
}) => preconnectForExecution(
  command: command,
  executor: executor,
  sessionManager: sessionManager,
  explicitConnectionOverride: explicitConnectionOverride,
  explicitVmServiceUri: parsed.option(_vmServiceUri),
);

Future<CoreResult> _executeExecCommand({
  required final ArgResults parsed,
  required final DefaultCoreCommandExecutor executor,
  required final CommandCatalog catalog,
  required final SessionManager sessionManager,
  required final String name,
  required final Map<String, Object?> rawArgs,
}) async {
  try {
    final effectiveArgs = _applyCliPermissionDefaults(name, rawArgs);
    final argsResolution = resolveCommandArgumentsForExecution(
      commandName: name,
      arguments: effectiveArgs,
    );
    final argsResolutionError = argsResolution.error;
    if (argsResolutionError != null) {
      return argsResolutionError;
    }

    final command = catalog.buildCommand(name, argsResolution.sanitizedArgs);
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
    // ignore: avoid_catching_errors
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

Map<String, Object?> _applyCliPermissionDefaults(
  final String name,
  final Map<String, Object?> rawArgs,
) {
  final withDefaults = Map<String, Object?>.from(rawArgs);
  if (withDefaults.containsKey('permissionPolicy')) {
    return withDefaults;
  }
  if (name == 'get_screenshots' || name == 'capture_ui_snapshot') {
    withDefaults['permissionPolicy'] =
        PermissionPolicy.autoRequestOnce.wireName;
  }
  return withDefaults;
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

List<_BatchStep> _parseBatchStepsJson(final String? value) {
  if (value == null || value.isEmpty) {
    throw const FormatException('Expected JSON array for --steps');
  }

  final decoded = jsonDecode(value);
  if (decoded is! List) {
    throw const FormatException('Expected JSON array for --steps');
  }

  return decoded.indexed
      .map((final entry) {
        final (index, rawStep) = entry;
        final step = switch (rawStep) {
          final Map<String, Object?> value => value,
          final Map value => value.cast<String, Object?>(),
          _ => throw FormatException(
            'Expected JSON object for batch step ${index + 1}',
          ),
        };
        final name = '${step['name'] ?? ''}'.trim();
        if (name.isEmpty) {
          throw FormatException('Batch step ${index + 1} is missing "name"');
        }
        final args = switch (step['args']) {
          null => <String, Object?>{},
          final Map<String, Object?> value => value,
          final Map value => value.cast<String, Object?>(),
          _ => throw FormatException(
            'Batch step ${index + 1} "args" must be a JSON object',
          ),
        };
        return _BatchStep(name: name, args: args);
      })
      .toList(growable: false);
}

SafeWriteOptions _safeWriteOptionsFrom(final ArgResults command) =>
    SafeWriteOptions(
      check: command.flag(_check),
      diff: command.flag(_diff),
      backup: command.flag(_backup),
      noOverwrite: command.flag(_noOverwrite),
    );

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

LoggingLevel _parseLogLevel(final String? level) => switch (level) {
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
  final bool Function(CoreResult result)? shouldRetry,
}) async {
  var retriesUsed = 0;
  var result = await run();
  while (!result.ok && retriesUsed < maxRetries) {
    final code = result.error?.code;
    final retryable =
        shouldRetry?.call(result) ??
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
        'expected': [
          'plugin/skills/$skillName',
          'mcp_server_dart/skills/$skillName',
          'skills/$skillName',
        ],
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
  final repoRoot = scriptDir.parent.parent;
  final candidates = <io.Directory>[
    io.Directory('${repoRoot.path}/plugin/skills/$skillName'),
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

CoreLogger _buildLogger(final LoggingLevel minimumLevel) =>
    (final level, final message, {final logger = 'core'}) {
      if (level.index < minimumLevel.index) {
        return;
      }
      io.stderr.writeln('[${level.name}] [$logger] $message');
    };

String _resolveStateRoot(final String statePath) {
  final file = io.File(statePath);
  final parent = file.parent.path;
  if (parent.isEmpty || parent == '.') {
    return '.flutter_mcp';
  }
  return parent;
}

String? _resolveOutputDir(final String? value) => _nonEmptyOption(value);

Future<void> _writeResultArtifactIfNeeded({
  required final ArgResults topLevel,
  required final CoreResult result,
  required final String? outputDir,
}) async {
  if (outputDir == null) {
    return;
  }
  if (topLevel.name != 'validate-runtime') {
    return;
  }

  final directory = io.Directory(outputDir);
  if (!directory.existsSync()) {
    await directory.create(recursive: true);
  }
  final file = io.File('${directory.path}/validate-runtime.json');
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(result.toEnvelopeJson()),
  );
}

void _printInteractiveNarrativeIfNeeded({
  required final ArgResults topLevel,
  required final CoreResult result,
}) {
  if (!io.stdout.hasTerminal) {
    return;
  }

  switch (topLevel.name) {
    case 'doctor':
      io.stdout.writeln(
        'doctor: visual-capture checks run in read-only mode; capture commands can auto-request once when needed.',
      );
      return;
    case 'validate-runtime':
      io.stdout.writeln(
        'validate-runtime: visual capture tries auto mode first; executor '
        'recovery retries host capture once (desktopCaptureRetried). When '
        'platform views are detected, flutter_layer fallback is skipped.',
      );
      return;
    case 'permissions':
      final data = _asObject(result.data);
      final status = '${data['status'] ?? 'unknown'}';
      final backend = '${data['backend'] ?? 'unknown'}';
      io.stdout.writeln('permissions: $backend reports $status.');
      return;
    case 'exec':
      final name = topLevel.option('name');
      if (name == 'get_screenshots' || name == 'capture_ui_snapshot') {
        final data = _asObject(result.data);
        final permission = _asObject(data['permission']);
        final status =
            '${permission['status'] ?? data['permissionStatus'] ?? 'unknown'}';
        final actual =
            '${data['actualMode'] ?? data['captureMode'] ?? 'unknown'}';
        io.stdout.writeln(
          'capture: permission status $status, actual mode $actual.',
        );
      }
      return;
  }
}

Map<String, Object?> _asObject(final Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, Object?>();
  }
  return const <String, Object?>{};
}

Map<String, Object?>? _stepData(
  final List<Map<String, Object?>> steps,
  final String name,
) {
  for (final step in steps) {
    if ('${step['name']}' != name) {
      continue;
    }
    final data = step['data'];
    if (data is Map<String, Object?>) {
      return data;
    }
    if (data is Map) {
      return data.cast<String, Object?>();
    }
  }
  return null;
}

Map<String, Object?> _screenshotEnvelope(final Map<String, Object?>? stepData) {
  if (stepData == null) {
    return const <String, Object?>{};
  }
  return _asObject(stepData['screenshots']);
}

String? _captureBackend(final Map<String, Object?>? stepData) {
  final screenshots = _screenshotEnvelope(stepData);
  final permission = _asObject(screenshots['permission']);
  return _nonEmptyOption(
    '${permission['backend'] ?? screenshots['backend'] ?? stepData?['backend'] ?? ''}',
  );
}

String? _captureMode(final Map<String, Object?>? stepData) {
  final screenshots = _screenshotEnvelope(stepData);
  return _nonEmptyOption(
        '${stepData?['summary'] is Map ? (_asObject(stepData?['summary'])['actualMode'] ?? '') : ''}',
      ) ??
      _nonEmptyOption(
        '${screenshots['actualMode'] ?? screenshots['captureMode'] ?? stepData?['actualMode'] ?? ''}',
      );
}

List<String> _screenshotFiles(final List<Map<String, Object?>> steps) {
  final files = <String>[];
  for (final step in steps) {
    final stepData = _stepData(steps, '${step['name']}');
    final screenshots = _screenshotEnvelope(stepData);
    final fileUrls = screenshots['fileUrls'];
    if (fileUrls is! List) {
      continue;
    }
    for (final value in fileUrls) {
      final stringValue = _nonEmptyOption('$value');
      if (stringValue != null) {
        files.add(stringValue);
      }
    }
  }
  return files;
}

/// Resolves the VM websocket URI for [doctor] and [validate-runtime].
///
/// Subcommand `--target` wins over global `--vm-service-uri` when both differ.
String? _resolveVmTargetUri({
  required final ArgResults command,
  required final ArgResults parsed,
}) {
  final fromCommand = _nonEmptyOption(command.option('target'));
  final fromGlobal = _nonEmptyOption(parsed.option(_vmServiceUri));
  if (fromCommand != null && fromGlobal != null && fromCommand != fromGlobal) {
    io.stderr.writeln(
      '[WARN] flutter-mcp-toolkit: --target and --vm-service-uri differ; '
      'using --target.',
    );
    return fromCommand;
  }
  return fromCommand ?? fromGlobal;
}

bool _captureHintsPlatformViewsDetected(
  final List<Map<String, Object?>> steps,
) {
  for (final step in steps) {
    if (step['ok'] != true) {
      continue;
    }
    final data = step['data'];
    if (data is! Map) {
      continue;
    }
    final screenshots = data['screenshots'];
    if (screenshots is Map) {
      final hints = screenshots['captureHints'];
      if (hints is Map && hints['platformViewsDetected'] == true) {
        return true;
      }
    }
    final hints = data['captureHints'];
    if (hints is Map && hints['platformViewsDetected'] == true) {
      return true;
    }
  }
  return false;
}

bool _desktopCaptureRetriedInSteps(final List<Map<String, Object?>> steps) {
  for (final step in steps) {
    final name = '${step['name']}';
    if (!name.contains('capture_ui_snapshot') || step['ok'] != true) {
      continue;
    }
    final data = step['data'];
    if (data is! Map) {
      continue;
    }
    final map = data is Map<String, Object?>
        ? data
        : data.cast<String, Object?>();
    final screenshots = map['screenshots'];
    if (screenshots is Map) {
      final shotMap = screenshots is Map<String, Object?>
          ? screenshots
          : screenshots.cast<String, Object?>();
      if (shotMap['desktopCaptureRetried'] == true) {
        return true;
      }
    }
    if (map['desktopCaptureRetried'] == true) {
      return true;
    }
  }
  return false;
}

PlatformViewHints _platformViewHintsFromDetected(final bool detected) =>
    PlatformViewHints(
      platformViewsDetected: detected,
      matches: const <PlatformViewMatch>[],
      recommendedMode: detected ? kCaptureHintRecommendedDesktopWindow : null,
      warning: detected ? kPlatformViewWarning : null,
    );

bool _platformViewsDetectedInPayload(final Map<String, Object?>? payload) {
  if (payload == null) {
    return false;
  }
  final hints = payload['captureHints'];
  if (hints is Map && hints['platformViewsDetected'] == true) {
    return true;
  }
  final tree = payload['widgetTree'];
  if (tree is Map) {
    return detectPlatformViews(tree).platformViewsDetected;
  }
  return false;
}

bool _eligibleForFlutterLayerCaptureRetry(final CoreResult result) {
  if (result.ok) {
    return false;
  }
  if (result.error?.code != CoreErrorCode.getScreenshotsFailed) {
    return false;
  }
  if (result.error?.resolvedDescriptor.retryable != true) {
    return false;
  }
  final message = (result.error?.message ?? '').toLowerCase();
  if (message.contains('desktop window') ||
      message.contains('desktop_window') ||
      message.contains('screencapturekit')) {
    return true;
  }
  final details = result.error?.details;
  if (details is! Map) {
    return false;
  }
  final permission = _asObject(_asObject(details)['permission']);
  final actual = '${permission['actualMode'] ?? ''}'.toLowerCase();
  final requested = '${permission['requestedMode'] ?? ''}'.toLowerCase();
  return actual == 'desktop_window' || requested == 'desktop_window';
}

Map<String, Object?>? _stepPayloadIfOk(
  final List<Map<String, Object?>> steps,
  final String name,
) {
  for (final step in steps) {
    if ('${step['name']}' != name || step['ok'] != true) {
      continue;
    }
    final data = step['data'];
    if (data is Map<String, Object?>) {
      return data;
    }
    if (data is Map) {
      return data.cast<String, Object?>();
    }
  }
  return null;
}

Map<String, Object?>? _effectiveValidateRuntimeCaptureData(
  final List<Map<String, Object?>> steps, {
  required final String primary,
  required final String flutterLayerFallback,
}) =>
    _stepPayloadIfOk(steps, flutterLayerFallback) ??
    _stepPayloadIfOk(steps, primary);

bool _validateRuntimeUsedFlutterLayerFallback(
  final List<Map<String, Object?>> steps,
) {
  for (final step in steps) {
    final name = '${step['name']}';
    if (!name.contains('flutter_layer')) {
      continue;
    }
    if (step['ok'] == true) {
      return true;
    }
  }
  return false;
}

bool _shouldRetryPostReloadCapture(final CoreResult result) {
  final code = result.error?.code;
  if (code == CoreErrorCode.connectFailed ||
      code == CoreErrorCode.vmNotConnected) {
    return true;
  }
  if (code != CoreErrorCode.getScreenshotsFailed) {
    return false;
  }
  final message =
      '${result.error?.message ?? ''} ${result.error?.details ?? ''}'
          .toLowerCase();
  return message.contains('screencapturekit') ||
      message.contains('desktop_window') ||
      message.contains('permission') ||
      message.contains('timeout') ||
      message.contains('window');
}

String _captureFailureKind(final CoreResult result) {
  final code = result.error?.code;
  final message =
      '${result.error?.message ?? ''} ${result.error?.details ?? ''}'
          .toLowerCase();
  if (message.contains('permission')) {
    return 'permission_denied';
  }
  if (code == CoreErrorCode.connectFailed ||
      code == CoreErrorCode.vmNotConnected) {
    return 'bad_target_uri_or_unreachable_vm_service';
  }
  if (code == CoreErrorCode.getScreenshotsFailed &&
      (message.contains('screencapturekit') ||
          message.contains('desktop_window') ||
          message.contains('window'))) {
    return 'host_capture_backend_instability';
  }
  return 'unknown_capture_failure';
}

String _globalUsage() {
  final buffer = StringBuffer()
    ..writeln('$kFlutterMcpCliName v$kFlutterMcpVersion')
    ..writeln()
    ..writeln('Usage:')
    ..writeln(
      '  flutter-mcp-toolkit [global options] <command> [command options]',
    )
    ..writeln()
    ..writeln('Commands:')
    ..writeln('  exec')
    ..writeln('  batch')
    ..writeln('  schema')
    ..writeln('  capabilities')
    ..writeln('  serve')
    ..writeln('  snapshot create')
    ..writeln('  snapshot diff')
    ..writeln('  bundle create')
    ..writeln('  doctor')
    ..writeln('  permissions status|request|open-settings')
    ..writeln('  validate-runtime')
    ..writeln('  init')
    ..writeln('  codegen-init')
    ..writeln('  migrate agent-entries')
    ..writeln('  migrate mcp-call-entry')
    ..writeln('  codegen sync')
    ..writeln()
    ..writeln('Global options:')
    ..writeln(_argParser.usage)
    ..writeln()
    ..writeln(
      'Use `flutter-mcp-toolkit <command> --help` for contextual examples.',
    );
  return buffer.toString();
}

String _usageForCommand(final List<String> commandPath) {
  final key = commandPath.join(' ');
  return switch (key) {
    'exec' => _usageExec(),
    'batch' => _usageBatch(),
    'schema' => _usageSchema(),
    'capabilities' => _usageCapabilities(),
    'serve' => _usageServe(),
    'snapshot' => _usageSnapshot(),
    'snapshot create' => _usageSnapshotCreate(),
    'snapshot diff' => _usageSnapshotDiff(),
    'bundle' => _usageBundle(),
    'bundle create' => _usageBundleCreate(),
    'doctor' => _usageDoctor(),
    'permissions' => _usagePermissions(),
    'permissions status' => _usagePermissions(),
    'permissions request' => _usagePermissions(),
    'permissions open-settings' => _usagePermissions(),
    'validate-runtime' => _usageValidateRuntime(),
    'init' => _usageInit(),
    'codegen-init' => _usageCodegenInit(),
    'migrate' => _usageMigrate(),
    'migrate agent-entries' => _usageMigrateAgentEntries(),
    'migrate mcp-call-entry' => _usageMigrateAgentEntries(),
    'codegen' => _usageCodegen(),
    'codegen sync' => _usageCodegenSync(),
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
        'Also used as validate-runtime / doctor --target when '
        '--target is omitted. '
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
    _webBrowserDebuggingPort,
    help:
        'Chrome remote-debugging-port override for web CDP capture when '
        'auto-discovery fails (flutter run -d chrome).',
  )
  ..addOption(
    _webPort,
    help: 'Flutter --web-port hint for selecting the matching CDP page target.',
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
  ..addFlag(_dumpsSupported, help: 'Enable dump commands')
  ..addFlag(
    _saveImagesToFiles,
    help: 'Save screenshots to files and return file URLs',
  )
  ..addOption(
    _outputDir,
    help:
        'Deterministic output root for CLI artifacts. Screenshot files are written to '
        '<output-dir>/.mcp_screenshots and validate-runtime mirrors its JSON summary here.',
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
      )
      ..addFlag(
        'pretty',
        help:
            'Pretty-print the response envelope with 2-space indentation '
            'instead of single-line JSON. Intended for humans reading the '
            'output; agents should keep the default compact form.',
      ),
  )
  ..addCommand(
    'batch',
    _commandParser()
      ..addOption(
        'steps',
        help:
            'Batch steps as JSON array. '
            'Each step must contain {"name":"<command>"} and may include '
            '{"args":{...}}.',
      )
      ..addFlag(
        'continue-on-error',
        help: 'Continue running remaining steps after a step fails.',
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
          ..addFlag(_check, help: 'Evaluate changes without writing files')
          ..addFlag(
            _diff,
            help: 'Attach unified diff metadata per changed target',
          )
          ..addFlag(
            _backup,
            help: 'Create timestamped backups before replacing targets',
          )
          ..addFlag(
            _noOverwrite,
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
        ..addFlag(_check, help: 'Evaluate changes without writing files')
        ..addFlag(
          _diff,
          help: 'Attach unified diff metadata per changed target',
        )
        ..addFlag(
          _backup,
          help: 'Create timestamped backups before replacing targets',
        )
        ..addFlag(
          _noOverwrite,
          help: 'Block writes when target already exists',
        ),
    ),
  )
  ..addCommand(
    'doctor',
    _commandParser()
      ..addFlag('json', help: 'Emit machine-readable JSON')
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
    'permissions',
    _commandParser()
      ..addCommand(
        'status',
        _commandParser()..addOption(
          'kind',
          defaultsTo: PermissionKind.visualCapture.wireName,
          help: 'Permission kind to inspect.',
        ),
      )
      ..addCommand(
        'request',
        _commandParser()..addOption(
          'kind',
          defaultsTo: PermissionKind.visualCapture.wireName,
          help: 'Permission kind to request.',
        ),
      )
      ..addCommand(
        'open-settings',
        _commandParser()..addOption(
          'kind',
          defaultsTo: PermissionKind.visualCapture.wireName,
          help: 'Permission kind to open in settings.',
        ),
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
      ..addOption(
        'post-reload-delay-ms',
        defaultsTo: '$_defaultValidateRuntimePostReloadDelayMs',
        help:
            'Optional settle delay before the post-reload visual capture step.',
      )
      ..addFlag(
        'after-reload',
        help:
            'Also run hot_reload_flutter and capture one more screenshot after reload.',
      )
      ..addFlag(
        'install-skill',
        help:
            'Install bundled Codex runtime-validation skill before running checks.',
      )
      ..addOption(
        'skill-destination',
        help:
            'Optional destination root for skill install '
            r'(defaults to $CODEX_HOME/skills).',
      )
      ..addFlag(
        'force-skill-install',
        help: 'Replace existing skill directory when using --install-skill.',
      ),
  )
  ..addCommand(
    'init',
    _commandParser()
      ..addOption(
        'mode',
        allowed: ['mcp', 'cli', 'auto'],
        defaultsTo: 'auto',
        help:
            'Skill rendering mode (mcp uses MCP tool calls, cli uses '
            'flutter-mcp-toolkit exec). auto detects from environment.',
      )
      ..addOption(
        'scope',
        allowed: ['project', 'user'],
        defaultsTo: 'project',
        help: r'Install scope: project (./) or user ($HOME).',
      ),
  )
  ..addCommand(
    'codegen-init',
    _commandParser()
      ..addFlag(
        'print-only',
        defaultsTo: true,
        help: 'Print snippet to stdout, do not edit main.dart.',
      )
      ..addFlag(
        'pub-add',
        defaultsTo: true,
        help: 'Run "flutter pub add flutter_mcp_toolkit" first.',
      ),
  )
  ..addCommand(
    'migrate',
    _commandParser()
      ..addCommand(
        'agent-entries',
        _migrateAgentEntriesParser(),
      )
      ..addCommand(
        'mcp-call-entry',
        _migrateAgentEntriesParser(),
      ),
  )
  ..addCommand(
    'codegen',
    _commandParser()
      ..addCommand(
        'sync',
        _commandParser()
          ..addOption(
            'platform',
            defaultsTo: 'web',
            help: 'Comma-separated platforms (phase 6d-web: web only)',
          )
          ..addOption(
            'project-dir',
            help: 'Flutter project root (defaults to current directory)',
          )
          ..addFlag(
            _check,
            help: 'Verify generated web artifacts are up to date',
          ),
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
const _defaultValidateRuntimePostReloadDelayMs = 0;
const _runtimeValidationSkillName = 'flutter-mcp-cli-runtime-validation';

final class _BatchStep {
  const _BatchStep({required this.name, required this.args});

  final String name;
  final Map<String, Object?> args;
}

const _dartVmHost = 'dart-vm-host';
const _dartVmPort = 'dart-vm-port';
const _vmServiceUri = 'vm-service-uri';
const _flutterProjectDir = 'flutter-project-dir';
const _flutterDevice = 'flutter-device';
const _flutterDiscoveryTimeoutMs = 'flutter-discovery-timeout-ms';
const _webBrowserDebuggingPort = 'web-browser-debugging-port';
const _webPort = 'web-port';
const _stateFile = 'state-file';
const _resourcesSupported = 'resources';
const _imagesSupported = 'images';
const _dumpsSupported = 'dumps';
const _dynamicRegistrySupported = 'dynamics';
const _saveImagesToFiles = 'save-images';
const _outputDir = 'output-dir';
const _logLevel = 'log-level';
const _help = 'help';
const _check = 'check';
const _write = 'write';
const _diff = 'diff';
const _backup = 'backup';
const _noOverwrite = 'no-overwrite';

String _usageExec() => '''
Usage: flutter-mcp-toolkit exec --name <command> [--args <json>] [--pretty]

Examples:
  flutter-mcp-toolkit exec --name status --args '{}'
  flutter-mcp-toolkit exec --name status --args '{}' --pretty
  flutter-mcp-toolkit exec --name get_vm --args '{"connection":{"uri":"ws://127.0.0.1:8181/<token>/ws"}}'
  flutter-mcp-toolkit exec --name get_extension_rpcs --args '{}'
  flutter-mcp-toolkit exec --name get_screenshots --args '{}'
  flutter-mcp-toolkit exec --name get_view_details --args '{}'

Notes:
  --pretty prints the response envelope with 2-space indentation.
  Agents should keep the default compact form.

CLI-first runtime validation sequence:
  1) get_extension_rpcs -> confirm ext.mcp.toolkit.app_errors/view_details/view_screenshots/inspect_widget_at_point
  2) capture_ui_snapshot + get_view_details -> visual/layout baseline
  3) get_app_errors -> runtime error context

If connection_selection_required appears:
  retry with args.connection.targetId or args.connection.uri (exact app.debugPort.wsUri).
''';

String _usageBatch() => '''
Usage: flutter-mcp-toolkit batch --steps <json> [--continue-on-error]

Examples:
  flutter-mcp-toolkit batch --steps '[{"name":"status"},{"name":"status"}]'
  flutter-mcp-toolkit batch --steps '[{"name":"discover_debug_apps"},{"name":"capture_ui_snapshot","args":{"compress":true}}]'
  flutter-mcp-toolkit batch --continue-on-error --steps '[{"name":"status"},{"name":"unknown_command"}]'

Each step reuses the same command catalog and preconnect flow as `exec`.
Use this when you want one CLI startup and one target selection path for a
small deterministic command sequence.
''';

String _usageSchema() => '''
Usage: flutter-mcp-toolkit schema [--name <command>]

Examples:
  flutter-mcp-toolkit schema
  flutter-mcp-toolkit schema --name get_vm
''';

String _usageCapabilities() => '''
Usage: flutter-mcp-toolkit capabilities

Examples:
  flutter-mcp-toolkit capabilities
''';

String _usageServe() => '''
Usage: flutter-mcp-toolkit serve

Examples:
  flutter-mcp-toolkit serve
''';

String _usageSnapshot() => '''
Usage:
  flutter-mcp-toolkit snapshot create ...
  flutter-mcp-toolkit snapshot diff ...

Examples:
  flutter-mcp-toolkit snapshot create --name baseline --args '{"commands":[{"name":"status","args":{}}]}'
  flutter-mcp-toolkit snapshot diff --from baseline --to current
''';

String _usageSnapshotCreate() => '''
Usage: flutter-mcp-toolkit snapshot create --name <id> [--args <json>] [--check] [--diff] [--backup] [--no-overwrite]

Examples:
  flutter-mcp-toolkit snapshot create --name baseline --args '{"commands":[{"name":"status","args":{}}]}'
  flutter-mcp-toolkit snapshot create --name baseline --check --diff
''';

String _usageSnapshotDiff() => '''
Usage: flutter-mcp-toolkit snapshot diff --from <id> --to <id>

Examples:
  flutter-mcp-toolkit snapshot diff --from baseline --to after_fix
''';

String _usageBundle() => '''
Usage:
  flutter-mcp-toolkit bundle create ...

Examples:
  flutter-mcp-toolkit bundle create --from-snapshot baseline --output .flutter_mcp/bundles/baseline
''';

String _usageBundleCreate() => '''
Usage: flutter-mcp-toolkit bundle create --from-snapshot <id> [--output <dir>] [--check] [--diff] [--backup] [--no-overwrite]

Examples:
  flutter-mcp-toolkit bundle create --from-snapshot baseline --output ./bundle_out
  flutter-mcp-toolkit bundle create --from-snapshot baseline --check --diff
''';

String _usageDoctor() => '''
Usage: flutter-mcp-toolkit doctor [--json] [--target <ws_uri>] [--timeout-ms <n>]

Examples:
  flutter-mcp-toolkit doctor
  flutter-mcp-toolkit doctor --json --target ws://127.0.0.1:8181/<token>/ws --timeout-ms 4000

Doctor checks include:
  - VM reachability
  - required mcp_toolkit extensions for app inspection
  - dynamic registry availability

If mcp_toolkit_extensions fails, screenshot/layout/error inspection is not reliable
until app instrumentation is fixed and app is hot restarted or rerun.
''';

String _usagePermissions() => '''
Usage:
  flutter-mcp-toolkit permissions status [--kind visual_capture]
  flutter-mcp-toolkit permissions request [--kind visual_capture]
  flutter-mcp-toolkit permissions open-settings [--kind visual_capture]

Examples:
  flutter-mcp-toolkit permissions status
  flutter-mcp-toolkit permissions request
  flutter-mcp-toolkit permissions open-settings
''';

String _usageValidateRuntime() =>
    '''
Usage: flutter-mcp-toolkit validate-runtime [--target <ws_uri>] [--timeout-ms <n>] [--errors-count <n>] [--connect-retries <n>] [--post-reload-delay-ms <n>] [--after-reload] [--install-skill] [--skill-destination <dir>] [--force-skill-install]

Two-step agent flow:
  1) Start Flutter app in debug mode
  2) Run this command

Examples:
  flutter-mcp-toolkit validate-runtime --target ws://127.0.0.1:8181/<token>/ws --timeout-ms 10000
  flutter-mcp-toolkit --vm-service-uri ws://127.0.0.1:8181/<token>/ws validate-runtime --timeout-ms 10000
  flutter-mcp-toolkit --save-images --output-dir .mcp_outputs/arena_macos validate-runtime --target ws://127.0.0.1:8181/<token>/ws --after-reload
  flutter-mcp-toolkit validate-runtime --target ws://127.0.0.1:8181/<token>/ws --install-skill

  What it does:
  - doctor preflight (including mcp_toolkit extension gate)
  - get_extension_rpcs
  - capture_ui_snapshot (auto mode; retries once with flutter_layer if host desktop_window capture fails)
  - get_view_details
  - get_app_errors
  - optional hot_reload + delayed capture_ui_snapshot (same fallback)

If toolkit extensions are missing, add `mcp_toolkit` to app dependencies and
initialize `MCPToolkitBinding.instance..initialize()..initializeFlutterToolkit();`
before `runApp`, then hot restart or rerun.

For truthful `desktop_window` capture from the bare CLI, also pass global
`--flutter-project-dir <app_dir>` and `--flutter-device <device>` so host
window capture can resolve the running Flutter app.

Transient first-connect failures are retried automatically for connect/vm_not_connected errors.
macOS desktop-window post-reload capture retries known host-capture races before failing.
Optional skill installation copies mcp_server_dart/skills/$_runtimeValidationSkillName to \$CODEX_HOME/skills.
''';

String _usageInit() => '''
Usage: flutter-mcp-toolkit init <claude-code|cursor|codex|cline|agents-skills|all> [--mode mcp|cli|auto] [--scope project|user]

Examples:
  flutter-mcp-toolkit init claude-code
  flutter-mcp-toolkit init claude-code --mode cli
  flutter-mcp-toolkit init all --mode mcp --scope user

Installs flutter-mcp-toolkit skills and MCP server config for an AI agent.
''';

String _usageCodegenInit() => '''
Usage: flutter-mcp-toolkit codegen-init [--no-print-only] [--no-pub-add]

Examples:
  flutter-mcp-toolkit codegen-init
  flutter-mcp-toolkit codegen-init --no-pub-add

Adds flutter_mcp_toolkit to a Flutter app and emits boilerplate for main.dart.
''';

Future<int> _runInitSubcommand(final ArgResults command) async {
  if (command.rest.isEmpty) {
    io.stderr.writeln(
      'Usage: flutter-mcp-toolkit init <claude-code|cursor|codex|cline|agents-skills|all>',
    );
    return 64;
  }
  final InitTarget target;
  try {
    target = InitTarget.parse(command.rest.first);
    // ignore: avoid_catching_errors
  } on ArgumentError catch (e) {
    io.stderr.writeln(e.message);
    return 64;
  }
  final mode = InitMode.parse(command.option('mode'));
  final scope = command.option('scope') ?? 'project';
  final outputRoot = scope == 'user'
      ? (io.Platform.environment['HOME'] ?? io.Directory.current.path)
      : io.Directory.current.path;
  try {
    return await runInit(
      target: target,
      modeOverride: mode,
      outputRoot: outputRoot,
      scopeIsUserHome: scope == 'user',
    );
    // ignore: avoid_catching_errors
  } on StateError catch (e) {
    io.stderr.writeln(e.message);
    io.stderr.writeln(
      'Hint: pass --mode mcp or --mode cli to skip auto-detection. '
      "If you've already run install.sh, restart your shell or "
      r'`source ~/.zshrc` so $PATH picks up the binary.',
    );
    return 64;
  }
}

Future<int> _runCodegenInitSubcommand(final ArgResults command) =>
    runCodegenInit(
      projectRoot: io.Directory.current.path,
      printSnippetOnly: command.flag('print-only'),
      runPubAdd: command.flag('pub-add'),
    );

Future<int> _runCodegenSubcommand(final ArgResults command) async {
  final sub = command.command;
  if (sub == null || sub.name != 'sync') {
    io.stderr.writeln('Usage: flutter-mcp-toolkit codegen sync --platform web');
    return 64;
  }
  return runCodegenSync(
    platform: sub.option('platform') ?? 'web',
    projectRoot: sub.option('project-dir') ?? io.Directory.current.path,
    checkOnly: sub.flag(_check),
  );
}

String _usageCodegen() => '''
Usage:
  flutter-mcp-toolkit codegen sync ...

Examples:
  flutter-mcp-toolkit codegen sync --platform web
  flutter-mcp-toolkit codegen sync --platform web --check
''';

String _usageCodegenSync() => '''
Usage: flutter-mcp-toolkit codegen sync --platform web [--project-dir <path>] [--check]

Examples:
  flutter-mcp-toolkit codegen sync --platform web
  flutter-mcp-toolkit codegen sync --platform web --check

Reads agent_manifest.json and writes web/manifest.json shortcuts +
web/agentkit_webmcp.generated.js for WebMCP bootstrap path C.
''';

ArgParser _migrateAgentEntriesParser() => _commandParser()
  ..addFlag(_check, help: 'Report pending migrations; exit 1 if any would change')
  ..addFlag(_write, help: 'Apply migrations in place')
  ..addOption(
    'namespace',
    defaultsTo: 'app',
    help: 'Default AgentCallEntry namespace for migrated entries',
  );

String _usageMigrate() => '''
Usage: flutter-mcp-toolkit migrate <agent-entries|mcp-call-entry> [options] <path>

Subcommands:
  agent-entries   Migrate MCPCallEntry → AgentCallEntry in Dart sources
  mcp-call-entry  Alias for agent-entries

Use `flutter-mcp-toolkit migrate agent-entries --help` for options.
''';

String _usageMigrateAgentEntries() => '''
Usage: flutter-mcp-toolkit migrate agent-entries [--check] [--write] [--namespace app] <path>

Examples:
  flutter-mcp-toolkit migrate agent-entries --check lib/
  flutter-mcp-toolkit migrate agent-entries --write lib/main.dart
  flutter-mcp-toolkit migrate mcp-call-entry --write --namespace my_app lib/

Migrates MCPCallEntry tool/resource factories to AgentCallEntry ahead of Phase 6b hard cut.
See docs/start_here/migration_agentkit_phase6.md for limitations.
''';

Future<int> _runMigrateSubcommand(final ArgResults command) async {
  final sub = command.command;
  if (sub == null ||
      (sub.name != 'agent-entries' && sub.name != 'mcp-call-entry')) {
    io.stderr.writeln(
      'Usage: flutter-mcp-toolkit migrate <agent-entries|mcp-call-entry> [options] <path>',
    );
    return 64;
  }
  if (sub.rest.isEmpty) {
    io.stderr.writeln(
      'Usage: flutter-mcp-toolkit migrate ${sub.name} [--check] [--write] <path>',
    );
    return 64;
  }
  return runMigrateAgentEntries(
    path: sub.rest.first,
    checkOnly: sub.flag(_check),
    write: sub.flag(_write),
    defaultNamespace: sub.option('namespace') ?? 'app',
  );
}
