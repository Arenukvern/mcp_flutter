// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:async';
import 'dart:io' as io;

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/core/commands.dart';
import 'package:flutter_inspector_mcp_server/src/core/connection_context.dart';
import 'package:flutter_inspector_mcp_server/src/core/core_types.dart';
import 'package:flutter_inspector_mcp_server/src/core/error_codes.dart';
import 'package:flutter_inspector_mcp_server/src/core/executor.dart';
import 'package:flutter_inspector_mcp_server/src/core/dynamic_gateway.dart';
import 'package:flutter_inspector_mcp_server/src/core/visual_capture.dart';
import 'package:flutter_inspector_mcp_server/src/mixins/mcp_toolkit_consts.dart';

enum DoctorCheckStatus { pass, warn, fail }

final class DoctorRunner {
  DoctorRunner({
    required this.connectionContext,
    required this.executor,
    required this.stateFilePath,
    required this.dynamicRegistrySupported,
    required this.logger,
  });

  final ConnectionContext connectionContext;
  final DefaultCoreCommandExecutor executor;
  final String stateFilePath;
  final bool dynamicRegistrySupported;
  final CoreLogger logger;

  Future<Map<String, Object?>> run({
    final String? target,
    final Duration timeout = const Duration(milliseconds: 2500),
  }) async {
    final checks = <Map<String, Object?>>[];
    final visualCaptureBroker = VisualCaptureBroker(
      configuration: executor.configuration,
      dynamicGateway: dynamicRegistrySupported
          ? VmExtensionDynamicGateway(connectionContext: connectionContext)
          : null,
      adapters: executor.visualCaptureAdapters,
    );

    try {
      checks.add(await _checkDartSdk(timeout: timeout));
      checks.add(await _checkFlutterSdk(timeout: timeout));
      checks.add(await _checkStatePathWritable());
      checks.add(
        await _checkVmTargetReachable(
          target: target,
          timeout: timeout,
          disconnectAfterCheck: false,
        ),
      );
      checks.add(await _checkVisualCaptureBackend(broker: visualCaptureBroker));
      checks.add(
        await _checkVisualCapturePermission(broker: visualCaptureBroker),
      );
      checks.add(
        await _checkVisualCaptureTruthMode(broker: visualCaptureBroker),
      );
      checks.add(await _checkAppPermissionBridge(broker: visualCaptureBroker));
      checks.add(await _checkToolkitExtensions(timeout: timeout));
      checks.add(await _checkDynamicRegistryAvailable(timeout: timeout));

      final passCount = checks.where((final c) => c['status'] == 'pass').length;
      final warnCount = checks.where((final c) => c['status'] == 'warn').length;
      final failCount = checks.where((final c) => c['status'] == 'fail').length;
      final criticalFailures = checks.where((final c) {
        return c['critical'] == true && c['status'] == 'fail';
      }).length;

      return {
        'checks': checks,
        'summary': {
          'total': checks.length,
          'pass': passCount,
          'warn': warnCount,
          'fail': failCount,
          'criticalFailures': criticalFailures,
        },
        'target': target,
        'checkedAt': DateTime.now().toUtc().toIso8601String(),
      };
    } finally {
      await connectionContext.disconnect();
    }
  }

