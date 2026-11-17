import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/visual_capture.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/web_browser_screenshot.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/types/core_types.dart';
import 'package:test/test.dart';

CoreRuntimeConfiguration _baseConfiguration({String? flutterDevice}) {
  return CoreRuntimeConfiguration(
    vmHost: '127.0.0.1',
    vmPort: 8181,
    resourcesSupported: true,
    imagesSupported: true,
    dumpsSupported: false,
    dynamicRegistrySupported: true,
    saveImagesToFiles: false,
    flutterDevice: flutterDevice,
  );
}

void main() {
  test('broker targetPlatform override selects web backend adapters', () {
    final broker = VisualCaptureBroker(
      configuration: _baseConfiguration(),
      targetPlatform: 'web',
      adapters: <VisualCapturePlatformAdapter>[
        WebBrowserScreenshotService(
          configuration: _baseConfiguration(flutterDevice: 'chrome'),
        ),
      ],
    );

    expect(broker.effectivePlatform, 'web');
    expect(broker.adapter.backend, 'web_browser');
  });

  test('broker targetPlatform override routes android to app-owned bridge', () {
    final broker = VisualCaptureBroker(
      configuration: _baseConfiguration(),
      targetPlatform: 'android',
    );

    expect(broker.effectivePlatform, 'android');
    expect(broker.adapter.backend, 'android_app_bridge');
    expect(broker.adapter.owner, PermissionOwner.app);
  });

  test('broker targetPlatform override routes linux desktop to app bridge', () {
    final broker = VisualCaptureBroker(
      configuration: _baseConfiguration(),
      targetPlatform: 'linux',
    );

    expect(broker.effectivePlatform, 'linux');
    expect(broker.adapter.backend, 'linux_app_bridge');
  });

  test('configuration flutterDevice selects web without target override', () {
    final broker = VisualCaptureBroker(
      configuration: _baseConfiguration(flutterDevice: 'chrome'),
    );

    expect(broker.effectivePlatform, 'web');
    expect(broker.adapter.backend, isIn(['web_browser', 'web_flutter_layer']));
  });

  test(
    'unset flutterDevice with web targetPlatform selects web_browser backend',
    () async {
      final configuration = _baseConfiguration();
      final broker = VisualCaptureBroker(
        configuration: configuration,
        targetPlatform: 'web',
        adapters: <VisualCapturePlatformAdapter>[
          WebBrowserScreenshotService(
            configuration: configuration,
            connectionContext: null,
          ),
        ],
      );

      final status = await broker.status();
      expect(broker.effectivePlatform, 'web');
      expect(status.backend, 'web_browser');
      expect(status.owner, PermissionOwner.none);
    },
  );
}