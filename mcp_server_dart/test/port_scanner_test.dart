// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:async';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/base_server.dart';
import 'package:flutter_inspector_mcp_server/src/mixins/port_scanner.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

/// Minimal test server for PortScanner mixin
base class TestPortScannerServer extends BaseMCPToolkitServer with PortScanner {
  TestPortScannerServer()
    : super.fromStreamChannel(
        StreamChannel.withCloseGuarantee(
          const Stream.empty(),
          StreamController<String>().sink,
        ),
        configuration: (
          vmHost: 'localhost',
          vmPort: 8181,
          resourcesSupported: false,
          imagesSupported: false,
          dumpsSupported: false,
          logLevel: 'error',
          environment: 'test',
          dynamicRegistrySupported: false,
        ),
        implementation: ServerImplementation(
          name: 'test-port-scanner',
          version: '1.0.0',
        ),
        instructions: 'Test server for port scanner',
      );
}

void main() {
  group('PortScanner', () {
    late TestPortScannerServer server;

    setUp(() {
      server = TestPortScannerServer();
    });

    test('scanForFlutterPorts returns valid port list', () async {
      final ports = await server.scanForFlutterPorts();
      expect(ports, isA<List<int>>());
      expect(ports.every((final port) => port > 0 && port <= 65535), isTrue);
    });

    test('isPortAccessible returns false for invalid ports', () async {
      final isAccessible = await server.isPortAccessible(99999);
      expect(isAccessible, isFalse);
    });

    test('isPortAccessible returns false for unreachable ports', () async {
      final isAccessible = await server.isPortAccessible(65432);
      expect(isAccessible, isFalse);
    });

    test('commonFlutterPorts returns expected development ports', () {
      final ports = server.commonFlutterPorts;
      expect(ports, equals([8080, 8181, 9000, 9001, 9999]));
    });

    test(
      'scanForFlutterPorts handles platform differences gracefully',
      () async {
        expect(() => server.scanForFlutterPorts(), returnsNormally);
      },
    );

    test('scanForFlutterPorts handles process failures gracefully', () async {
      // Should not throw even if system commands fail
      final ports = await server.scanForFlutterPorts();
      expect(ports, isA<List<int>>());
    });
  });
}
