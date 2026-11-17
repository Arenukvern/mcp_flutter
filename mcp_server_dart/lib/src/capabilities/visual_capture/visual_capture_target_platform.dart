// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:async';

import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/visual_capture.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/web_cdp_discovery.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/types/core_types.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/vm_connections/connection_context.dart';
import 'package:vm_service/vm_service.dart';

const _flutterPlatformOverrideExtension = 'ext.flutter.platformOverride';

/// Result of probing the connected debug target for visual-capture routing.
typedef VisualCaptureTargetPlatformResolution = ({
  String platform,
  String? warning,
});

typedef ResolveVisualCaptureTargetPlatform =
    Future<VisualCaptureTargetPlatformResolution> Function({
      required CoreRuntimeConfiguration configuration,
      required ConnectionContext connectionContext,
      required Duration probeTimeout,
    });

/// Resolves which capture platform rules apply for the connected debug target.
///
/// [configuration.flutterDevice] wins when set explicitly; otherwise a connected
/// VM target is probed before falling back to the host default.
Future<VisualCaptureTargetPlatformResolution> resolveVisualCaptureTargetPlatform({
  required CoreRuntimeConfiguration configuration,
  required ConnectionContext connectionContext,
  required Duration probeTimeout,
}) async {
  final fromDevice = _platformFromFlutterDevice(configuration.flutterDevice);
  if (fromDevice != null) {
    return (platform: fromDevice, warning: null);
  }

  if (!connectionContext.isConnected) {
    return (
      platform: effectiveVisualCapturePlatformFromConfiguration(configuration),
      warning:
          'Visual capture target platform could not be probed because the VM target is not connected.',
    );
  }

  final timedOut = <String>{};
  final probeDeadline = DateTime.now().add(probeTimeout);

  Duration remainingProbeBudget() {
    final left = probeDeadline.difference(DateTime.now());
    if (left <= Duration.zero) {
      return Duration.zero;
    }
    return left;
  }

  Future<T?> runVmProbe<T>({
    required String label,
    required Future<T> Function() action,
  }) =>
      _runProbe(
        label: label,
        timedOut: timedOut,
        probeTimeout: remainingProbeBudget(),
        action: action,
      );

  final webViaJsUtil = await runVmProbe(
    label: 'dart.library.js_util',
    action: () => _probeWebViaJsUtil(connectionContext: connectionContext),
  );
  if (webViaJsUtil == true) {
    return (platform: 'web', warning: null);
  }

  final jsUtilTimedOut = timedOut.contains('dart.library.js_util');

  final fromExtension = await runVmProbe(
    label: _flutterPlatformOverrideExtension,
    action: () => _probeTargetPlatformViaFlutterExtension(
      connectionContext: connectionContext,
    ),
  );
  if (!jsUtilTimedOut &&
      fromExtension != null &&
      _isNativeCapturePlatform(fromExtension)) {
    return _resolution(
      platform: fromExtension,
      configuration: configuration,
      timedOut: timedOut,
    );
  }

  final fromEvaluate = await runVmProbe(
    label: 'defaultTargetPlatform',
    action: () => _probeTargetPlatformViaEvaluateFallback(
      connectionContext: connectionContext,
    ),
  );
  if (!jsUtilTimedOut &&
      fromEvaluate != null &&
      _isNativeCapturePlatform(fromEvaluate)) {
    return _resolution(
      platform: fromEvaluate,
      configuration: configuration,
      timedOut: timedOut,
    );
  }

  final vmProbesTimedOut = timedOut.isNotEmpty;
  if (!vmProbesTimedOut) {
    final connectionTarget = _connectionTargetForProbe(
      connectionContext: connectionContext,
      configuration: configuration,
    );
    final cdpViable = await runVmProbe(
      label: 'web_cdp_viability',
      action: () => isWebCdpCaptureViable(
        configuration: configuration,
        connectionTarget: connectionTarget,
        includeProcessScan: false,
      ),
    );
    if (cdpViable == true) {
      return _resolution(
        platform: 'web',
        configuration: configuration,
        timedOut: timedOut,
      );
    }
  }

  if (!jsUtilTimedOut && (fromExtension == 'web' || fromEvaluate == 'web')) {
    return _resolution(
      platform: 'web',
      configuration: configuration,
      timedOut: timedOut,
    );
  }

  return _resolution(
    platform: effectiveVisualCapturePlatformFromConfiguration(configuration),
    configuration: configuration,
    timedOut: timedOut,
  );
}

VisualCaptureTargetPlatformResolution _resolution({
  required String platform,
  required CoreRuntimeConfiguration configuration,
  required Set<String> timedOut,
}) =>
    (
      platform: platform,
      warning: _probeResolutionWarning(
        timedOut: timedOut,
        resolvedPlatform: platform,
        configuration: configuration,
      ),
    );

Future<VisualCaptureTargetPlatformResolution>
catchVisualCaptureTargetPlatformProbeFailures({
  required Future<VisualCaptureTargetPlatformResolution> probe,
  required CoreRuntimeConfiguration configuration,
  required CoreLogger logger,
}) async {
  try {
    return await probe;
  } on Object catch (error, stackTrace) {
    logger(
      LoggingLevel.debug,
      'Visual capture target platform probe failed: $error',
      logger: 'DoctorRunner',
    );
    logger(
      LoggingLevel.debug,
      '$stackTrace',
      logger: 'DoctorRunner',
    );
    return (
      platform: effectiveVisualCapturePlatformFromConfiguration(configuration),
      warning:
          'Visual capture target platform probe failed (${error.runtimeType}); '
          'using host/default routing.',
    );
  }
}

