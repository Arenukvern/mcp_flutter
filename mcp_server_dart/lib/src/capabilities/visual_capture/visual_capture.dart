// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/dynamic_registry/dynamic_gateway.dart';

// Pure value types re-exported from flutter_mcp_toolkit_core.
export 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart'
    show
        CaptureCapability,
        PermissionBrokerResult,
        PermissionKind,
        PermissionOwner,
        PermissionPolicy,
        PermissionStatus,
        parsePermissionKind,
        parsePermissionPolicy,
        screenshotModeAuto,
        screenshotModeDesktopWindow,
        screenshotModeFlutterLayer;

abstract interface class VisualCapturePlatformAdapter {
  String get backend;

  PermissionOwner get owner;

  Set<CaptureCapability> get capabilities;

  Set<String> get supportedModes;

  String get truthMode;

  bool supportsPlatform(final String effectivePlatform);

  Future<PermissionBrokerResult> status({
    required final PermissionKind kind,
    required final PermissionPolicy policy,
    required final CoreRuntimeConfiguration configuration,
  });

  Future<PermissionBrokerResult> request({
    required final PermissionKind kind,
    required final PermissionPolicy policy,
    required final CoreRuntimeConfiguration configuration,
  });

  Future<PermissionBrokerResult> openSettings({
    required final PermissionKind kind,
    required final PermissionPolicy policy,
    required final CoreRuntimeConfiguration configuration,
  });
}

abstract interface class AppPermissionBridgeGateway {
  Future<List<String>> listSupportedKinds();

  Future<PermissionBrokerResult> status({
    required final PermissionKind kind,
    required final PermissionPolicy policy,
  });

  Future<PermissionBrokerResult> request({
    required final PermissionKind kind,
    required final PermissionPolicy policy,
  });

  Future<PermissionBrokerResult> openSettings({
    required final PermissionKind kind,
    required final PermissionPolicy policy,
  });
}

const visualCaptureBridgeTools = (
  status: 'permission_status',
  request: 'request_permission',
  openSettings: 'open_permission_settings',
);

const visualCaptureBridgeResource =
    'visual://localhost/permissions/supported/kinds';

final class DynamicRegistryAppPermissionBridgeGateway
    implements AppPermissionBridgeGateway {
  const DynamicRegistryAppPermissionBridgeGateway({required this.gateway});

  final CoreDynamicGateway gateway;

  @override
  Future<List<String>> listSupportedKinds() async {
    final result = await gateway.runClientResource(visualCaptureBridgeResource);
    if (!result.ok) {
      return const <String>[];
    }

    final data = _asObject(result.data);
    final content = '${data['content'] ?? ''}'.trim();
    if (content.isEmpty) {
      final payload = _asObject(data['payload']);
      return _asStringList(payload['supportedKinds']);
    }

    try {
      final decoded = jsonDecode(content);
      if (decoded is Map<String, Object?>) {
        return _supportedKindsFromObject(decoded);
      }
      if (decoded is Map) {
        return _supportedKindsFromObject(decoded);
      }
      if (decoded is List) {
        return decoded.whereType<String>().toList(growable: false);
      }
    } on Exception {
      return const <String>[];
    }
    return const <String>[];
  }

  @override
  Future<PermissionBrokerResult> status({
    required final PermissionKind kind,
    required final PermissionPolicy policy,
  }) => _runTool(
    toolName: visualCaptureBridgeTools.status,
    kind: kind,
    policy: policy,
  );

  @override
  Future<PermissionBrokerResult> request({
    required final PermissionKind kind,
    required final PermissionPolicy policy,
  }) => _runTool(
    toolName: visualCaptureBridgeTools.request,
    kind: kind,
    policy: policy,
  );

  @override
  Future<PermissionBrokerResult> openSettings({
    required final PermissionKind kind,
    required final PermissionPolicy policy,
  }) => _runTool(
    toolName: visualCaptureBridgeTools.openSettings,
    kind: kind,
    policy: policy,
  );

  Future<PermissionBrokerResult> _runTool({
    required final String toolName,
    required final PermissionKind kind,
    required final PermissionPolicy policy,
  }) async {
    final result = await gateway.runClientTool(toolName, <String, Object?>{
      'kind': kind.wireName,
      'policy': policy.wireName,
    });
    if (!result.ok) {
      return PermissionBrokerResult(
        kind: kind,
        status: PermissionStatus.unsupportedUntilAppBridge,
        policy: policy,
        owner: PermissionOwner.app,
        backend: 'app_bridge',
        capabilities: const <CaptureCapability>{
          CaptureCapability.unsupportedUntilAppBridge,
        },
        supportedModes: const <String>{},
        message: result.error?.message,
        details: <String, Object?>{'error': result.error?.toJson()},
        appBridgeInstalled: true,
      );
    }

    final data = _asObject(result.data);
    final parameters = _asObject(data['parameters']);
    return _permissionResultFromJson(
      kind: kind,
      policy: policy,
      payload: parameters,
      fallbackBackend: 'app_bridge',
      fallbackOwner: PermissionOwner.app,
      bridgeInstalled: true,
    );
  }
}

