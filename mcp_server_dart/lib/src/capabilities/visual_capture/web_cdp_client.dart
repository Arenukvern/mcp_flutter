// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/web_cdp_discovery.dart';

final class WebCdpCaptureException implements Exception {
  const WebCdpCaptureException({
    required this.message,
    this.code = 'screenshot_failed',
    this.details = const <String, Object?>{},
  });

  final String message;
  final String code;
  final Map<String, Object?> details;

  @override
  String toString() => message;
}

/// Captures PNG bytes from a CDP page target.
abstract interface class WebTabPngCapturer {
  Future<Uint8List> capturePng({
    required final WebCdpEndpoint endpoint,
    final Duration timeout,
  });
}

/// Minimal CDP client for `Page.captureScreenshot` on a page target.
final class WebCdpScreenshotClient implements WebTabPngCapturer {
  const WebCdpScreenshotClient();

  @override
  Future<Uint8List> capturePng({
    required final WebCdpEndpoint endpoint,
    final Duration timeout = const Duration(seconds: 12),
  }) async {
    WebSocketChannel? channel;
    try {
      channel = WebSocketChannel.connect(endpoint.pageWsUrl);
      await channel.ready.timeout(timeout);
      final responses = channel.stream.asBroadcastStream();

      await _sendCommand(
        responses,
        channel.sink,
        method: 'Page.enable',
        id: 1,
        timeout: timeout,
      );

      final result = await _sendCommand(
        responses,
        channel.sink,
        method: 'Page.captureScreenshot',
        id: 2,
        params: const <String, Object?>{
          'format': 'png',
          'captureBeyondViewport': true,
          'fromSurface': true,
        },
        timeout: timeout,
      );

      final data = result?['data'];
      if (data is! String || data.isEmpty) {
        throw WebCdpCaptureException(
          message: 'CDP Page.captureScreenshot returned no image data.',
          details: endpoint.toMetadata(),
        );
      }

      return Uint8List.fromList(base64Decode(data));
    } on WebCdpCaptureException {
      rethrow;
    } on TimeoutException {
      throw WebCdpCaptureException(
        message: 'CDP capture timed out.',
        code: 'websocket_failed',
        details: endpoint.toMetadata(),
      );
    } on Object catch (e) {
      throw WebCdpCaptureException(
        message: 'CDP capture failed: $e',
        code: 'websocket_failed',
        details: endpoint.toMetadata(),
      );
    } finally {
      await channel?.sink.close();
    }
  }

  Future<Map<String, Object?>?> _sendCommand(
    final Stream<dynamic> responses,
    final StreamSink<dynamic> sink, {
    required final String method,
    required final int id,
    required final Duration timeout, final Map<String, Object?> params = const <String, Object?>{},
  }) async {
    final payload = jsonEncode(<String, Object?>{
      'id': id,
      'method': method,
      'params': params,
    });
    sink.add(payload);

    final response = await responses
        .map((final event) {
          if (event is String) {
            return jsonDecode(event);
          }
          if (event is List<int>) {
            return jsonDecode(utf8.decode(event));
          }
          return null;
        })
        .where((final decoded) => decoded is Map && (decoded['id'] as num?)?.toInt() == id)
        .map((final decoded) => Map<String, Object?>.from(decoded as Map))
        .first
        .timeout(timeout);

    if (response.containsKey('error')) {
      throw WebCdpCaptureException(
        message: 'CDP $method failed: ${response['error']}',
        details: <String, Object?>{'method': method, 'error': response['error']},
      );
    }

    final result = response['result'];
    if (result is Map) {
      return Map<String, Object?>.from(result);
    }
    return null;
  }
}

bool isRetryableWebCdpFailure(final Object? error) {
  if (error is! WebCdpCaptureException) {
    return false;
  }
  return error.code == 'websocket_failed' ||
      error.code == 'target_not_found' ||
      error.code == 'discovery_failed';
}
