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

  bool get hasWebClients {
    final hasClients = _webClients.isNotEmpty;
    unawaited(
      Future.microtask(() {
        log(
          LoggingLevel.debug,
          'hasWebClients check: $hasClients (${_webClients.length} clients)',
          logger: 'WebBridge',
        );
      }),
    );
    return hasClients;
  }

  Future<void> startWebBridge({final int port = 8183}) async {
    try {
      _webBridgeServer = await HttpServer.bind('localhost', port);
      log(
        LoggingLevel.info,
        'Web bridge server started on port $port',
        logger: 'WebBridge',
      );

      _webBridgeServer!.listen((final request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          try {
            final ws = await WebSocketTransformer.upgrade(request);
            final channel = IOWebSocketChannel(ws);
            final clientId = _generateClientId();
            
            log(
              LoggingLevel.info,
              'WebSocket upgrade successful, adding client: $clientId',
              logger: 'WebBridge',
            );
            
            _webClients[clientId] = channel;

            log(
              LoggingLevel.info,
              'Web client connected: $clientId (total clients: ${_webClients.length})',
              logger: 'WebBridge',
            );

            channel.stream.listen(
              (final message) {
                log(
                  LoggingLevel.debug,
                  'Received message from $clientId',
                  logger: 'WebBridge',
                );
                _handleWebMessage(clientId, message);
              },
              onDone: () {
                log(
                  LoggingLevel.info,
                  'Web client stream done: $clientId',
                  logger: 'WebBridge',
                );
                if (_webClients.containsKey(clientId)) {
                  _webClients.remove(clientId);
                  log(
                    LoggingLevel.info,
                    'Web client disconnected: $clientId (remaining clients: ${_webClients.length})',
                    logger: 'WebBridge',
                  );
                }
              },
              onError: (final error) {
                log(
                  LoggingLevel.error,
                  'Web client error: $error (clientId: $clientId)',
                  logger: 'WebBridge',
                );
              },
              cancelOnError: false,
            );
          } catch (e, stack) {
            log(
              LoggingLevel.error,
              'Error upgrading WebSocket: $e',
              logger: 'WebBridge',
            );
            log(
              LoggingLevel.debug,
              () => 'Stack trace: $stack',
              logger: 'WebBridge',
            );
            request.response
              ..statusCode = HttpStatus.internalServerError
              ..close();
          }
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

  String _generateClientId() => 'web_client_${DateTime.now().millisecondsSinceEpoch}_${_webClients.length}';

  void _handleWebMessage(final String clientId, final message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'mcp_service_extension':
          unawaited(_handleServiceExtensionRequest(clientId, data));
        case 'mcp_service_extension_response':
          _handleServiceExtensionResponse(data);
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
    final String clientId,
    final Map<String, dynamic> data,
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
    final String method,
    final Map<String, String> parameters,
  ) async {
    log(
      LoggingLevel.debug,
      'callServiceExtensionViaWeb: method=$method, clients=${_webClients.length}',
      logger: 'WebBridge',
    );
    
    final channel = _webClients.values.firstOrNull;
    if (channel == null) {
      log(
        LoggingLevel.error,
        'No web client available (total: ${_webClients.length})',
        logger: 'WebBridge',
      );
      throw StateError('No web client connected');
    }

    final id = 'req_${_requestId++}';
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[id] = completer;

    log(
      LoggingLevel.debug,
      'Sending service extension request: id=$id, method=$method',
      logger: 'WebBridge',
    );

    try {
      channel.sink.add(jsonEncode({
        'type': 'mcp_service_extension',
        'id': id,
        'method': method,
        'parameters': parameters,
      }));
    } catch (e) {
      _pendingRequests.remove(id);
      log(
        LoggingLevel.error,
        'Error sending message to web client: $e',
        logger: 'WebBridge',
      );
      rethrow;
    }

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pendingRequests.remove(id);
        log(
          LoggingLevel.error,
          'Service extension call timed out: id=$id, method=$method',
          logger: 'WebBridge',
        );
        throw TimeoutException('Service extension call timed out');
      },
    );
  }

  void _handleServiceExtensionResponse(final Map<String, dynamic> data) {
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
    final String clientId,
    final String requestId,
    final Map<String, dynamic> result,
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

  void _sendErrorResponse(final String clientId, final String requestId, final String error) {
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

