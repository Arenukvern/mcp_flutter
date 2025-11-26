import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

class WebBridgeClient {
  WebBridgeClient._();
  static final WebBridgeClient instance = WebBridgeClient._();

  dynamic _webSocket;
  final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};
  int _requestId = 0;
  bool _connected = false;

  Future<void> connect(String bridgeUrl) async {
    if (!kIsWeb) {
      throw UnsupportedError('WebBridgeClient only works on web platform');
    }
    throw UnsupportedError('WebBridgeClient requires web implementation');
  }

  Future<Map<String, dynamic>> callServiceExtension(
    String method,
    Map<String, String> parameters,
  ) async {
    throw UnsupportedError('Not implemented');
  }

  void disconnect() {
    _connected = false;
    _pendingRequests.clear();
  }

  bool get isConnected => _connected;
}

