import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/visual_capture.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/visual_capture_target_platform.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/types/core_types.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/vm_connections/connection_context.dart';
import 'package:test/test.dart';
CoreRuntimeConfiguration _baseConfiguration({
  String? flutterDevice,
  int? webBrowserDebuggingPort,
}) {
  return CoreRuntimeConfiguration(
    vmHost: '127.0.0.1',
    vmPort: 8181,
    resourcesSupported: true,
    imagesSupported: true,
    dumpsSupported: false,
    dynamicRegistrySupported: true,
    saveImagesToFiles: false,
    flutterDevice: flutterDevice,
    webBrowserDebuggingPort: webBrowserDebuggingPort,
  );
}

void main() {
  test('explicit flutterDevice wins without VM', () async {
    final resolution = await resolveVisualCaptureTargetPlatform(
      configuration: _baseConfiguration(flutterDevice: 'android'),
      connectionContext: ConnectionContext(
        defaultHost: '127.0.0.1',
        defaultPort: 8181,
        logger: (level, message, {logger = 'test'}) {},
        discoverPorts: () async => <int>[],
      ),
      probeTimeout: const Duration(seconds: 2),
    );
    expect(resolution.platform, 'android');
    expect(resolution.warning, isNull);
  });

  test('platformOverride android routes before unrelated web CDP port', () async {
  final cdpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => cdpServer.close(force: true));
    unawaited(
      cdpServer.forEach((request) async {
        final body = jsonEncode([
          {
            'type': 'page',
            'url': 'http://localhost:${cdpServer.port}/',
            'webSocketDebuggerUrl': 'ws://127.0.0.1:${cdpServer.port}/devtools/page',
          },
        ]);
        request.response
          ..headers.contentType = ContentType.json
          ..write(body);
        await request.response.close();
      }),
    );

    final vmServer = await _startVmFake(
      platformOverride: 'android',
      jsUtil: false,
    );
    addTearDown(() => vmServer.close(force: true));

    final context = await _connectVmFake(vmServer);
    final resolution = await resolveVisualCaptureTargetPlatform(
      configuration: _baseConfiguration(
        webBrowserDebuggingPort: cdpServer.port,
      ),
      connectionContext: context,
      probeTimeout: const Duration(seconds: 2),
    );

    expect(resolution.platform, 'android');
    expect(
      VisualCaptureBroker(
        configuration: _baseConfiguration(),
        targetPlatform: resolution.platform,
      ).adapter.backend,
      'android_app_bridge',
    );
  });

  test('js_util probe resolves web', () async {
    final vmServer = await _startVmFake(jsUtil: true);
    addTearDown(() => vmServer.close(force: true));

    final context = await _connectVmFake(vmServer);
    final resolution = await resolveVisualCaptureTargetPlatform(
      configuration: _baseConfiguration(),
      connectionContext: context,
      probeTimeout: const Duration(seconds: 2),
    );

    expect(resolution.platform, 'web');
  });

  test(
    'hanging VM probes skip CDP and never resolve to web when CDP is viable',
    () async {
      final cdpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => cdpServer.close(force: true));
      unawaited(
        cdpServer.forEach((request) async {
          final body = jsonEncode([
            {
              'type': 'page',
              'url': 'http://localhost:${cdpServer.port}/',
              'webSocketDebuggerUrl':
                  'ws://127.0.0.1:${cdpServer.port}/devtools/page',
            },
          ]);
          request.response
            ..headers.contentType = ContentType.json
            ..write(body);
          await request.response.close();
        }),
      );

      final vmServer = await _startVmFake(
        jsUtil: false,
        delayMethods: const {'evaluate', 'ext.flutter.platformOverride'},
      );
      addTearDown(() => vmServer.close(force: true));

      final context = await _connectVmFake(vmServer);
      final resolution = await resolveVisualCaptureTargetPlatform(
        configuration: _baseConfiguration(
          webBrowserDebuggingPort: cdpServer.port,
        ),
        connectionContext: context,
        probeTimeout: const Duration(milliseconds: 80),
      );

      expect(resolution.platform, isNot('web'));
      expect(
        resolution.platform,
        effectiveVisualCapturePlatformFromConfiguration(_baseConfiguration()),
      );
      expect(resolution.warning, isNotNull);
      expect(resolution.warning, contains('timed out'));
    },
  );

  test(
    'js_util timeout ignores browser-derived native platformOverride answers',
    () async {
      final vmServer = await _startVmFake(
        jsUtil: false,
        platformOverride: 'macOS',
        delayMethods: const {'evaluate'},
      );
      addTearDown(() => vmServer.close(force: true));

      final context = await _connectVmFake(vmServer);
      final configuration = _baseConfiguration();
      final resolution = await resolveVisualCaptureTargetPlatform(
        configuration: configuration,
        connectionContext: context,
        probeTimeout: const Duration(milliseconds: 80),
      );

      expect(resolution.platform, isNot('macos'));
      expect(
        resolution.platform,
        effectiveVisualCapturePlatformFromConfiguration(configuration),
      );
      expect(resolution.warning, isNotNull);
      expect(resolution.warning, contains('timed out'));
      expect(resolution.warning, contains('host/default routing'));
    },
  );

  test(
    'catchVisualCaptureTargetPlatformProbeFailures returns warning on throw',
    () async {
      final configuration = _baseConfiguration();
      final resolution = await catchVisualCaptureTargetPlatformProbeFailures(
        configuration: configuration,
        probe: Future<VisualCaptureTargetPlatformResolution>(() async {
          throw StateError('paused');
        }),
      );

      expect(
        resolution.platform,
        effectiveVisualCapturePlatformFromConfiguration(configuration),
      );
      expect(resolution.warning, contains('StateError'));
      expect(resolution.warning, contains('host/default routing'));
    },
  );

  test('probe timeout falls back to host configuration', () async {
    final vmServer = await _startVmFake(
      delayMethod: 'ext.flutter.platformOverride',
    );
    addTearDown(() => vmServer.close(force: true));

    final context = await _connectVmFake(vmServer);
    final resolution = await resolveVisualCaptureTargetPlatform(
      configuration: _baseConfiguration(),
      connectionContext: context,
      probeTimeout: const Duration(milliseconds: 50),
    );

    expect(
      resolution.platform,
      effectiveVisualCapturePlatformFromConfiguration(_baseConfiguration()),
    );
    expect(resolution.warning, isNotNull);
    expect(resolution.warning, contains('timed out'));
  });

  test('disconnected VM yields warning instead of aborting', () async {
    final context = ConnectionContext(
      defaultHost: '127.0.0.1',
      defaultPort: 8181,
      logger: (level, message, {logger = 'test'}) {},
      discoverPorts: () async => <int>[],
    );

    final resolution = await resolveVisualCaptureTargetPlatform(
      configuration: _baseConfiguration(),
      connectionContext: context,
      probeTimeout: const Duration(milliseconds: 200),
    );

    expect(resolution.warning, isNotNull);
    expect(resolution.warning, contains('not connected'));
  });
}