  Future<Map<String, Object?>> _checkDartSdk({
    required final Duration timeout,
  }) async {
    try {
      final result = await io.Process.run('dart', const <String>[
        '--version',
      ]).timeout(timeout);
      if (result.exitCode != 0) {
        return _check(
          id: 'dart_sdk',
          status: DoctorCheckStatus.fail,
          critical: false,
          diagnostic: 'dart --version exited with ${result.exitCode}',
          fixCommand:
              'Install Dart SDK 3.10+ and ensure `dart` is available on PATH.',
        );
      }

      final line = _firstNonEmptyLine(
        '${result.stdout}\n${result.stderr}',
      ).trim();
      return _check(
        id: 'dart_sdk',
        status: DoctorCheckStatus.pass,
        critical: false,
        diagnostic: line.isEmpty ? 'Dart SDK detected.' : line,
        fixCommand:
            'If this fails in CI, install Dart SDK and verify PATH wiring.',
      );
    } on TimeoutException {
      return _check(
        id: 'dart_sdk',
        status: DoctorCheckStatus.warn,
        critical: false,
        diagnostic:
            'dart --version timed out after ${timeout.inMilliseconds}ms',
        fixCommand:
            'Retry with --timeout-ms <n> or verify local Dart SDK installation.',
      );
    } on Exception catch (error) {
      return _check(
        id: 'dart_sdk',
        status: DoctorCheckStatus.warn,
        critical: false,
        diagnostic: 'Failed to execute dart --version: $error',
        fixCommand:
            'Install Dart SDK 3.10+ and ensure `dart` is available on PATH.',
      );
    }
  }

  Future<Map<String, Object?>> _checkFlutterSdk({
    required final Duration timeout,
  }) async {
    try {
      final result = await io.Process.run('flutter', const <String>[
        '--version',
      ]).timeout(timeout);
      if (result.exitCode != 0) {
        return _check(
          id: 'flutter_sdk',
          status: DoctorCheckStatus.warn,
          critical: false,
          diagnostic: 'flutter --version exited with ${result.exitCode}',
          fixCommand:
              'Install Flutter SDK and ensure `flutter` is available on PATH.',
        );
      }

      final line = _firstNonEmptyLine(
        '${result.stdout}\n${result.stderr}',
      ).trim();
      return _check(
        id: 'flutter_sdk',
        status: DoctorCheckStatus.pass,
        critical: false,
        diagnostic: line.isEmpty ? 'Flutter SDK detected.' : line,
        fixCommand:
            'Run `flutter doctor` and fix local SDK issues if reported.',
      );
    } on TimeoutException {
      return _check(
        id: 'flutter_sdk',
        status: DoctorCheckStatus.warn,
        critical: false,
        diagnostic:
            'flutter --version timed out after ${timeout.inMilliseconds}ms',
        fixCommand:
            'Retry with --timeout-ms <n> or ensure Flutter SDK is installed.',
      );
    } on Exception catch (error) {
      return _check(
        id: 'flutter_sdk',
        status: DoctorCheckStatus.warn,
        critical: false,
        diagnostic: 'Failed to execute flutter --version: $error',
        fixCommand:
            'Install Flutter SDK and ensure `flutter` is available on PATH.',
      );
    }
  }

  Future<Map<String, Object?>> _checkStatePathWritable() async {
    final stateFile = io.File(stateFilePath);
    final parentDir = stateFile.parent;
    final probeName =
        '.doctor_state_write_probe_${DateTime.now().microsecondsSinceEpoch}';
    final probeFile = io.File('${parentDir.path}/$probeName');

    try {
      parentDir.createSync(recursive: true);
      probeFile.writeAsStringSync('probe');
      probeFile.deleteSync();
      return _check(
        id: 'state_path_writable',
        status: DoctorCheckStatus.pass,
        critical: true,
        diagnostic: 'State directory is writable: ${parentDir.path}',
        fixCommand: 'Ensure write access to ${parentDir.path}.',
      );
    } on Exception catch (error) {
      try {
        if (probeFile.existsSync()) {
          probeFile.deleteSync();
        }
      } on Exception {
        // Best effort cleanup.
      }
      return _check(
        id: 'state_path_writable',
        status: DoctorCheckStatus.fail,
        critical: true,
        diagnostic: 'Cannot write to state directory ${parentDir.path}: $error',
        fixCommand: 'Create and grant write access to ${parentDir.path}.',
      );
    }
  }

