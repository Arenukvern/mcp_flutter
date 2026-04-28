// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// ignore_for_file: unnecessary_async

import 'dart:async';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/mcp_toolkit_server/base_server.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/vm_connections/core_port_scanner.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/vm_connections/port_scanner.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

/// Minimal test server for PortScanner mixin
base class TestPortScannerServer extends BaseMCPToolkitServer {
  TestPortScannerServer()
    : super.fromStreamChannel(
        StreamChannel.withCloseGuarantee(
          const Stream.empty(),
          StreamController<String>().sink,
        ),
        configuration: (
          vmHost: 'localhost',
          vmPort: 8181,
          awaitDndConnection: false,
          resourcesSupported: false,
          imagesSupported: false,
          dumpsSupported: false,
          logLevel: 'error',
          environment: 'test',
          dynamicRegistrySupported: false,
          saveImagesToFiles: false,
          flutterProjectDir: null,
          flutterDevice: null,
          flutterDiscoveryTimeoutMs: 2500,
          useCapabilityKernel: false,
        ),
        implementation: Implementation(
          name: 'test-port-scanner',
          version: '1.0.0',
        ),
        instructions: 'Test server for port scanner',
      );
}

void main() {
  group('PortScanner', () {
    late TestPortScannerServer server;
    late PortScanner portScanner;

    setUp(() {
      server = TestPortScannerServer();
      portScanner = PortScanner(server: server);
    });

    test('scanForFlutterPorts returns valid port list', () async {
      final ports = await portScanner.scanForFlutterPorts();
      expect(ports, isA<List<int>>());
      expect(ports.every((final port) => port > 0 && port <= 65535), isTrue);
    });

    test('isPortAccessible returns false for invalid ports', () async {
      final isAccessible = await portScanner.isPortAccessible(99999);
      expect(isAccessible, isFalse);
    });

    test('isPortAccessible returns false for unreachable ports', () async {
      final isAccessible = await portScanner.isPortAccessible(65432);
      expect(isAccessible, isFalse);
    });

    test('commonFlutterPorts returns expected development ports', () {
      final ports = portScanner.commonFlutterPorts;
      expect(ports, equals([8080, 8181, 9000, 9001, 9999]));
    });

    test(
      'scanForFlutterPorts handles platform differences gracefully',
      () async {
        expect(() => portScanner.scanForFlutterPorts(), returnsNormally);
      },
    );

    test('scanForFlutterPorts handles process failures gracefully', () async {
      // Should not throw even if system commands fail
      final ports = await portScanner.scanForFlutterPorts();
      expect(ports, isA<List<int>>());
    });

    test('Unix parser accepts LISTEN endpoint and extracts local port', () {
      final port = CorePortScanner.parseListeningPortFromUnixLsofLine(
        'dart 92061 anton 7u IPv4 0xcebc4c66aeefbfd5 0t0 TCP 127.0.0.1:61879 (LISTEN)',
      );
      expect(port, equals(61879));
    });

    test('Unix parser ignores ESTABLISHED remote destinations', () {
      final port = CorePortScanner.parseListeningPortFromUnixLsofLine(
        'dart 62006 anton 10u IPv6 0xb117fb2b05557122 0t0 TCP 10.8.1.1:56203->34.36.0.14:443 (ESTABLISHED)',
      );
      expect(port, isNull);
    });

    test('Unix parser ignores malformed/non-listen lines', () {
      final port = CorePortScanner.parseListeningPortFromUnixLsofLine(
        'dart malformed line with no tcp endpoint',
      );
      expect(port, isNull);
    });
  });
}