List<String> _supportedKindsFromObject(final Map<dynamic, dynamic> value) {
  final direct = _asStringList(value['supportedKinds']);
  if (direct.isNotEmpty) {
    return direct;
  }

  return _asStringList(_asObject(value['parameters'])['supportedKinds']);
}

final class WebVisualCapturePlatformAdapter
    implements VisualCapturePlatformAdapter {
  const WebVisualCapturePlatformAdapter();

  @override
  String get backend => 'web_flutter_layer';

  @override
  Set<CaptureCapability> get capabilities => const <CaptureCapability>{
    CaptureCapability.flutterLayer,
  };

  @override
  PermissionOwner get owner => PermissionOwner.none;

  @override
  Set<String> get supportedModes => const <String>{screenshotModeFlutterLayer};

  @override
  String get truthMode => screenshotModeFlutterLayer;

  @override
  bool supportsPlatform(final String effectivePlatform) =>
      effectivePlatform == 'web';

  @override
  Future<PermissionBrokerResult> status({
    required final PermissionKind kind,
    required final PermissionPolicy policy,
    required final CoreRuntimeConfiguration configuration,
  }) async => PermissionBrokerResult(
    kind: kind,
    status: PermissionStatus.notRequired,
    policy: policy,
    owner: owner,
    backend: backend,
    capabilities: capabilities,
    supportedModes: supportedModes,
    truthMode: truthMode,
    message: 'Web capture uses Flutter-layer screenshots only.',
  );

  @override
  Future<PermissionBrokerResult> request({
    required final PermissionKind kind,
    required final PermissionPolicy policy,
    required final CoreRuntimeConfiguration configuration,
  }) => status(kind: kind, policy: policy, configuration: configuration);

  @override
  Future<PermissionBrokerResult> openSettings({
    required final PermissionKind kind,
    required final PermissionPolicy policy,
    required final CoreRuntimeConfiguration configuration,
  }) => status(kind: kind, policy: policy, configuration: configuration);
}

final class UnsupportedUntilAppBridgeVisualCapturePlatformAdapter
    implements VisualCapturePlatformAdapter {
  const UnsupportedUntilAppBridgeVisualCapturePlatformAdapter({
    required this.platforms,
    required this.backend,
  });

  final Set<String> platforms;

  @override
  final String backend;

  @override
  Set<CaptureCapability> get capabilities => const <CaptureCapability>{
    CaptureCapability.unsupportedUntilAppBridge,
  };

  @override
  PermissionOwner get owner => PermissionOwner.app;

  @override
  Set<String> get supportedModes => const <String>{};

  @override
  String get truthMode => CaptureCapability.unsupportedUntilAppBridge.wireName;

  @override
  bool supportsPlatform(final String effectivePlatform) =>
      platforms.contains(effectivePlatform);

  @override
  Future<PermissionBrokerResult> status({
    required final PermissionKind kind,
    required final PermissionPolicy policy,
    required final CoreRuntimeConfiguration configuration,
  }) async => PermissionBrokerResult(
    kind: kind,
    status: PermissionStatus.unsupportedUntilAppBridge,
    policy: policy,
    owner: owner,
    backend: backend,
    capabilities: capabilities,
    supportedModes: supportedModes,
    truthMode: truthMode,
    message:
        'Visual capture is app-owned on this target and requires the optional app permission bridge.',
    details: <String, Object?>{
      'platform': _effectiveVisualCapturePlatform(configuration),
    },
  );

  @override
  Future<PermissionBrokerResult> request({
    required final PermissionKind kind,
    required final PermissionPolicy policy,
    required final CoreRuntimeConfiguration configuration,
  }) => status(kind: kind, policy: policy, configuration: configuration);

  @override
  Future<PermissionBrokerResult> openSettings({
    required final PermissionKind kind,
    required final PermissionPolicy policy,
    required final CoreRuntimeConfiguration configuration,
  }) => status(kind: kind, policy: policy, configuration: configuration);
}