  Future<Map<String, Object?>> _checkVmTargetReachable({
    required final String? target,
    required final Duration timeout,
    final bool disconnectAfterCheck = true,
  }) async {
    try {
      final normalizedTarget = target?.trim();
      if (normalizedTarget != null &&
          normalizedTarget.isNotEmpty &&
          CoreConnectionTarget.isLegacyHostPortTargetId(normalizedTarget)) {
        return _check(
          id: 'vm_target_reachable',
          status: DoctorCheckStatus.fail,
          critical: true,
          diagnostic:
              'Legacy host:port targetId is not supported: $normalizedTarget',
          fixCommand:
              'Use full websocket URI target (ws://host:port/<token>/ws).',
        );
      }

      String selectedTarget = '';
      if (normalizedTarget != null && normalizedTarget.isNotEmpty) {
        selectedTarget = normalizedTarget;
      } else {
        final targets = await connectionContext.discoverTargets();
        if (targets.isEmpty) {
          return _check(
            id: 'vm_target_reachable',
            status: DoctorCheckStatus.fail,
            critical: true,
            diagnostic: 'No Flutter debug targets discovered.',
            fixCommand:
                'Start a Flutter app in debug mode and retry `flutter_mcp_cli doctor`.',
          );
        }
        selectedTarget = targets.first.targetId;
      }

      await connectionContext
          .connect(
            mode: CoreConnectionMode.auto,
            targetId: selectedTarget,
            timeout: timeout,
          )
          .timeout(timeout);
      final endpoint =
          connectionContext.activeEndpoint?.display ?? selectedTarget;
      return _check(
        id: 'vm_target_reachable',
        status: DoctorCheckStatus.pass,
        critical: true,
        diagnostic: 'Connected to VM target: $endpoint',
        fixCommand:
            'If this check regresses, retry with --target <ws_uri> and --timeout-ms <n>.',
      );
    } on TimeoutException {
      return _check(
        id: 'vm_target_reachable',
        status: DoctorCheckStatus.fail,
        critical: true,
        diagnostic:
            'VM reachability check timed out after ${timeout.inMilliseconds}ms',
        fixCommand:
            'Increase --timeout-ms and verify the debug app is running.',
      );
    } on Exception catch (error) {
      logger(
        LoggingLevel.debug,
        'vm_target_reachable check failed: $error',
        logger: 'Doctor',
      );
      return _check(
        id: 'vm_target_reachable',
        status: DoctorCheckStatus.fail,
        critical: true,
        diagnostic: 'Failed to reach VM target: $error',
        fixCommand:
            'Use --target with exact app.debugPort.wsUri or run discover_debug_apps.',
      );
    } finally {
      if (disconnectAfterCheck) {
        await connectionContext.disconnect();
      }
    }
  }

  Future<Map<String, Object?>> _checkVisualCaptureBackend({
    required final VisualCaptureBroker broker,
  }) async {
    final skipped = _skipAppOwnedBridgeCheck(
      broker: broker,
      id: 'visual_capture_backend',
      fixCommand:
          'Start or connect to the target app before probing app-owned capture backends.',
    );
    if (skipped != null) {
      return skipped;
    }
    try {
      final result = await broker.status();
      final capabilityNames = result.capabilities
          .map((final capability) => capability.wireName)
          .join(', ');
      final status = switch (result.status) {
        PermissionStatus.unsupported ||
        PermissionStatus.unsupportedUntilAppBridge => DoctorCheckStatus.warn,
        _ => DoctorCheckStatus.pass,
      };
      return _check(
        id: 'visual_capture_backend',
        status: status,
        critical: false,
        diagnostic:
            'Visual capture backend ${result.backend} (owner: ${result.owner.wireName}; capabilities: $capabilityNames).',
        fixCommand:
            'Use `flutter_mcp_cli permissions status` to inspect capture support for the selected target.',
      );
    } on Object catch (error) {
      logger(
        LoggingLevel.debug,
        'visual_capture_backend check failed: $error',
        logger: 'Doctor',
      );
      return _check(
        id: 'visual_capture_backend',
        status: DoctorCheckStatus.warn,
        critical: false,
        diagnostic: 'Visual capture backend probe failed: $error',
        fixCommand:
            'Verify the host visual-capture helper can run, or use the Flutter-layer capture path on supported targets.',
      );
    }
  }

