import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:flutter_mcp_toolkit_server/flutter_mcp_core.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/desktop_window_screenshot.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/web_browser_screenshot.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/web_cdp_client.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/web_cdp_discovery.dart';

final class _FakeMacHost implements DesktopWindowScreenshotService {
  _FakeMacHost({this.captureResult, this.throws = false});

  final DesktopWindowScreenshotCapture? captureResult;
  final bool throws;

  @override
  Future<DesktopWindowScreenshotCapture?> capture({
    required final String projectDir,
    required final String device,
    required final bool compress,
    final int? targetPid,
    final String? cacheDir,
  }) async {
    if (throws) {
      throw const DesktopWindowCaptureException(message: 'SCK failed');
    }
    return captureResult;
  }

  @override
  Future<Map<String, Object?>> focus({
    required final String device,
    final int? targetPid,
    final String? cacheDir,
  }) async => const <String, Object?>{'ok': true};

  @override
  bool supportsPlatform(final String effectivePlatform) => false;
}

final class _FakeCdpClient implements WebTabPngCapturer {
  _FakeCdpClient(this.png);

  final Uint8List png;

  @override
  Future<Uint8List> capturePng({
    required final WebCdpEndpoint endpoint,
    final Duration timeout = const Duration(seconds: 12),
  }) async => png;
}

void main() {
  test(
    'WebBrowserScreenshotService falls back from SCK failure to CDP',
    () async {
      final server = await HttpServer.bind('127.0.0.1', 0);
      addTearDown(server.close);
      final port = server.port;
      server.listen((final request) async {
        if (request.uri.path == '/json/list') {
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(<Map<String, Object?>>[
                <String, Object?>{
                  'type': 'page',
                  'url': 'http://localhost:8080/',
                  'webSocketDebuggerUrl':
                      'ws://127.0.0.1:$port/devtools/page/test',
                },
              ]),
            );
          await request.response.close();
        } else {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        }
      });

      final png = Uint8List.fromList(<int>[1, 2, 3]);
      final service = WebBrowserScreenshotService(
        configuration: CoreRuntimeConfiguration(
          vmHost: 'localhost',
          vmPort: 8181,
          resourcesSupported: true,
          imagesSupported: true,
          dumpsSupported: false,
          dynamicRegistrySupported: true,
          saveImagesToFiles: false,
          flutterDevice: 'chrome',
          webBrowserDebuggingPort: port,
        ),
        macHost: _FakeMacHost(throws: true),
        cdpClient: _FakeCdpClient(png),
      );

      final capture = await service.capture(
        projectDir: '.',
        device: 'chrome',
        compress: true,
      );

      expect(capture, isNotNull);
      expect(capture!.captureMode, screenshotModeDesktopWindow);
      expect(capture.metadata['captureBackend'], 'cdp');
      expect(capture.images.single, base64Encode(png));
    },
  );

  test(
    'WebBrowserScreenshotService returns macos_host metadata when SCK succeeds',
    () async {
      if (!Platform.isMacOS) {
        return;
      }
      const macCapture = DesktopWindowScreenshotCapture(
        images: <String>['a'],
        captureMode: screenshotModeDesktopWindow,
        metadata: <String, Object?>{'window': 'Chrome'},
      );
      final service = WebBrowserScreenshotService(
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
        macHost: _FakeMacHost(captureResult: macCapture),
        cdpClient: _FakeCdpClient(Uint8List.fromList(<int>[9])),
      );

      final capture = await service.capture(
        projectDir: '.',
        device: 'chrome',
        compress: false,
      );

      expect(capture?.metadata['captureBackend'], 'macos_host');
      expect(capture?.metadata['window'], 'Chrome');
    },
  );

  test('returns null for non-web devices', () async {
    final service = WebBrowserScreenshotService(
      configuration: const CoreRuntimeConfiguration(
        vmHost: 'localhost',
        vmPort: 8181,
        resourcesSupported: true,
        imagesSupported: true,
        dumpsSupported: false,
        dynamicRegistrySupported: true,
        saveImagesToFiles: false,
        flutterDevice: 'macos',
      ),
    );
    expect(
      await service.capture(projectDir: '.', device: 'macos', compress: true),
      isNull,
    );
  });
}
