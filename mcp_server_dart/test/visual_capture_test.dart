import 'dart:io';

import 'package:flutter_mcp_toolkit_server/flutter_mcp_core.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/desktop_window_screenshot.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/web_browser_screenshot.dart';
import 'package:test/test.dart';

void main() {
  test(
    'macOS host broker offers desktop_window for ios simulator targets',
    () async {
      if (!Platform.isMacOS) {
        return;
      }

      final broker = VisualCaptureBroker(
        configuration: const CoreRuntimeConfiguration(
          vmHost: 'localhost',
          vmPort: 8181,
          resourcesSupported: true,
          imagesSupported: true,
          dumpsSupported: false,
          dynamicRegistrySupported: true,
          saveImagesToFiles: false,
          flutterDevice: 'ios',
        ),
        adapters: <VisualCapturePlatformAdapter>[
          MacOsDesktopWindowScreenshotService(
            runProcess: (_, final _) async =>
                ProcessResult(0, 0, '{"ok":true,"status":"granted"}', ''),
          ),
        ],
      );

      final prepared = await broker.prepareForCapture(
        requestedMode: screenshotModeAuto,
      );

      expect(prepared.actualMode, screenshotModeDesktopWindow);
      expect(prepared.supportedModes, contains(screenshotModeDesktopWindow));
    },
  );

  test(
    'macOS host broker offers desktop_window for chrome web targets',
    () async {
      if (!Platform.isMacOS) {
        return;
      }

      final broker = VisualCaptureBroker(
        configuration: const CoreRuntimeConfiguration(
          vmHost: 'localhost',
          vmPort: 8181,
          resourcesSupported: true,
          imagesSupported: true,
          dumpsSupported: false,
          dynamicRegistrySupported: true,
          saveImagesToFiles: false,
          flutterDevice: 'chrome',
        ),
        adapters: <VisualCapturePlatformAdapter>[
          WebBrowserScreenshotService(
            configuration: const CoreRuntimeConfiguration(
              vmHost: 'localhost',
              vmPort: 8181,
              resourcesSupported: true,
              imagesSupported: true,
              dumpsSupported: false,
              dynamicRegistrySupported: true,
              saveImagesToFiles: false,
              flutterDevice: 'chrome',
            ),
            macHost: MacOsDesktopWindowScreenshotService(
              runProcess: (_, final _) async =>
                  ProcessResult(0, 0, '{"ok":true,"status":"granted"}', ''),
            ),
          ),
        ],
      );

      final prepared = await broker.prepareForCapture(
        requestedMode: screenshotModeAuto,
      );

      expect(prepared.actualMode, screenshotModeDesktopWindow);
      expect(prepared.supportedModes, contains(screenshotModeDesktopWindow));
    },
  );

  test('app bridge metadata wins over placeholder adapter metadata', () async {
    final broker = VisualCaptureBroker(
      configuration: const CoreRuntimeConfiguration(
        vmHost: 'localhost',
        vmPort: 8181,
        resourcesSupported: true,
        imagesSupported: true,
        dumpsSupported: false,
        dynamicRegistrySupported: true,
        saveImagesToFiles: false,
        flutterDevice: 'ios',
      ),
      dynamicGateway: _FakeDynamicGateway(),
      adapters: const <VisualCapturePlatformAdapter>[
        _PlaceholderAppBridgeAdapter(),
      ],
    );

    final result = await broker.status();

    expect(result.status, equals(PermissionStatus.granted));
    expect(result.backend, equals('ios_app_bridge'));
    expect(result.capabilities, equals({CaptureCapability.flutterLayer}));
    expect(result.supportedModes, equals({screenshotModeFlutterLayer}));
    expect(result.truthMode, equals(screenshotModeFlutterLayer));
    expect(result.appBridgeInstalled, isTrue);
  });

  test(
    'prepareForCapture honors bridge-supported modes on app-owned targets',
    () async {
      final broker = VisualCaptureBroker(
        configuration: const CoreRuntimeConfiguration(
          vmHost: 'localhost',
          vmPort: 8181,
          resourcesSupported: true,
          imagesSupported: true,
          dumpsSupported: false,
          dynamicRegistrySupported: true,
          saveImagesToFiles: false,
          flutterDevice: 'ios',
        ),
        dynamicGateway: _FakeDynamicGateway(),
        adapters: const <VisualCapturePlatformAdapter>[
          _PlaceholderAppBridgeAdapter(),
        ],
      );

      final result = await broker.prepareForCapture(
        requestedMode: screenshotModeFlutterLayer,
      );

      expect(result.actualMode, equals(screenshotModeFlutterLayer));
      expect(result.fallbackReason, isNull);
      expect(result.canCapture, isTrue);
    },
  );
}

final class _PlaceholderAppBridgeAdapter
    implements VisualCapturePlatformAdapter {
  const _PlaceholderAppBridgeAdapter();

  @override
  String get backend => 'ios_app_bridge';

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
      effectivePlatform == 'ios';

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

final class _FakeDynamicGateway implements CoreDynamicGateway {
  @override
  Future<CoreResult> dynamicRegistryStats({
    required final bool includeAppDetails,
  }) async => CoreResult.success();

  @override
  Future<CoreResult> listClientToolsAndResources() async =>
      CoreResult.success();

  @override
  Future<CoreResult> runClientResource(final String resourceUri) async =>
      CoreResult.success(
        data: <String, Object?>{
          'payload': <String, Object?>{
            'supportedKinds': <String>[PermissionKind.visualCapture.wireName],
          },
        },
      );

  @override
  Future<CoreResult> runClientTool(
    final String toolName,
    final Map<String, Object?> arguments,
  ) async => CoreResult.success(
    data: <String, Object?>{
      'parameters': <String, Object?>{
        'status': PermissionStatus.granted.wireName,
        'backend': 'app_bridge',
        'capabilities': <String>[CaptureCapability.flutterLayer.wireName],
        'supportedModes': const <String>[screenshotModeFlutterLayer],
        'truthMode': screenshotModeFlutterLayer,
      },
    },
  );
}
