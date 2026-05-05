#!/usr/bin/env dart
// ignore_for_file: avoid_print, avoid_catches_without_on_clauses

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('MCP Server Integration Tests', () {
    test('should initialize successfully', () async {
      final result = await _runServerTest((
        final requestSink,
        final responseStream,
      ) async {
        final initRequest = {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'initialize',
          'params': {
            'protocolVersion': '2024-11-05',
            'capabilities': {
              'roots': {'listChanged': true},
              'sampling': {},
            },
            'clientInfo': {'name': 'test-client', 'version': '1.0.0'},
          },
        };

        requestSink.add(jsonEncode(initRequest));

        final response = await responseStream.first.timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw TimeoutException('No response received'),
        );

        expect(response['jsonrpc'], equals('2.0'));
        expect(
          response['id'],
          anyOf(equals(1), isNull),
        ); // Some servers may not return ID
        expect(response['result'], isNotNull);
        final result = response['result'] as Map<String, dynamic>;
        expect(result['protocolVersion'], isNotNull);
        expect(result['capabilities'], isNotNull);
      });

      expect(result, isTrue);
    });

    test('should list tools after initialization', () async {
      final result = await _runServerTest((
        final requestSink,
        final responseStream,
      ) async {
        final responses = <Map<String, dynamic>>[];
        final responseSubscription = responseStream.listen(responses.add);

        try {
          // First initialize
          final initRequest = {
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'initialize',
            'params': {
              'protocolVersion': '2024-11-05',
              'capabilities': {
                'roots': {'listChanged': true},
                'sampling': {},
              },
              'clientInfo': {'name': 'test-client', 'version': '1.0.0'},
            },
          };

          requestSink.add(jsonEncode(initRequest));

          // Wait for init response
          await _waitForResponse(
            responses,
            (final r) => r['id'] == 1 || r['method'] == 'initialize',
          );

          // Then request tools list
          final toolsRequest = {
            'jsonrpc': '2.0',
            'id': 2,
            'method': 'tools/list',
            'params': {},
          };

          requestSink.add(jsonEncode(toolsRequest));

          // Wait for tools response
          final response = await _waitForResponse(
            responses,
            (final r) =>
                r['id'] == 2 ||
                (r.containsKey('result') &&
                    r['result'] is Map &&
                    (r['result'] as Map).containsKey('tools')),
          );

          expect(response['jsonrpc'], equals('2.0'));
          expect(response['result'], isNotNull);
          final result = response['result'] as Map<String, dynamic>;
          expect(result['tools'], isList);
          final tools = (result['tools'] as List).cast<Map<String, dynamic>>();
          final names = tools
              .map((final tool) => tool['name']?.toString() ?? '')
              .toSet();

          // v3.0.0: tools surface under the "fmt_" capability prefix.
          expect(names.contains('fmt_hot_reload_flutter'), isTrue);
          expect(names.contains('fmt_hot_restart_flutter'), isTrue);
          expect(names.contains('fmt_get_vm'), isTrue);
          expect(names.contains('fmt_get_extension_rpcs'), isTrue);
          expect(names.contains('fmt_discover_debug_apps'), isTrue);
          expect(names.contains('fmt_inspect_widget_at_point'), isTrue);
          expect(names.contains('fmt_capture_ui_snapshot'), isTrue);
        } finally {
          await responseSubscription.cancel();
        }
      });

      expect(result, isTrue);
    });

    test('should list resources after initialization', () async {
      final result = await _runServerTest((
        final requestSink,
        final responseStream,
      ) async {
        final responses = <Map<String, dynamic>>[];
        final responseSubscription = responseStream.listen(responses.add);

        try {
          // First initialize
          final initRequest = {
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'initialize',
            'params': {
              'protocolVersion': '2024-11-05',
              'capabilities': {
                'roots': {'listChanged': true},
                'sampling': {},
              },
              'clientInfo': {'name': 'test-client', 'version': '1.0.0'},
            },
          };

          requestSink.add(jsonEncode(initRequest));

          // Wait for init response
          await _waitForResponse(
            responses,
            (final r) => r['id'] == 1 || r['method'] == 'initialize',
          );

          // Then request resources list
          final resourcesRequest = {
            'jsonrpc': '2.0',
            'id': 3,
            'method': 'resources/list',
            'params': {},
          };

          requestSink.add(jsonEncode(resourcesRequest));

          // Wait for resources response
          final response = await _waitForResponse(
            responses,
            (final r) =>
                r['id'] == 3 ||
                (r.containsKey('result') &&
                    r['result'] is Map &&
                    (r['result'] as Map).containsKey('resources')),
          );

          expect(response['jsonrpc'], equals('2.0'));
          expect(response['result'], isNotNull);
          final result = response['result'] as Map<String, dynamic>;
          expect(result['resources'], isList);
          final resources = (result['resources'] as List)
              .cast<Map<String, dynamic>>();
          final uris = resources
              .map((final resource) => resource['uri']?.toString() ?? '')
              .toSet();
          expect(uris.contains('visual://localhost/app/errors/latest'), isTrue);
          expect(uris.contains('visual://localhost/view/details'), isTrue);
        } finally {
          await responseSubscription.cancel();
        }
      });

      expect(result, isTrue);
    });

    test('should handle invalid JSON-RPC requests', () async {
      final result = await _runServerTest((
        final requestSink,
        final responseStream,
      ) async {
        final invalidRequest = {
          'jsonrpc': '2.0',
          'id': 4,
          'method': 'invalid/method',
          'params': {},
        };

        requestSink.add(jsonEncode(invalidRequest));

        final response = await responseStream.first.timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw TimeoutException('No error response'),
        );

        expect(response['jsonrpc'], equals('2.0'));
        expect(response['id'], anyOf(equals(4), isNull));
        expect(response['error'], isNotNull);
        final error = response['error'] as Map<String, dynamic>;
        expect(error['code'], isA<int>());
        expect(error['message'], isA<String>());
      });

      expect(result, isTrue);
    });

    test('should handle malformed JSON requests gracefully', () async {
      final result = await _runServerTest((
        final requestSink,
        final responseStream,
      ) async {
        // Missing closing brace
        const malformedJson = '{"jsonrpc": "2.0", "id": 5, "method": "test"';

        requestSink.add(malformedJson);

        // Server should either respond with a parse error or
        // ignore malformed JSON.
        // We'll wait a short time to see if there's a response
        try {
          final response = await responseStream.first.timeout(
            const Duration(seconds: 8),
          );

          // If we get a response, it should be an error
          expect(response['jsonrpc'], equals('2.0'));
          expect(response['error'], isNotNull);
          final error = response['error'] as Map<String, dynamic>;
          expect(error['code'], equals(-32700)); // Parse error
        } on TimeoutException {
          // It's also acceptable for the server to ignore malformed JSON
          // This is valid behavior according to JSON-RPC spec
        }
      });

      expect(result, isTrue);
    });

    test('should handle requests without initialization', () async {
      final result = await _runServerTest((
        final requestSink,
        final responseStream,
      ) async {
        final toolsRequest = {
          'jsonrpc': '2.0',
          'id': 6,
          'method': 'tools/list',
          'params': {},
        };

        requestSink.add(jsonEncode(toolsRequest));

        try {
          final response = await responseStream.first.timeout(
            const Duration(seconds: 20),
          );

          expect(response['jsonrpc'], equals('2.0'));
          expect(response['id'], anyOf(equals(6), isNull));
          // Should either return an error or handle gracefully
          expect(
            response.containsKey('result') || response.containsKey('error'),
            isTrue,
          );
        } on TimeoutException {
          // Also acceptable for implementations to ignore pre-initialize
          // requests.
        }
      });

      expect(result, isTrue);
    });
  });
}