final class VisualCaptureBroker {
  VisualCaptureBroker({
    required this.configuration,
    this.dynamicGateway,
    final Iterable<VisualCapturePlatformAdapter>? adapters,
  }) : _adapters = <VisualCapturePlatformAdapter>[
         ...?adapters,
         const WebVisualCapturePlatformAdapter(),
         if (!io.Platform.isMacOS)
           const UnsupportedUntilAppBridgeVisualCapturePlatformAdapter(
             platforms: <String>{'ios'},
             backend: 'ios_app_bridge',
           ),
         const UnsupportedUntilAppBridgeVisualCapturePlatformAdapter(
           platforms: <String>{'android'},
           backend: 'android_app_bridge',
         ),
         const UnsupportedUntilAppBridgeVisualCapturePlatformAdapter(
           platforms: <String>{'linux'},
           backend: 'linux_app_bridge',
         ),
       ];

  final CoreRuntimeConfiguration configuration;
  final CoreDynamicGateway? dynamicGateway;
  final List<VisualCapturePlatformAdapter> _adapters;

  String get effectivePlatform =>
      _effectiveVisualCapturePlatform(configuration);

  VisualCapturePlatformAdapter get adapter {
    for (final candidate in _adapters) {
      if (candidate.supportsPlatform(effectivePlatform)) {
        return candidate;
      }
    }
    return const UnsupportedUntilAppBridgeVisualCapturePlatformAdapter(
      platforms: <String>{'unknown'},
      backend: 'unknown_app_bridge',
    );
  }

  Future<PermissionBrokerResult> status({
    final PermissionKind kind = PermissionKind.visualCapture,
    final PermissionPolicy policy = PermissionPolicy.checkOnly,
  }) => _dispatch(
    action: _PermissionBrokerAction.status,
    kind: kind,
    policy: policy,
  );

  Future<PermissionBrokerResult> request({
    final PermissionKind kind = PermissionKind.visualCapture,
    final PermissionPolicy policy = PermissionPolicy.requestAlways,
  }) => _dispatch(
    action: _PermissionBrokerAction.request,
    kind: kind,
    policy: policy,
  );

  Future<PermissionBrokerResult> openSettings({
    final PermissionKind kind = PermissionKind.visualCapture,
    final PermissionPolicy policy = PermissionPolicy.checkOnly,
  }) => _dispatch(
    action: _PermissionBrokerAction.openSettings,
    kind: kind,
    policy: policy,
  );

  Future<PermissionBrokerResult> prepareForCapture({
    required final String requestedMode,
    final PermissionKind kind = PermissionKind.visualCapture,
    final PermissionPolicy policy = PermissionPolicy.checkOnly,
  }) async {
    if (requestedMode == screenshotModeFlutterLayer) {
      return _successForRequestedFlutterLayer(
        await status(kind: kind, policy: policy),
        requestedMode: requestedMode,
      );
    }

    final adapterResult = await status(kind: kind, policy: policy);
    if (requestedMode == screenshotModeDesktopWindow) {
      return _prepareDesktopWindow(
        adapterResult,
        requestedMode: requestedMode,
        policy: policy,
        allowFallback: false,
      );
    }

    return _prepareAuto(
      adapterResult,
      requestedMode: requestedMode,
      policy: policy,
    );
  }

