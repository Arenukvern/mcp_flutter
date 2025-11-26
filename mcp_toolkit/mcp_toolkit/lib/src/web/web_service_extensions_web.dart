import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../mcp_toolkit_binding_base.dart';
import 'web_bridge_client.dart';

mixin WebServiceExtensions on MCPToolkitBindingBase {
  WebBridgeClient? _webBridgeClient;
  bool _webMode = false;
  final Map<String, ServiceExtensionCallback> _webCallbacks = {};

  Future<void> initializeWebBridge({required String bridgeUrl}) async {
    if (!kIsWeb) {
      throw UnsupportedError(
        'Web bridge can only be initialized on web platform',
      );
    }

    _webMode = true;
    _webBridgeClient = WebBridgeClient.instance;
    await _webBridgeClient!.connect(bridgeUrl);
    _setupWebSocketListener();
  }

  @override
  void registerServiceExtension({
    required String name,
    required ServiceExtensionCallback callback,
  }) {
    if (_webMode && kIsWeb) {
      _registerWebServiceExtension(name: name, callback: callback);
    } else {
      super.registerServiceExtension(name: name, callback: callback);
    }
  }

  void _registerWebServiceExtension({
    required String name,
    required ServiceExtensionCallback callback,
  }) {
    final methodName = '${mcpServiceExtensionName}.$name';
    _webCallbacks[methodName] = callback;
    
    if (kDebugMode) {
      debugPrint('[WebServiceExtensions] Registered web service extension: $methodName');
    }
  }

  StreamSubscription<Map<String, dynamic>>? _messageSubscription;

  void _setupWebSocketListener() {
    if (!kIsWeb || _webBridgeClient == null) return;

    _messageSubscription?.cancel();
    _messageSubscription = _webBridgeClient!.messages.listen((json) {
      final type = json['type'] as String?;
      
      if (type == 'mcp_service_extension') {
        final method = json['method'] as String?;
        final id = json['id'] as String?;
        
        if (method != null && id != null) {
          final callback = _webCallbacks[method];
          if (callback != null) {
            _handleWebServiceExtensionCall(
              method,
              Map<String, String>.from(json['parameters'] as Map? ?? {}),
              callback,
              id,
            );
          }
        }
      }
    });
  }

  Future<void> _handleWebServiceExtensionCall(
    String methodName,
    Map<String, String> parameters,
    ServiceExtensionCallback callback,
    String requestId,
  ) async {
    if (_webBridgeClient == null || !_webBridgeClient!.isConnected) {
      if (kDebugMode) {
        debugPrint('[WebServiceExtensions] Cannot send response: WebSocket not connected');
      }
      return;
    }

    try {
      final result = await callback(parameters);
      final response = {
        'type': 'mcp_service_extension_response',
        'id': requestId,
        'result': {
          'type': '_extensionType',
          'method': methodName,
          ...result,
        },
      };
      _webBridgeClient!.sendMessage(response);
    } catch (exception, stack) {
      final errorResponse = {
        'type': 'mcp_service_extension_response',
        'id': requestId,
        'error': {
          'exception': exception.toString(),
          'stack': stack.toString(),
          'method': methodName,
        },
      };
      _webBridgeClient!.sendMessage(errorResponse);
    }
  }

  void disposeWebBridge() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _webBridgeClient?.disconnect();
    _webBridgeClient = null;
    _webMode = false;
    _webCallbacks.clear();
  }
}