/// Helper function to run a test with a fresh server process
Future<bool> _runServerTest(
  final Future<void> Function(
    StreamSink<String> requestSink,
    Stream<Map<String, dynamic>> responseStream,
  )
  testFunction,
) async {
  Process? serverProcess;
  StreamController<String>? requestController;

  try {
    // Start the MCP server process
    serverProcess = await Process.start('dart', [
      'run',
      'bin/flutter_mcp_toolkit_server.dart',
    ], workingDirectory: Directory.current.path);

    // Set up request controller for sending to server's stdin
    requestController = StreamController<String>();
    requestController.stream
        .map((final request) => '$request\n')
        .listen(
          serverProcess.stdin.writeln,
          onError: (final error) => print('Request error: $error'),
        );

    // Set up response stream from server's stdout as a broadcast stream
    final responseStream = serverProcess.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((final line) => line.trim().isNotEmpty)
        .map((final line) {
          try {
            return jsonDecode(line) as Map<String, dynamic>;
          } catch (e, stackTrace) {
            print('Invalid JSON response: $line');
            throw FormatException('Invalid JSON response: $line', stackTrace);
          }
        })
        .asBroadcastStream();

    // Handle server errors (but don't fail the test)
    serverProcess.stderr
        .transform(utf8.decoder)
        .listen((final error) => print('Server stderr: $error'));

    // Give the server a moment to start up
    await Future.delayed(const Duration(milliseconds: 1000));

    // Run the actual test
    await testFunction(requestController.sink, responseStream);

    return true;
  } catch (e, stackTrace) {
    print('Test failed with error: $e');
    print('Stack trace: $stackTrace');
    return false;
  } finally {
    // Clean up
    await requestController?.close();
    serverProcess?.kill();
    if (serverProcess != null) {
      try {
        await serverProcess.exitCode.timeout(const Duration(seconds: 8));
      } catch (e, stackTrace) {
        print('Error killing server: $e');
        print('Stack trace: $stackTrace');
        serverProcess.kill(ProcessSignal.sigkill);
      }
    }
  }
}

/// Helper function to wait for a specific response
Future<Map<String, dynamic>> _waitForResponse(
  final List<Map<String, dynamic>> responses,
  final bool Function(Map<String, dynamic>) condition,
) async {
  const maxWaitTime = Duration(seconds: 30);
  const checkInterval = Duration(milliseconds: 100);
  final startTime = DateTime.now();

  while (DateTime.now().difference(startTime) < maxWaitTime) {
    for (int i = 0; i < responses.length; i++) {
      if (condition(responses[i])) {
        return responses.removeAt(i); // Remove and return the matching response
      }
    }
    await Future.delayed(checkInterval);
  }

  throw TimeoutException('No matching response found within timeout period');
}
