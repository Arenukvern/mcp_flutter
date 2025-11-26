import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/flutter_inspector_mcp_server.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

base mixin WebBridgeSupport on BaseMCPToolkitServer {
  HttpServer? _webBridgeServer;
  final Map<String, WebSocketChannel> _webClients = {};
  final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};
  int _requestId = 0;

  bool get hasWebClients => _webClients.isNotEmpty;

  Future<void> startWebBridge({int port = 8183}) async {
    try {
      _webBridgeServer = await HttpServer.bind('localhost', port);
      log(
        LoggingLevel.info,
        'Web bridge server started on port $port',
        logger: 'WebBridge',
      );

      _webBridgeServer!.listen((request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          final ws = await WebSocketTransformer.upgrade(request);
          final channel = IOWebSocketChannel(ws);
          final clientId = _generateClientId();
          _webClients[clientId] = channel;

          log(
            LoggingLevel.info,
            'Web client connected: $clientId',
            logger: 'WebBridge',
          );

          channel.stream.listen(
            (message) => _handleWebMessage(clientId, message),
            onDone: () {
              _webClients.remove(clientId);
              log(
                LoggingLevel.info,
                'Web client disconnected: $clientId',
                logger: 'WebBridge',
              );
            },
            onError: (error) {
              log(
                LoggingLevel.error,
                'Web client error: $error',
                logger: 'WebBridge',
              );
            },
          );
        } else {
          request.response
            ..statusCode = HttpStatus.badRequest
            ..close();
        }
      });
    } catch (e) {
      log(
        LoggingLevel.error,
        'Failed to start web bridge server: $e',
        logger: 'WebBridge',
      );
      rethrow;
    }
  }

  String _generateClientId() {
    return 'web_client_${DateTime.now().millisecondsSinceEpoch}_${_webClients.length}';
  }

  void _handleWebMessage(String clientId, dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'mcp_service_extension':
          _handleServiceExtensionRequest(clientId, data);
          break;
        case 'mcp_service_extension_response':
          _handleServiceExtensionResponse(data);
          break;
        default:
          log(
            LoggingLevel.warning,
            'Unknown message type: $type',
            logger: 'WebBridge',
          );
      }
    } catch (e) {
      log(
        LoggingLevel.error,
        'Error handling web message: $e',
        logger: 'WebBridge',
      );
    }
  }

  Future<void> _handleServiceExtensionRequest(
    String clientId,
    Map<String, dynamic> data,
  ) async {
    final method = data['method'] as String?;
    final parameters = Map<String, String>.from(
      data['parameters'] as Map? ?? {},
    );
    final requestId = data['id'] as String?;

    if (method == null || requestId == null) {
      _sendErrorResponse(clientId, requestId ?? 'unknown', 'Invalid request');
      return;
    }

    try {
      final result = await callServiceExtensionViaWeb(method, parameters);
      _sendResponse(clientId, requestId, result);
    } catch (e) {
      _sendErrorResponse(clientId, requestId, e.toString());
    }
  }

  Future<Map<String, dynamic>> callServiceExtensionViaWeb(
    String method,
    Map<String, String> parameters,
  ) async {
    final channel = _webClients.values.firstOrNull;
    if (channel == null) {
      throw StateError('No web client connected');
    }

    final id = 'req_${_requestId++}';
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[id] = completer;

    channel.sink.add(jsonEncode({
      'type': 'mcp_service_extension',
      'id': id,
      'method': method,
      'parameters': parameters,
    }));

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pendingRequests.remove(id);
        throw TimeoutException('Service extension call timed out');
      },
    );
  }

  void _handleServiceExtensionResponse(Map<String, dynamic> data) {
    final id = data['id'] as String?;
    if (id != null && _pendingRequests.containsKey(id)) {
      if (data.containsKey('error')) {
        _pendingRequests[id]!.completeError(data['error']);
      } else {
        _pendingRequests[id]!.complete(data['result'] as Map<String, dynamic>);
      }
      _pendingRequests.remove(id);
    }
  }

  void _sendResponse(
    String clientId,
    String requestId,
    Map<String, dynamic> result,
  ) {
    final channel = _webClients[clientId];
    if (channel != null) {
      channel.sink.add(jsonEncode({
        'type': 'mcp_service_extension_response',
        'id': requestId,
        'result': result,
      }));
    }
  }

  void _sendErrorResponse(String clientId, String requestId, String error) {
    final channel = _webClients[clientId];
    if (channel != null) {
      channel.sink.add(jsonEncode({
        'type': 'mcp_service_extension_response',
        'id': requestId,
        'error': error,
      }));
    }
  }

  Future<void> stopWebBridge() async {
    for (final channel in _webClients.values) {
      await channel.sink.close();
    }
    _webClients.clear();
    await _webBridgeServer?.close(force: true);
    _webBridgeServer = null;
    log(
      LoggingLevel.info,
      'Web bridge server stopped',
      logger: 'WebBridge',
    );
  }

  bool get isWebBridgeRunning => _webBridgeServer != null;
}

