// mcp_shared_core/lib/src/visual_capture/permission_types.dart
// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// Pure value types and enums for visual capture permission model.
// No dart:io, no dart_mcp, no transport dependencies.

const screenshotModeAuto = 'auto';
const screenshotModeFlutterLayer = 'flutter_layer';
const screenshotModeDesktopWindow = 'desktop_window';

enum PermissionKind {
  visualCapture('visual_capture');

  const PermissionKind(this.wireName);

  final String wireName;
}

PermissionKind parsePermissionKind(
  final Object? value, {
  final PermissionKind fallback = PermissionKind.visualCapture,
}) {
  final normalized = '$value'.trim().toLowerCase();
  for (final candidate in PermissionKind.values) {
    if (candidate.wireName == normalized) {
      return candidate;
    }
  }
  return fallback;
}

enum PermissionStatus {
  granted('granted'),
  denied('denied'),
  notDetermined('not_determined'),
  notRequired('not_required'),
  unsupported('unsupported'),
  unsupportedUntilAppBridge('unsupported_until_app_bridge');

  const PermissionStatus(this.wireName);

  final String wireName;

  bool get isGranted =>
      this == PermissionStatus.granted || this == PermissionStatus.notRequired;
}

enum PermissionPolicy {
  checkOnly('check_only'),
  autoRequestOnce('auto_request_once'),
  requestAlways('request_always');

  const PermissionPolicy(this.wireName);

  final String wireName;
}

PermissionPolicy parsePermissionPolicy(
  final Object? value, {
  final PermissionPolicy fallback = PermissionPolicy.checkOnly,
}) {
  final normalized = '$value'.trim().toLowerCase();
  for (final candidate in PermissionPolicy.values) {
    if (candidate.wireName == normalized) {
      return candidate;
    }
  }
  return fallback;
}

enum PermissionOwner {
  host('host'),
  app('app'),
  none('none');

  const PermissionOwner(this.wireName);

  final String wireName;
}

enum CaptureCapability {
  desktopWindow('desktop_window'),
  flutterLayer('flutter_layer'),
  unsupported('unsupported'),
  unsupportedUntilAppBridge('unsupported_until_app_bridge');

  const CaptureCapability(this.wireName);

  final String wireName;
}

final class PermissionBrokerResult {
  const PermissionBrokerResult({
    required this.kind,
    required this.status,
    required this.policy,
    required this.owner,
    required this.backend,
    required this.capabilities,
    required this.supportedModes,
    this.requestedMode,
    this.actualMode,
    this.truthMode,
    this.fallbackReason,
    this.message,
    this.details = const <String, Object?>{},
    this.canRequest = false,
    this.canOpenSettings = false,
    this.appBridgeInstalled = false,
  });

  final PermissionKind kind;
  final PermissionStatus status;
  final PermissionPolicy policy;
  final PermissionOwner owner;
  final String backend;
  final Set<CaptureCapability> capabilities;
  final Set<String> supportedModes;
  final String? requestedMode;
  final String? actualMode;
  final String? truthMode;
  final String? fallbackReason;
  final String? message;
  final Map<String, Object?> details;
  final bool canRequest;
  final bool canOpenSettings;
  final bool appBridgeInstalled;

  bool get canCapture =>
      actualMode != null && status != PermissionStatus.denied;

  PermissionBrokerResult copyWith({
    final PermissionKind? kind,
    final PermissionStatus? status,
    final PermissionPolicy? policy,
    final PermissionOwner? owner,
    final String? backend,
    final Set<CaptureCapability>? capabilities,
    final Set<String>? supportedModes,
    final String? requestedMode,
    final bool clearRequestedMode = false,
    final String? actualMode,
    final bool clearActualMode = false,
    final String? truthMode,
    final bool clearTruthMode = false,
    final String? fallbackReason,
    final bool clearFallbackReason = false,
    final String? message,
    final bool clearMessage = false,
    final Map<String, Object?>? details,
    final bool? canRequest,
    final bool? canOpenSettings,
    final bool? appBridgeInstalled,
  }) => PermissionBrokerResult(
    kind: kind ?? this.kind,
    status: status ?? this.status,
    policy: policy ?? this.policy,
    owner: owner ?? this.owner,
    backend: backend ?? this.backend,
    capabilities: capabilities ?? this.capabilities,
    supportedModes: supportedModes ?? this.supportedModes,
    requestedMode: clearRequestedMode
        ? null
        : (requestedMode ?? this.requestedMode),
    actualMode: clearActualMode ? null : (actualMode ?? this.actualMode),
    truthMode: clearTruthMode ? null : (truthMode ?? this.truthMode),
    fallbackReason: clearFallbackReason
        ? null
        : (fallbackReason ?? this.fallbackReason),
    message: clearMessage ? null : (message ?? this.message),
    details: details ?? this.details,
    canRequest: canRequest ?? this.canRequest,
    canOpenSettings: canOpenSettings ?? this.canOpenSettings,
    appBridgeInstalled: appBridgeInstalled ?? this.appBridgeInstalled,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.wireName,
    'status': status.wireName,
    'policy': policy.wireName,
    'owner': owner.wireName,
    'backend': backend,
    'capabilities': capabilities
        .map((final capability) => capability.wireName)
        .toList(growable: false),
    'supportedModes': supportedModes.toList(growable: false),
    'requestedMode': requestedMode,
    'actualMode': actualMode,
    'truthMode': truthMode,
    'fallbackReason': fallbackReason,
    'message': message,
    'details': details,
    'canRequest': canRequest,
    'canOpenSettings': canOpenSettings,
    'appBridgeInstalled': appBridgeInstalled,
  };
}
