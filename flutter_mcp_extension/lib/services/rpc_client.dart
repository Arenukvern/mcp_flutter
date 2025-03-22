// ignore_for_file: avoid_catches_without_on_clauses

import 'dart:convert';

import 'package:flutter_mcp_extension/common_imports.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class RpcClient extends ChangeNotifier {
  WebSocketChannel? _channel;
  final Map<String, Function> _methods = {};
  var _connected = false;

  bool get connected => _connected;

  /// Returns a list of registered method names
  List<String> get registeredMethods => _methods.keys.toList();

  // Register RPC methods that can be called by the TypeScript server
  void registerMethod(final String methodName, final Function handler) {
    _methods[methodName] = handler;
    notifyListeners();
  }

  Future<void> connect({
    required final int port,
    required final String host,
    required final String path,
  }) async {
    await _startClient(port, host, path);
  }

  Future<void> _startClient(
    final int port,
    final String host,
    final String path,
  ) async {
    try {
      final wsUrl = 'ws://$host:$port/$path';
      print('Client connecting to $wsUrl');

      // Use the WebSocketChannel to connect to the server
      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Listen to the incoming messages
      channel.stream.listen(
        (final message) async {
          await _handleRpcCall(channel, message);
        },
        onDone: () {
          _channel = null;
          _connected = false;
          notifyListeners();
          print('Disconnected from WebSocket server');

          // Try to reconnect after a delay
          Future.delayed(const Duration(seconds: 2), () {
            if (!_connected) {
              print('Attempting to reconnect...');
              connect(port: port, host: host, path: path);
            }
          });
        },
        onError: (final error) {
          _channel = null;
          _connected = false;
          notifyListeners();
          print('Error with WebSocket connection: $error');

          // Try to reconnect after a delay
          Future.delayed(const Duration(seconds: 2), () {
            if (!_connected) {
              print('Attempting to reconnect after error...');
              connect(port: port, host: host, path: path);
            }
          });
        },
      );

      _channel = channel;
      _connected = true;
      notifyListeners();
      print('Connected to WebSocket server');
    } catch (e) {
      print('Failed to connect to WebSocket server: $e');
      // Try to reconnect after a delay
      Future.delayed(const Duration(seconds: 2), () {
        if (!_connected) {
          print('Attempting to reconnect after failure...');
          connect(port: port, host: host, path: path);
        }
      });
    }
  }

  Future<void> _handleRpcCall(
    final WebSocketChannel channel,
    final rawMessage,
  ) async {
    try {
      final Map<String, dynamic> message = json.decode(rawMessage.toString());
      final String id = message['id'];
      final String method = message['method'];
      final Map<String, dynamic> params = message['params'] ?? {};

      print('Received RPC call: $method (ID: $id)');

      if (_methods.containsKey(method)) {
        // Execute the method and get result
        await _executeRpcMethod(channel, id, method, params);
      } else {
        // Method not found
        _sendResponse(channel, id, null, {
          'code': -32601,
          'message': 'Method not found',
        });
      }
    } catch (e, stackTrace) {
      print('Error processing message: $e $stackTrace');
      // Parse error
      _sendResponse(channel, '0', null, {
        'code': -32700,
        'message': 'Parse error',
      });
    }
  }

  Future<void> _executeRpcMethod(
    final WebSocketChannel channel,
    final String id,
    final String method,
    final Map<String, dynamic> params,
  ) async {
    try {
      final handler = _methods[method]!;

      // Execute handler and get result
      final result = await Function.apply(handler, [params]);

      // Send response back to client
      _sendResponse(channel, id, result, null);
    } catch (e, stackTrace) {
      print('Error executing method $method: $e $stackTrace');
      _sendResponse(channel, id, null, {
        'code': -32603,
        'message': 'Internal error: $e',
      });
    }
  }

  void _sendResponse(
    final WebSocketChannel channel,
    final String id,
    final result,
    final error,
  ) {
    final response = {
      'jsonrpc': '2.0',
      'id': id,
      if (result != null) 'result': result,
      if (error != null) 'error': error,
    };

    // WebSocketChannel has a unified API for both web and non-web
    channel.sink.add(json.encode(response));
  }

  Future<void> disconnect() async {
    await _channel?.sink.close();
  }
}