  Future<Map<String, Object?>> _checkVisualCapturePermission({
    required final VisualCaptureBroker broker,
  }) async {
    final skipped = _skipAppOwnedBridgeCheck(
      broker: broker,
      id: 'visual_capture_permission',
      fixCommand:
          'Start or connect to the target app before probing app-owned capture permissions.',
    );
    if (skipped != null) {
      return skipped;
    }
    try {
      final result = await broker.status();
      final status = result.status.isGranted
          ? DoctorCheckStatus.pass
          : DoctorCheckStatus.warn;
      return _check(
        id: 'visual_capture_permission',
        status: status,
        critical: false,
        diagnostic:
            'Visual capture permission status: ${result.status.wireName} (${result.backend}).',
        fixCommand: result.canOpenSettings
            ? 'Run `flutter_mcp_cli permissions open-settings` or retry a capture command with auto-request enabled.'
            : 'Permission is not required or not supported on this target.',
      );
    } on Object catch (error) {
      logger(
        LoggingLevel.debug,
        'visual_capture_permission check failed: $error',
        logger: 'Doctor',
      );
      return _check(
        id: 'visual_capture_permission',
        status: DoctorCheckStatus.warn,
        critical: false,
        diagnostic: 'Visual capture permission probe failed: $error',
        fixCommand:
            'Use `flutter_mcp_cli permissions status` for a direct permission check after fixing the host adapter.',
      );
    }
  }

  Future<Map<String, Object?>> _checkVisualCaptureTruthMode({
    required final VisualCaptureBroker broker,
  }) async {
    final skipped = _skipAppOwnedBridgeCheck(
      broker: broker,
      id: 'visual_capture_truth_mode',
      fixCommand:
          'Start or connect to the target app before probing app-owned capture truth mode.',
    );
    if (skipped != null) {
      return skipped;
    }
    try {
      final result = await broker.prepareForCapture(
        requestedMode: screenshotModeAuto,
        policy: PermissionPolicy.checkOnly,
      );
      final actualMode = result.actualMode ?? 'unavailable';
      final status = switch (broker.effectivePlatform) {
        'macos' when actualMode == screenshotModeDesktopWindow =>
          DoctorCheckStatus.pass,
        'web' when actualMode == screenshotModeFlutterLayer =>
          DoctorCheckStatus.pass,
        _ => DoctorCheckStatus.warn,
      };
      return _check(
        id: 'visual_capture_truth_mode',
        status: status,
        critical: false,
        diagnostic:
            'Visual truth path requested ${screenshotModeAuto} -> actual $actualMode'
            '${result.fallbackReason == null ? '' : ' (${result.fallbackReason})'}.',
        fixCommand:
            'Grant capture permission or adjust the target/capture mode before relying on visual assertions.',
      );
    } on Object catch (error) {
      logger(
        LoggingLevel.debug,
        'visual_capture_truth_mode check failed: $error',
        logger: 'Doctor',
      );
      return _check(
        id: 'visual_capture_truth_mode',
        status: DoctorCheckStatus.warn,
        critical: false,
        diagnostic: 'Visual truth-mode probe failed: $error',
        fixCommand:
            'Fix the visual-capture backend or fall back to an explicitly supported capture mode.',
      );
    }
  }

