import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/web_cdp_client.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/web_cdp_discovery.dart';
import 'package:test/test.dart';

void main() {
  test(
    'WebCdpScreenshotClient returns PNG bytes from Page.captureScreenshot',
    () async {
      final server = await HttpServer.bind('127.0.0.1', 0);
      addTearDown(server.close);
      final port = server.port;

      server.listen((final request) async {
        if (!WebSocketTransformer.isUpgradeRequest(request)) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen((final data) {
          final decoded = jsonDecode(data as String) as Map<String, Object?>;
          final id = (decoded['id'] as num?)?.toInt();
          final method = decoded['method'];
          if (method == 'Page.enable') {
            socket.add(
              jsonEncode(<String, Object?>{
                'id': id,
                'result': <String, Object?>{},
              }),
            );
            return;
          }
          if (method == 'Page.captureScreenshot') {
            socket.add(
              jsonEncode(<String, Object?>{
                'id': id,
                'result': <String, Object?>{
                  'data': base64Encode(<int>[0x89, 0x50, 0x4E, 0x47]),
                },
              }),
            );
          }
        });
      });

      const client = WebCdpScreenshotClient();
      final png = await client.capturePng(
        endpoint: WebCdpEndpoint(
          debugPort: port,
          pageWsUrl: Uri.parse('ws://127.0.0.1:$port'),
        ),
      );

      expect(png, isA<Uint8List>());
      expect(png.length, greaterThan(0));
    },
  );

  test('isRetryableWebCdpFailure marks websocket and discovery codes', () {
    expect(
      isRetryableWebCdpFailure(
        const WebCdpCaptureException(message: 'x', code: 'websocket_failed'),
      ),
      isTrue,
    );
    expect(
      isRetryableWebCdpFailure(const WebCdpCaptureException(message: 'x')),
      isFalse,
    );
  });
}