  Future<bool> isAppBridgeInstalled() async {
    if (adapter.owner != PermissionOwner.app) {
      return false;
    }
    final gateway = dynamicGateway;
    if (gateway == null) {
      return false;
    }
    final bridge = DynamicRegistryAppPermissionBridgeGateway(gateway: gateway);
    final supported = await bridge.listSupportedKinds();
    return supported.contains(PermissionKind.visualCapture.wireName);
  }

  Future<PermissionBrokerResult> _dispatch({
    required final _PermissionBrokerAction action,
    required final PermissionKind kind,
    required final PermissionPolicy policy,
  }) async {
    final selected = adapter;
    final gateway = dynamicGateway;
    if (selected.owner == PermissionOwner.app && gateway != null) {
      final bridge = DynamicRegistryAppPermissionBridgeGateway(
        gateway: gateway,
      );
      final supportedKinds = await bridge.listSupportedKinds();
      if (supportedKinds.contains(kind.wireName)) {
        final result = switch (action) {
          _PermissionBrokerAction.status => await bridge.status(
            kind: kind,
            policy: policy,
          ),
          _PermissionBrokerAction.request => await bridge.request(
            kind: kind,
            policy: policy,
          ),
          _PermissionBrokerAction.openSettings => await bridge.openSettings(
            kind: kind,
            policy: policy,
          ),
        };
        return _mergeBridgeResult(selected: selected, result: result);
      }
    }

    final result = switch (action) {
      _PermissionBrokerAction.status => await selected.status(
        kind: kind,
        policy: policy,
        configuration: configuration,
      ),
      _PermissionBrokerAction.request => await selected.request(
        kind: kind,
        policy: policy,
        configuration: configuration,
      ),
      _PermissionBrokerAction.openSettings => await selected.openSettings(
        kind: kind,
        policy: policy,
        configuration: configuration,
      ),
    };
    return result.copyWith(appBridgeInstalled: false);
  }

  Future<PermissionBrokerResult> _prepareAuto(
    final PermissionBrokerResult initial, {
    required final String requestedMode,
    required final PermissionPolicy policy,
  }) async {
    var current = initial.copyWith(requestedMode: requestedMode);
    if (current.status.isGranted &&
        current.supportedModes.contains(screenshotModeDesktopWindow)) {
      return current.copyWith(
        actualMode: screenshotModeDesktopWindow,
        truthMode: screenshotModeDesktopWindow,
        clearFallbackReason: true,
      );
    }

    if (!current.status.isGranted &&
        current.supportedModes.contains(screenshotModeDesktopWindow) &&
        (policy == PermissionPolicy.autoRequestOnce ||
            policy == PermissionPolicy.requestAlways)) {
      current = await request(kind: current.kind, policy: policy);
      current = current.copyWith(requestedMode: requestedMode);
      if (current.status.isGranted) {
        return current.copyWith(
          actualMode: screenshotModeDesktopWindow,
          truthMode: screenshotModeDesktopWindow,
          clearFallbackReason: true,
        );
      }
      if (current.status == PermissionStatus.denied) {
        return current.copyWith(
          clearActualMode: true,
          fallbackReason: 'permission_denied',
        );
      }
    }

    if (current.supportedModes.contains(screenshotModeFlutterLayer)) {
      return _successForRequestedFlutterLayer(
        current,
        requestedMode: requestedMode,
      ).copyWith(fallbackReason: _fallbackReasonForAuto(current));
    }

    return current.copyWith(
      clearActualMode: true,
      fallbackReason: _fallbackReasonForAuto(current),
    );
  }

