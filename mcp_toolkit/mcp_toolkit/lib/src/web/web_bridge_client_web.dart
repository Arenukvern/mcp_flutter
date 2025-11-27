import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

class WebBridgeClient {
  WebBridgeClient._();
  static final WebBridgeClient instance = WebBridgeClient._();

  html.WebSocket? _webSocket;
  final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};
  int _requestId = 0;
  bool _connected = false;
  final StreamController<Map<String, dynamic>> _messageController = 
      StreamController<Map<String, dynamic>>.broadcast();
  Completer<void>? _connectCompleter;

  html.WebSocket? get webSocket => _webSocket;
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  Future<void> connect(String bridgeUrl) async {
    if (!kIsWeb) {
      throw UnsupportedError('WebBridgeClient only works on web platform');
    }

    _connectCompleter = Completer<void>();

    try {
      _webSocket = html.WebSocket(bridgeUrl);
      _setupWebSocketListeners();
      
      await _connectCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
            _connectCompleter!.completeError(
              TimeoutException('WebSocket connection timeout'),
            );
            _connectCompleter = null;
          }
          throw TimeoutException('WebSocket connection timeout');
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[WebBridgeClient] Failed to connect: $e');
      }
      _connectCompleter = null;
      rethrow;
    }
  }

  void _setupWebSocketListeners() {
    _webSocket!.onOpen.listen((_) {
      _connected = true;
      if (kDebugMode) {
        debugPrint('[WebBridgeClient] Connected to bridge');
      }
      if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
        _connectCompleter!.complete();
        _connectCompleter = null;
      }
    });

    _webSocket!.onMessage.listen((event) {
      _handleMessage(event.data as String);
    });

    _webSocket!.onError.listen((error) {
      if (kDebugMode) {
        debugPrint('[WebBridgeClient] WebSocket error: $error');
      }
      _connected = false;
      if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
        _connectCompleter!.completeError(
          error ?? StateError('WebSocket connection failed'),
        );
        _connectCompleter = null;
      }
    });

    _webSocket!.onClose.listen((_) {
      _connected = false;
      if (kDebugMode) {
        debugPrint('[WebBridgeClient] Connection closed');
      }
      if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
        _connectCompleter!.completeError(
          StateError('WebSocket connection closed before opening'),
        );
        _connectCompleter = null;
      }
    });
  }

  void _handleMessage(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final type = json['type'] as String?;
      final id = json['id'] as String?;
      
      if (type == 'mcp_service_extension_response' && 
          id != null && 
          _pendingRequests.containsKey(id)) {
        _pendingRequests[id]!.complete(json);
        _pendingRequests.remove(id);
      } else if (type == 'mcp_service_extension') {
        _messageController.add(json);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[WebBridgeClient] Error handling message: $e');
      }
    }
  }

  Future<Map<String, dynamic>> callServiceExtension(
    String method,
    Map<String, String> parameters,
  ) async {
    if (!_connected || _webSocket == null) {
      throw StateError('Not connected to bridge');
    }

    final id = 'req_${_requestId++}';
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[id] = completer;

    final request = {
      'id': id,
      'type': 'mcp_service_extension',
      'method': method,
      'parameters': parameters,
    };

    _webSocket!.send(jsonEncode(request));

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pendingRequests.remove(id);
        throw TimeoutException('Service extension call timed out');
      },
    );
  }

  void disconnect() {
    if (_webSocket != null) {
      _webSocket!.close();
      _webSocket = null;
    }
    _connected = false;
    _pendingRequests.clear();
    _messageController.close();
    if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
      _connectCompleter!.completeError(
        StateError('Connection closed during connect'),
      );
      _connectCompleter = null;
    }
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_webSocket != null && _connected) {
      _webSocket!.send(jsonEncode(message));
    }
  }

  bool get isConnected => _connected;
}

