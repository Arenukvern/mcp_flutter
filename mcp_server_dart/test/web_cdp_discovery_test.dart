import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_toolkit_server/flutter_mcp_core.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/web_cdp_discovery.dart';
import 'package:test/test.dart';

void main() {
  test(
    'parseChromeDebugPortsFromProcessList extracts remote-debugging-port',
    () {
      const listing = '''
/usr/bin/Google Chrome --remote-debugging-port=50541 --user-data-dir=/tmp/x
chromium --remote-debugging-port=9222
''';
      expect(parseChromeDebugPortsFromProcessList(listing), [9222, 50541]);
    },
  );

  test('selectCdpPageTarget prefers localhost and web-port', () {
    final selected = selectCdpPageTarget(
      targets: <Map<String, Object?>>[
        <String, Object?>{
          'type': 'page',
          'url': 'https://example.com/',
          'webSocketDebuggerUrl': 'ws://127.0.0.1:1/devtools/page/1',
        },
        <String, Object?>{
          'type': 'page',
          'url': 'http://localhost:8080/',
          'webSocketDebuggerUrl': 'ws://127.0.0.1:1/devtools/page/2',
        },
      ],
      preferredWebPort: 8080,
    );
    expect(selected?['url'], 'http://localhost:8080/');
  });

  test('discoverWebCdpEndpoint uses CLI override and /json/list', () async {
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
                    'ws://127.0.0.1:$port/devtools/page/abc',
              },
            ]),
          );
        await request.response.close();
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    });

    final endpoint = await discoverWebCdpEndpoint(
      configuration: CoreRuntimeConfiguration(
        vmHost: 'localhost',
        vmPort: 8181,
        resourcesSupported: true,
        imagesSupported: true,
        dumpsSupported: false,
        dynamicRegistrySupported: true,
        saveImagesToFiles: false,
        webBrowserDebuggingPort: port,
        webPort: 8080,
      ),
    );

    expect(endpoint?.debugPort, port);
    expect(endpoint?.pageUrl, 'http://localhost:8080/');
    expect(endpoint?.discoverySource, 'cli_override');
  });

  test('parseMachineEvent reads browserDebugPort from nested fields', () {
    final parsed = FlutterToolMachineDiscovery.parseMachineEvent(
      <String, Object?>{
        'event': 'app.debugPort',
        'params': <String, Object?>{
          'wsUri': 'ws://127.0.0.1:50541/ws',
          'port': 50541,
        },
      },
    );
    expect(parsed.browserDebugPort, 50541);
    expect(parsed.vmServiceWsUri?.port, 50541);
  });

  test('sticky connection target port is tried before process scan', () async {
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
                'url': 'http://127.0.0.1:3000/',
                'webSocketDebuggerUrl':
                    'ws://127.0.0.1:$port/devtools/page/sticky',
              },
            ]),
          );
        await request.response.close();
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    });

    final endpoint = await discoverWebCdpEndpoint(
      configuration: const CoreRuntimeConfiguration(
        vmHost: 'localhost',
        vmPort: 8181,
        resourcesSupported: true,
        imagesSupported: true,
        dumpsSupported: false,
        dynamicRegistrySupported: true,
        saveImagesToFiles: false,
      ),
      connectionTarget: CoreConnectionTarget(
        targetId: 't',
        host: '127.0.0.1',
        port: port,
        endpoint: 'ws://127.0.0.1:$port/ws',
        isSticky: true,
        isCurrent: true,
        browserDebugPort: port,
      ),
    );

    expect(endpoint?.discoverySource, 'connection_target');
  });
}