  Future<PermissionBrokerResult> _prepareDesktopWindow(
    final PermissionBrokerResult initial, {
    required final String requestedMode,
    required final PermissionPolicy policy,
    required final bool allowFallback,
  }) async {
    var current = initial.copyWith(requestedMode: requestedMode);
    if (!current.supportedModes.contains(screenshotModeDesktopWindow)) {
      if (!allowFallback) {
        return current.copyWith(
          clearActualMode: true,
          fallbackReason: 'desktop_window_unsupported',
        );
      }
      return _successForRequestedFlutterLayer(
        current,
        requestedMode: requestedMode,
      ).copyWith(fallbackReason: 'desktop_window_unsupported');
    }

    if (current.status.isGranted) {
      return current.copyWith(
        actualMode: screenshotModeDesktopWindow,
        truthMode: screenshotModeDesktopWindow,
      );
    }

    if (policy == PermissionPolicy.autoRequestOnce ||
        policy == PermissionPolicy.requestAlways) {
      current = await request(kind: current.kind, policy: policy);
      current = current.copyWith(requestedMode: requestedMode);
      if (current.status.isGranted) {
        return current.copyWith(
          actualMode: screenshotModeDesktopWindow,
          truthMode: screenshotModeDesktopWindow,
        );
      }
      if (current.status == PermissionStatus.denied) {
        return current.copyWith(
          clearActualMode: true,
          fallbackReason: 'permission_denied',
        );
      }
    }

    if (allowFallback &&
        current.supportedModes.contains(screenshotModeFlutterLayer)) {
      return _successForRequestedFlutterLayer(
        current,
        requestedMode: requestedMode,
      ).copyWith(fallbackReason: 'desktop_window_unavailable');
    }

    return current.copyWith(
      clearActualMode: true,
      fallbackReason: 'desktop_window_permission_required',
    );
  }

  PermissionBrokerResult _successForRequestedFlutterLayer(
    final PermissionBrokerResult result, {
    required final String requestedMode,
  }) {
    if (!result.supportedModes.contains(screenshotModeFlutterLayer)) {
      return result.copyWith(
        requestedMode: requestedMode,
        clearActualMode: true,
        fallbackReason: 'flutter_layer_unsupported',
      );
    }

    return result.copyWith(
      requestedMode: requestedMode,
      actualMode: screenshotModeFlutterLayer,
      truthMode: result.truthMode,
    );
  }

  String _fallbackReasonForAuto(final PermissionBrokerResult result) {
    if (result.status == PermissionStatus.denied) {
      return 'permission_denied';
    }
    if (result.status == PermissionStatus.notDetermined) {
      return 'permission_not_granted';
    }
    if (result.status == PermissionStatus.unsupportedUntilAppBridge) {
      return 'unsupported_until_app_bridge';
    }
    if (result.status == PermissionStatus.unsupported) {
      return 'unsupported';
    }
    return 'platform_default';
  }
}

PermissionBrokerResult _mergeBridgeResult({
  required final VisualCapturePlatformAdapter selected,
  required final PermissionBrokerResult result,
}) {
  final capabilities = _hasConcreteCapabilities(result.capabilities)
      ? result.capabilities
      : selected.capabilities;
  final supportedModes = result.supportedModes.isNotEmpty
      ? result.supportedModes
      : selected.supportedModes;
  final truthMode = _isConcreteTruthMode(result.truthMode)
      ? result.truthMode
      : selected.truthMode;
  final backend = _resolveBridgeBackend(
    bridgeBackend: result.backend,
    selectedBackend: selected.backend,
  );
  return result.copyWith(
    backend: backend,
    owner: result.owner == PermissionOwner.none ? selected.owner : result.owner,
    capabilities: capabilities,
    supportedModes: supportedModes,
    truthMode: truthMode,
    appBridgeInstalled: true,
  );
}

bool _hasConcreteCapabilities(final Set<CaptureCapability> capabilities) =>
    capabilities.any(
      (final capability) =>
          capability != CaptureCapability.unsupported &&
          capability != CaptureCapability.unsupportedUntilAppBridge,
    );

bool _isConcreteTruthMode(final String? truthMode) {
  final normalized = truthMode?.trim();
  if (normalized == null || normalized.isEmpty) {
    return false;
  }
  return normalized != CaptureCapability.unsupported.wireName &&
      normalized != CaptureCapability.unsupportedUntilAppBridge.wireName;
}

String _resolveBridgeBackend({
  required final String bridgeBackend,
  required final String selectedBackend,
}) {
  final normalized = bridgeBackend.trim();
  if (normalized.isEmpty || normalized == 'app_bridge') {
    return selectedBackend;
  }
  return normalized;
}

