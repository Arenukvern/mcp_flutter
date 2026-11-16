// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/visual_capture.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/web_cdp_discovery.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/types/core_types.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/vm_connections/connection_context.dart';
import 'package:vm_service/vm_service.dart';

/// Resolves which capture platform rules apply for the connected debug target.
///
/// [configuration.flutterDevice] wins when set explicitly; otherwise a connected
/// VM target is probed before falling back to the host default.
Future<String> resolveVisualCaptureTargetPlatform({
  required CoreRuntimeConfiguration configuration,
  required ConnectionContext connectionContext,
}) async {
  final fromDevice = _platformFromFlutterDevice(configuration.flutterDevice);
  if (fromDevice != null) {
    return fromDevice;
  }

  if (!connectionContext.isConnected) {
    return effectiveVisualCapturePlatformFromConfiguration(configuration);
  }

  if (connectionContext.stickyBrowserDebugPort != null) {
    return 'web';
  }

  final connectionTarget = _connectionTargetForProbe(
    connectionContext: connectionContext,
    configuration: configuration,
  );
  if (await isWebCdpCaptureViable(
    configuration: configuration,
    connectionTarget: connectionTarget,
  )) {
    return 'web';
  }

  final probed = await _probeTargetPlatformViaIsolate(
    connectionContext: connectionContext,
  );
  if (probed != null) {
    return probed;
  }

  return effectiveVisualCapturePlatformFromConfiguration(configuration);
}

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

Future<String?> _probeTargetPlatformViaIsolate({
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

    final webProbe = await vmService.evaluate(
      isolateId,
      libraryId,
      "const bool.fromEnvironment('dart.library.js_util')",
    );
    if (_instanceRefIsTrue(webProbe)) {
      return 'web';
    }

    final platformProbe = await vmService.evaluate(
      isolateId,
      libraryId,
      'defaultTargetPlatform.name',
    );
    final platformName = _stringFromInstanceRef(platformProbe);
    if (platformName != null) {
      return _normalizeTargetPlatformName(platformName);
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
  if (value.kind == 'Bool') {
    return value.valueAsString == 'true';
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

String _normalizeTargetPlatformName(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'android':
      return 'android';
    case 'ios':
    case 'i':
      return 'ios';
    case 'linux':
      return 'linux';
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