Future<HttpServer> _startVmFake({
  bool jsUtil = false,
  String? platformOverride,
  String? delayMethod,
  Set<String> delayMethods = const {},
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  const isolateId = 'isolates/1';
  const libraryId = 'libraries/1';

  unawaited(
    server.forEach((request) async {
      if (!WebSocketTransformer.isUpgradeRequest(request)) {
        final result = switch (request.uri.pathSegments.last) {
          'getVM' => <String, Object?>{
            'type': 'VM',
            'pid': 4242,
            'isolates': [
              {'type': '@Isolate', 'id': isolateId, 'name': 'main'},
            ],
          },
          'getIsolate' => <String, Object?>{
            'type': 'Isolate',
            'id': isolateId,
            'rootLib': <String, Object?>{
              'type': '@Library',
              'id': libraryId,
              'name': 'root',
            },
            'extensionRPCs': ['ext.flutter.reassemble'],
          },
          _ => <String, Object?>{},
        };
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'jsonrpc': '2.0', 'result': result}));
        await request.response.close();
        return;
      }

      // ignore: close_sinks
      final socket = await WebSocketTransformer.upgrade(request);
      socket.listen((raw) async {
        final Object? frame;
        try {
          frame = jsonDecode(raw as String);
        } on FormatException {
          return;
        }
        if (frame is! Map<String, dynamic>) {
          return;
        }
        final method = frame['method'] as String? ?? '';
        final id = frame['id'];

        if ((delayMethod != null && method == delayMethod) ||
            delayMethods.contains(method)) {
          await Future<void>.delayed(const Duration(seconds: 5));
        }

        final payload = switch (method) {
          'getVM' => <String, Object?>{
            'type': 'VM',
            'pid': 4242,
            'isolates': [
              {'type': '@Isolate', 'id': isolateId, 'name': 'main'},
            ],
          },
          'getIsolate' => <String, Object?>{
            'type': 'Isolate',
            'id': isolateId,
            'rootLib': <String, Object?>{
              'type': '@Library',
              'id': libraryId,
              'name': 'root',
            },
            'extensionRPCs': ['ext.flutter.reassemble'],
          },
          'evaluate' => <String, Object?>{
            'type': '@Instance',
            'kind': 'Bool',
            'class': <String, Object?>{'type': '@Class', 'name': 'bool'},
            'valueAsString': jsUtil ? 'true' : 'false',
          },
          'ext.flutter.platformOverride' => <String, Object?>{
            'type': '_extensionType',
            'method': method,
            'value': platformOverride,
          },
          _ => <String, Object?>{'type': 'Success'},
        };

        socket.add(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': id,
            'result': payload,
          }),
        );
      });
    }),
  );
  return server;
}

Future<ConnectionContext> _connectVmFake(HttpServer server) async {
  final context = ConnectionContext(
    defaultHost: '127.0.0.1',
    defaultPort: 8181,
    logger: (level, message, {logger = 'test'}) {},
    discoverPorts: () async => <int>[server.port],
  );
  await context.connect();
  return context;
}