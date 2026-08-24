// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// ignore_for_file: unnecessary_async

import 'dart:async';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/base_server.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/vm_connections/core_port_scanner.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/vm_connections/port_scanner.dart';
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
          scanPorts: const <int>[],
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

  group('CorePortScanner scan ports', () {
    void noopLogger(
      final LoggingLevel level,
      final String message, {
      final String logger = 'core',
    }) {}

    test('spec parser expands ranges and lists into sorted unique ports', () {
      expect(
        CorePortScanner.parseScanPortsSpec(' 9100, 8765-8767 ,9100'),
        equals([8765, 8766, 8767, 9100]),
      );
    });

    test('spec parser drops unusable entries', () {
      expect(CorePortScanner.parseScanPortsSpec(null), isEmpty);
      expect(CorePortScanner.parseScanPortsSpec(''), isEmpty);
      expect(CorePortScanner.parseScanPortsSpec('abc'), isEmpty);
      expect(CorePortScanner.parseScanPortsSpec('0'), isEmpty);
      expect(CorePortScanner.parseScanPortsSpec('70000'), isEmpty);
      expect(CorePortScanner.parseScanPortsSpec('8767-8765'), isEmpty);
      expect(CorePortScanner.parseScanPortsSpec('abc,8765'), equals([8765]));
    });

    test('spec parser caps how many ports a value expands to', () {
      const start = 9000;
      const limit = CorePortScanner.maxScanPortsCount;
      expect(
        CorePortScanner.parseScanPortsSpec('$start-${start + limit}'),
        isEmpty,
      );
      expect(
        CorePortScanner.parseScanPortsSpec('$start-${start + limit - 1}'),
        hasLength(limit),
      );
    });

    test('spec parser drops entries that would exceed the cap', () {
      const limit = CorePortScanner.maxScanPortsCount;
      final ports = CorePortScanner.parseScanPortsSpec(
        '1000-${1000 + limit - 2},2000-2100,8765',
      );

      expect(ports, hasLength(limit));
      expect(ports.last, 8765);
      expect(ports, isNot(contains(2000)));
    });

    test(
      'configured ports are probed regardless of the process scan',
      () async {
        final listener = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        addTearDown(listener.close);

        final scanner = CorePortScanner(
          logger: noopLogger,
          scanPorts: [listener.port],
        );

        expect(await scanner.probeKnownPorts(), contains(listener.port));
        expect(await scanner.scanForFlutterPorts(), contains(listener.port));
      },
    );

    test('configured ports nobody listens on stay out of the result', () async {
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final closedPort = probe.port;
      await probe.close();

      final scanner = CorePortScanner(
        logger: noopLogger,
        scanPorts: [closedPort],
      );

      expect(await scanner.scanForFlutterPorts(), isNot(contains(closedPort)));
    });
  });
}