  Future<Map<String, Object?>> _checkAppPermissionBridge({
    required final VisualCaptureBroker broker,
  }) async {
    if (broker.adapter.owner != PermissionOwner.app) {
      return _check(
        id: 'app_permission_bridge',
        status: DoctorCheckStatus.pass,
        critical: false,
        diagnostic: 'App permission bridge is not required for this target.',
        fixCommand:
            'Only app-owned capture targets need the optional permission bridge.',
      );
    }
    if (!dynamicRegistrySupported) {
      return _check(
        id: 'app_permission_bridge',
        status: DoctorCheckStatus.warn,
        critical: false,
        diagnostic:
            'App permission bridge could not be checked because dynamic registry support is disabled.',
        fixCommand:
            'Run with --dynamics and install the optional app permission bridge if this target requires it.',
      );
    }
    if (!connectionContext.isConnected) {
      return _check(
        id: 'app_permission_bridge',
        status: DoctorCheckStatus.warn,
        critical: false,
        diagnostic:
            'App permission bridge could not be checked because VM target is not connected.',
        fixCommand:
            'Use --target <ws_uri> or start the debug app before re-running doctor.',
      );
    }

    final installed = await broker.isAppBridgeInstalled();
    return _check(
      id: 'app_permission_bridge',
      status: installed ? DoctorCheckStatus.pass : DoctorCheckStatus.warn,
      critical: false,
      diagnostic: installed
          ? 'App permission bridge detected through dynamic registry.'
          : 'App permission bridge not detected.',
      fixCommand:
          'Install the optional mcp_toolkit permission delegate and re-run doctor.',
    );
  }

  Map<String, Object?>? _skipAppOwnedBridgeCheck({
    required final VisualCaptureBroker broker,
    required final String id,
    required final String fixCommand,
  }) {
    if (broker.adapter.owner != PermissionOwner.app ||
        connectionContext.isConnected) {
      return null;
    }
    return _check(
      id: id,
      status: DoctorCheckStatus.warn,
      critical: false,
      diagnostic:
          'App-owned visual capture could not be checked because VM target is not connected.',
      fixCommand: fixCommand,
    );
  }

  Future<Map<String, Object?>> _checkDynamicRegistryAvailable({
    required final Duration timeout,
  }) async {
    if (!dynamicRegistrySupported) {
      return _check(
        id: 'dynamic_registry_available',
        status: DoctorCheckStatus.warn,
        critical: false,
        diagnostic: 'Dynamic registry support is disabled (--no-dynamics).',
        fixCommand: 'Run with --dynamics to enable dynamic registry checks.',
      );
    }

    try {
      final result = await executor
          .execute(const ListClientToolsAndResourcesCommand())
          .timeout(timeout);

      if (result.ok) {
        final payload = switch (result.data) {
          final Map<String, Object?> value => value,
          final Map value => value.cast<String, Object?>(),
          _ => const <String, Object?>{},
        };
        final tools = switch (payload['tools']) {
          final List list => list.length,
          _ => 0,
        };
        final resources = switch (payload['resources']) {
          final List list => list.length,
          _ => 0,
        };
        return _check(
          id: 'dynamic_registry_available',
          status: DoctorCheckStatus.pass,
          critical: false,
          diagnostic:
              'Dynamic registry reachable (tools: $tools, resources: $resources).',
          fixCommand:
              'If expected tools are missing, hot-reload the app and retry discovery.',
        );
      }

      final errorCode = result.error?.code;
      final status =
          (errorCode == CoreErrorCode.vmNotConnected ||
              errorCode == CoreErrorCode.connectionSelectionRequired ||
              errorCode == CoreErrorCode.connectFailed)
          ? DoctorCheckStatus.warn
          : DoctorCheckStatus.fail;

      return _check(
        id: 'dynamic_registry_available',
        status: status,
        critical: false,
        diagnostic:
            'Dynamic registry check failed: ${result.error?.message ?? 'unknown error'}',
        fixCommand:
            'Ensure app-side mcp_toolkit registration is active, then retry.',
      );
    } on TimeoutException {
      return _check(
        id: 'dynamic_registry_available',
        status: DoctorCheckStatus.warn,
        critical: false,
        diagnostic:
            'Dynamic registry check timed out after ${timeout.inMilliseconds}ms',
        fixCommand: 'Increase --timeout-ms and retry when app is responsive.',
      );
    } on Exception catch (error) {
      return _check(
        id: 'dynamic_registry_available',
        status: DoctorCheckStatus.warn,
        critical: false,
        diagnostic: 'Dynamic registry check failed unexpectedly: $error',
        fixCommand:
            'Verify app-side dynamic registry initialization and retry doctor.',
      );
    }
  }

