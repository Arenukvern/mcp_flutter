import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/flutter_mcp_core.dart';
import 'package:test/test.dart';

void main() {
  test('seeds sticky endpoint with URI path token', () {
    final context = ConnectionContext(
      defaultHost: 'localhost',
      defaultPort: 8181,
      logger:
          (
            final LoggingLevel level,
            final String message, {
            final String logger = 'test',
          }) {},
      discoverPorts: () async => <int>[],
      initialStickyEndpointUri: 'ws://127.0.0.1:8181/pHDrCFCDBwg=/ws',
    );

    expect(
      context.stickyEndpoint?.display,
      equals('ws://127.0.0.1:8181/pHDrCFCDBwg=/ws'),
    );
  });

  test('discoverTargets emits URI-based target IDs', () async {
    final context = ConnectionContext(
      defaultHost: 'localhost',
      defaultPort: 8181,
      logger:
          (
            final LoggingLevel level,
            final String message, {
            final String logger = 'test',
          }) {},
      discoverPorts: () async => <int>[8181],
    );

    final targets = await context.discoverTargets();
    expect(targets, hasLength(1));
    expect(targets.first.targetId, equals('ws://localhost:8181/ws'));
    expect(targets.first.endpoint, equals('ws://localhost:8181/ws'));
    expect(targets.first.discoverySource, equals('port_scan'));
  });

  test(
    'discoverTargets prefers machine-discovered loopback endpoint',
    () async {
      final context = ConnectionContext(
        defaultHost: 'localhost',
        defaultPort: 8181,
        logger:
            (
              final LoggingLevel level,
              final String message, {
              final String logger = 'test',
            }) {},
        discoverPorts: () async => <int>[8181, 8182],
        discoverMachineTargets: () async => <FlutterMachineDiscoveryTarget>[
          FlutterMachineDiscoveryTarget(
            vmServiceWsUri: Uri.parse('ws://127.0.0.1:8181/abc/ws'),
            dtdUri: Uri.parse('ws://127.0.0.1:8181/dtd'),
          ),
        ],
      );

      final targets = await context.discoverTargets();
      expect(targets, hasLength(2));

      final machineTarget = targets.firstWhere(
        (final target) => target.port == 8181,
      );
      expect(machineTarget.targetId, equals('ws://127.0.0.1:8181/abc/ws'));
      expect(
        machineTarget.discoverySource,
        equals(CoreConnectionTarget.machineDiscoverySource),
      );
      expect(machineTarget.dtdUri, equals('ws://127.0.0.1:8181/dtd'));
    },
  );
}
