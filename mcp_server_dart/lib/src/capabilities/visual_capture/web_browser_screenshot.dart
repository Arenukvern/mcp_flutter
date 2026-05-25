// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/desktop_window_screenshot.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/visual_capture.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/types/core_types.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/vm_connections/connection_context.dart';

import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/web_cdp_client.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/web_cdp_discovery.dart';

/// Web capture: macOS ScreenCaptureKit first, then CDP (Phase B).
final class WebBrowserScreenshotService
    implements DesktopWindowScreenshotService, VisualCapturePlatformAdapter {
  WebBrowserScreenshotService({
    required this.configuration,
    this.connectionContext,
    final DesktopWindowScreenshotService? macHost,
    final WebTabPngCapturer? cdpClient,
  }) : _macHost = macHost ?? MacOsDesktopWindowScreenshotService(),
       _cdpClient = cdpClient ?? const WebCdpScreenshotClient();

  final CoreRuntimeConfiguration configuration;
  final ConnectionContext? connectionContext;
  final DesktopWindowScreenshotService _macHost;
  final WebTabPngCapturer _cdpClient;

  CoreConnectionTarget? get _connectionTarget {
    final port = connectionContext?.stickyBrowserDebugPort;
    if (port == null) {
      return null;
    }
    return CoreConnectionTarget(
      targetId: 'sticky-web-cdp',
      host: '127.0.0.1',
      port: port,
      endpoint: '127.0.0.1:$port',
      isSticky: true,
      isCurrent: connectionContext?.isConnected ?? false,
      browserDebugPort: port,
    );
  }

  @override
  String get backend => 'web_browser';

  @override
  Set<CaptureCapability> get capabilities => const <CaptureCapability>{
    CaptureCapability.desktopWindow,
    CaptureCapability.flutterLayer,
  };

  @override
  PermissionOwner get owner => PermissionOwner.none;

  @override
  Set<String> get supportedModes => const <String>{
    screenshotModeDesktopWindow,
    screenshotModeFlutterLayer,
  };

  @override
  String get truthMode => screenshotModeDesktopWindow;

  @override
  bool supportsPlatform(final String effectivePlatform) =>
      effectivePlatform == 'web';

  @override
  Future<PermissionBrokerResult> status({
    required final PermissionKind kind,
    required final PermissionPolicy policy,
    required final CoreRuntimeConfiguration configuration,
  }) async {
    final cdpViable = await isWebCdpCaptureViable(
      configuration: configuration,
      connectionTarget: _connectionTarget,
    );
    final macViable = Platform.isMacOS;
    final modes = <String>{screenshotModeFlutterLayer};
    if (cdpViable || macViable) {
      modes.add(screenshotModeDesktopWindow);
    }
    return PermissionBrokerResult(
      kind: kind,
      status: PermissionStatus.notRequired,
      policy: policy,
      owner: owner,
      backend: backend,
      capabilities: capabilities,
      supportedModes: modes,
      truthMode: truthMode,
      message: cdpViable
          ? 'Web capture can use CDP tab screenshots.'
          : macViable
          ? 'Web capture can use macOS host window pixels.'
          : 'Web capture uses Flutter-layer screenshots only.',
    );
  }

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

  @override
  Future<Map<String, Object?>> focus({
    required final String device,
    final int? targetPid,
    final String? cacheDir,
  }) async {
    if (Platform.isMacOS && isWebFlutterDevice(device)) {
      return _macHost.focus(
        device: device,
        targetPid: targetPid,
        cacheDir: cacheDir,
      );
    }
    return const <String, Object?>{
      'ok': true,
      'message': 'CDP capture does not require window focus.',
    };
  }

  @override
  Future<DesktopWindowScreenshotCapture?> capture({
    required final String projectDir,
    required final String device,
    required final bool compress,
    final int? targetPid,
    final String? cacheDir,
  }) async {
    if (!isWebFlutterDevice(device)) {
      return null;
    }

    if (Platform.isMacOS) {
      try {
        final macCapture = await _macHost.capture(
          projectDir: projectDir,
          device: device,
          compress: compress,
          targetPid: targetPid,
          cacheDir: cacheDir,
        );
        if (macCapture != null) {
          return DesktopWindowScreenshotCapture(
            images: macCapture.images,
            captureMode: macCapture.captureMode,
            metadata: <String, Object?>{
              ...macCapture.metadata,
              'captureBackend': 'macos_host',
            },
          );
        }
      } on DesktopWindowCaptureException {
        // Fall through to CDP.
      }
    }

    return _captureViaCdp(compress: compress, rediscover: false);
  }

  Future<DesktopWindowScreenshotCapture?> _captureViaCdp({
    required final bool compress,
    required final bool rediscover,
  }) async {
    final endpoint = await discoverWebCdpEndpoint(
      configuration: configuration,
      connectionTarget: rediscover ? null : _connectionTarget,
    );
    if (endpoint == null) {
      if (isWebFlutterDevice(configuration.flutterDevice) &&
          configuration.flutterDevice == 'web-server') {
        return null;
      }
      throw const WebCdpCaptureException(
        message:
            'Chrome DevTools endpoint not found. Launch with '
            'flutter run -d chrome and/or pass --web-browser-debugging-port.',
        code: 'discovery_failed',
      );
    }

    try {
      final png = await _cdpClient.capturePng(endpoint: endpoint);
      final encoded = compress ? base64Encode(png) : base64Encode(png);
      return DesktopWindowScreenshotCapture(
        images: <String>[encoded],
        captureMode: screenshotModeDesktopWindow,
        metadata: <String, Object?>{
          'captureBackend': 'cdp',
          'requestedCompress': compress,
          ...endpoint.toMetadata(),
        },
      );
    } on WebCdpCaptureException catch (e) {
      if (!rediscover && isRetryableWebCdpFailure(e)) {
        return _captureViaCdp(compress: compress, rediscover: true);
      }
      rethrow;
    }
  }
}