enum _PermissionBrokerAction { status, request, openSettings }

String _effectiveVisualCapturePlatform(
  final CoreRuntimeConfiguration configuration,
) {
  final device = configuration.flutterDevice?.trim().toLowerCase();
  switch (device) {
    case 'macos':
      return 'macos';
    case 'chrome':
    case 'web':
    case 'web-server':
      return 'web';
    case 'ios':
      return 'ios';
    case 'android':
      return 'android';
    case 'linux':
      return 'linux';
  }

  final host = io.Platform.operatingSystem;
  return switch (host) {
    'macos' => 'macos',
    'linux' => 'linux',
    _ => 'unknown',
  };
}

PermissionBrokerResult permissionResultFromToolPayload({
  required final PermissionKind kind,
  required final PermissionPolicy policy,
  required final Map<String, Object?> payload,
  required final String fallbackBackend,
  required final PermissionOwner fallbackOwner,
  required final bool bridgeInstalled,
}) => _permissionResultFromJson(
  kind: kind,
  policy: policy,
  payload: payload,
  fallbackBackend: fallbackBackend,
  fallbackOwner: fallbackOwner,
  bridgeInstalled: bridgeInstalled,
);

PermissionBrokerResult _permissionResultFromJson({
  required final PermissionKind kind,
  required final PermissionPolicy policy,
  required final Map<String, Object?> payload,
  required final String fallbackBackend,
  required final PermissionOwner fallbackOwner,
  required final bool bridgeInstalled,
}) {
  final status = _parsePermissionStatus(payload['status']);
  final owner = _parsePermissionOwner(payload['owner']) ?? fallbackOwner;
  final backend = '${payload['backend'] ?? fallbackBackend}'.trim();
  final actualMode = _nullableString(payload['actualMode']);
  final truthMode = _nullableString(payload['truthMode']);
  final fallbackReason = _nullableString(payload['fallbackReason']);
  final message = _nullableString(payload['message']);

  final capabilities = <CaptureCapability>{};
  for (final value in _asStringList(payload['capabilities'])) {
    for (final candidate in CaptureCapability.values) {
      if (candidate.wireName == value) {
        capabilities.add(candidate);
      }
    }
  }

  final supportedModes = <String>{};
  _asStringList(payload['supportedModes']).forEach(supportedModes.add);

  return PermissionBrokerResult(
    kind: kind,
    status: status,
    policy: policy,
    owner: owner,
    backend: backend.isEmpty ? fallbackBackend : backend,
    capabilities: capabilities.isEmpty
        ? const <CaptureCapability>{CaptureCapability.unsupported}
        : capabilities,
    supportedModes: supportedModes,
    actualMode: actualMode,
    truthMode: truthMode,
    fallbackReason: fallbackReason,
    message: message,
    details: _asObject(payload['details']),
    canRequest: _parseBool(payload['canRequest']),
    canOpenSettings: _parseBool(payload['canOpenSettings']),
    appBridgeInstalled: bridgeInstalled,
  );
}

PermissionStatus _parsePermissionStatus(final Object? value) {
  final normalized = '$value'.trim().toLowerCase();
  for (final candidate in PermissionStatus.values) {
    if (candidate.wireName == normalized) {
      return candidate;
    }
  }
  return PermissionStatus.unsupported;
}

PermissionOwner? _parsePermissionOwner(final Object? value) {
  final normalized = '$value'.trim().toLowerCase();
  for (final candidate in PermissionOwner.values) {
    if (candidate.wireName == normalized) {
      return candidate;
    }
  }
  return null;
}

Map<String, Object?> _asObject(final Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  return const <String, Object?>{};
}

List<String> _asStringList(final Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value.whereType<String>().toList(growable: false);
}

bool _parseBool(final Object? value) => switch (value) {
  final bool v => v,
  final String v => v.toLowerCase() == 'true',
  _ => false,
};

String? _nullableString(final Object? value) {
  final text = '$value'.trim();
  if (text.isEmpty || text == 'null') {
    return null;
  }
  return text;
}