String? _probeResolutionWarning({
  required Set<String> timedOut,
  required String resolvedPlatform,
  required CoreRuntimeConfiguration configuration,
}) {
  if (timedOut.isEmpty) {
    return null;
  }
  final hostPlatform = effectiveVisualCapturePlatformFromConfiguration(
    configuration,
  );
  if (resolvedPlatform == hostPlatform) {
    return 'Visual capture target platform probe timed out (${timedOut.join(', ')}); '
        'using host/default routing.';
  }
  return 'Visual capture target platform probe timed out (${timedOut.join(', ')}); '
      'resolved platform: $resolvedPlatform.';
}

Future<T?> _runProbe<T>({
  required String label,
  required Set<String> timedOut,
  required Duration probeTimeout,
  required Future<T> Function() action,
}) async {
  if (probeTimeout <= Duration.zero) {
    timedOut.add(label);
    return null;
  }
  try {
    return await action().timeout(probeTimeout);
  } on TimeoutException {
    timedOut.add(label);
    return null;
  }
}

bool _isNativeCapturePlatform(String platform) => switch (platform) {
      'android' || 'ios' || 'linux' || 'macos' || 'windows' || 'fuchsia' =>
        true,
      _ => false,
    };

String? _platformFromFlutterDevice(String? flutterDevice) {
  final device = flutterDevice?.trim().toLowerCase();
  if (device == null || device.isEmpty) {
    return null;
  }
  return switch (device) {
    'macos' => 'macos',
    'chrome' || 'web' || 'web-server' => 'web',
    'ios' => 'ios',
    'android' => 'android',
    'linux' => 'linux',
    _ => null,
  };
}

CoreConnectionTarget? _connectionTargetForProbe({
  required ConnectionContext connectionContext,
  required CoreRuntimeConfiguration configuration,
}) {
  final stickyPort = connectionContext.stickyBrowserDebugPort;
  if (stickyPort != null) {
    return CoreConnectionTarget(
      targetId: 'doctor-visual-capture-probe',
      host: configuration.vmHost,
      port: configuration.vmPort,
      endpoint: '${configuration.vmHost}:${configuration.vmPort}',
      isSticky: true,
      isCurrent: true,
      browserDebugPort: stickyPort,
    );
  }

  final endpoint = connectionContext.activeEndpoint;
  if (endpoint == null) {
    return null;
  }

  return CoreConnectionTarget(
    targetId: CoreConnectionTarget.buildTargetId(
      vmServiceWsUri: endpoint.wsUri,
    ),
    host: endpoint.host,
    port: endpoint.port,
    endpoint: endpoint.display,
    isSticky: true,
    isCurrent: true,
    browserDebugPort: connectionContext.stickyBrowserDebugPort,
  );
}

Future<bool> _probeWebViaJsUtil({
  required ConnectionContext connectionContext,
}) async {
  final vmService = connectionContext.vmService;
  if (vmService == null) {
    return false;
  }

  final isolateRef = await connectionContext.getFlutterIsolate();
  final isolateId = isolateRef?.id;
  if (isolateId == null) {
    return false;
  }

  try {
    final isolate = await vmService.getIsolate(isolateId);
    final libraryId = isolate.rootLib?.id;
    if (libraryId == null) {
      return false;
    }

    final webProbe = await vmService.evaluate(
      isolateId,
      libraryId,
      "const bool.fromEnvironment('dart.library.js_util')",
    );
    return _instanceRefIsTrue(webProbe);
  } on Object {
    return false;
  }
}

Future<String?> _probeTargetPlatformViaFlutterExtension({
  required ConnectionContext connectionContext,
}) async {
  final isolateRef = await connectionContext.getFlutterIsolate();
  final isolateId = isolateRef?.id;
  if (isolateId == null) {
    return null;
  }

  final response = await connectionContext.callServiceExtension(
    _flutterPlatformOverrideExtension,
    isolateId: isolateId,
  );
  if (response == null) {
    return null;
  }

  final payload = response.json;
  if (payload == null) {
    return null;
  }
  final value = payload['value'];
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return _normalizeFlutterPlatformOverrideValue(value);
}

Future<String?> _probeTargetPlatformViaEvaluateFallback({
  required ConnectionContext connectionContext,
}) async {
  final vmService = connectionContext.vmService;
  if (vmService == null) {
    return null;
  }

  final isolateRef = await connectionContext.getFlutterIsolate();
  final isolateId = isolateRef?.id;
  if (isolateId == null) {
    return null;
  }

  try {
    final isolate = await vmService.getIsolate(isolateId);
    final libraryId = isolate.rootLib?.id;
    if (libraryId == null) {
      return null;
    }

    final platformProbe = await vmService.evaluate(
      isolateId,
      libraryId,
      'defaultTargetPlatform.name',
    );
    final platformName = _stringFromInstanceRef(platformProbe);
    if (platformName != null) {
      return _normalizeFlutterPlatformOverrideValue(platformName);
    }
  } on Object {
    return null;
  }

  return null;
}

bool _instanceRefIsTrue(Object? value) {
  if (value is! InstanceRef) {
    return false;
  }
  return value.valueAsString == 'true';
}

String? _stringFromInstanceRef(Object? value) {
  if (value is! InstanceRef) {
    return null;
  }
  final raw = value.valueAsString;
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return raw;
}

String _normalizeFlutterPlatformOverrideValue(String raw) {
  switch (raw.trim()) {
    case 'android':
      return 'android';
    case 'iOS':
    case 'ios':
      return 'ios';
    case 'linux':
      return 'linux';
    case 'macOS':
    case 'macos':
      return 'macos';
    case 'windows':
      return 'windows';
    case 'fuchsia':
      return 'fuchsia';
    default:
      return raw.trim().toLowerCase();
  }
}