  Future<Map<String, Object?>> _checkToolkitExtensions({
    required final Duration timeout,
  }) async {
    try {
      final result = await executor
          .execute(const GetExtensionRpcsCommand())
          .timeout(timeout);

      if (!result.ok) {
        final errorCode = result.error?.code;
        final status =
            (errorCode == CoreErrorCode.vmNotConnected ||
                errorCode == CoreErrorCode.connectionSelectionRequired ||
                errorCode == CoreErrorCode.connectFailed)
            ? DoctorCheckStatus.warn
            : DoctorCheckStatus.fail;

        return _check(
          id: 'mcp_toolkit_extensions',
          status: status,
          critical: false,
          diagnostic:
              'Failed to read extension RPCs: '
              '${result.error?.message ?? 'unknown error'}',
          fixCommand:
              'Run `flutter_mcp_cli exec --name get_extension_rpcs --args "{}"`. '
              'If unavailable, install and initialize mcp_toolkit, then hot restart '
              'or rerun the app in debug mode.',
        );
      }

      final extensionList = switch (result.data) {
        final List values => values.map((final value) => '$value').toSet(),
        _ => <String>{},
      };

      final requiredExtensions = <String>{
        mcpToolkitExtKeys.appErrors,
        mcpToolkitExtKeys.viewDetails,
        mcpToolkitExtKeys.viewScreenshots,
        mcpToolkitExtKeys.inspectWidgetAtPoint,
      };
      final missing = requiredExtensions.difference(extensionList).toList()
        ..sort();

      if (missing.isNotEmpty) {
        return _check(
          id: 'mcp_toolkit_extensions',
          status: DoctorCheckStatus.fail,
          critical: false,
          diagnostic:
              'Missing required toolkit extensions: ${missing.join(', ')}',
          fixCommand:
              'App-level inspection is blocked. Ensure '
              '`MCPToolkitBinding.instance..initialize()..initializeFlutterToolkit();` '
              'runs before `runApp`, '
              'then hot restart or rerun the app. If app cannot be modified, skip '
              'screenshot/layout/error inspection claims.',
        );
      }

      return _check(
        id: 'mcp_toolkit_extensions',
        status: DoctorCheckStatus.pass,
        critical: false,
        diagnostic:
            'Required toolkit extensions detected '
            '(${requiredExtensions.length}/${requiredExtensions.length}).',
        fixCommand:
            'If screenshots are blank, keep app window visible/foreground and '
            'retry get_screenshots.',
      );
    } on TimeoutException {
      return _check(
        id: 'mcp_toolkit_extensions',
        status: DoctorCheckStatus.warn,
        critical: false,
        diagnostic:
            'Extension RPC check timed out after ${timeout.inMilliseconds}ms',
        fixCommand:
            'Increase --timeout-ms or retry with explicit --target <ws_uri>.',
      );
    } on Exception catch (error) {
      return _check(
        id: 'mcp_toolkit_extensions',
        status: DoctorCheckStatus.warn,
        critical: false,
        diagnostic: 'Extension RPC check failed unexpectedly: $error',
        fixCommand:
            'Retry with exact app.debugPort.wsUri target. If app was just '
            'instrumented, perform full restart and re-run doctor.',
      );
    }
  }

  Map<String, Object?> _check({
    required final String id,
    required final DoctorCheckStatus status,
    required final bool critical,
    required final String diagnostic,
    required final String fixCommand,
  }) {
    return {
      'id': id,
      'status': status.name,
      'critical': critical,
      'diagnostic': diagnostic,
      'fix_command': fixCommand,
    };
  }

  String _firstNonEmptyLine(final String text) {
    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return '';
  }
}
