import 'package:flutter_mcp_toolkit_server/flutter_mcp_core.dart';
import 'package:test/test.dart';

void main() {
  test('seeds sticky endpoint with URI path token', () {
    final context = ConnectionContext(
      defaultHost: 'localhost',
      defaultPort: 8181,
      logger: (final level, final message, {final logger = 'test'}) {},
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
      logger: (final level, final message, {final logger = 'test'}) {},
      discoverPorts: () async => <int>[8181],
      probeFlutterTarget: (final endpoint, {required final timeout}) async =>
          true,
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
        logger: (final level, final message, {final logger = 'test'}) {},
        discoverPorts: () async => <int>[8181, 8182],
        discoverMachineTargets: () async => <FlutterMachineDiscoveryTarget>[
          FlutterMachineDiscoveryTarget(
            vmServiceWsUri: Uri.parse('ws://127.0.0.1:8181/abc/ws'),
            dtdUri: Uri.parse('ws://127.0.0.1:8181/dtd'),
          ),
        ],
      );

      final targets = await context.discoverTargets();
      expect(targets, hasLength(1));

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

  test('ensureConnectedWithPolicy enriches vm_not_connected details', () async {
    final context = ConnectionContext(
      defaultHost: 'localhost',
      defaultPort: 8181,
      logger: (final level, final message, {final logger = 'test'}) {},
      discoverPorts: () async => <int>[],
      discoverMachineTargets: () async => <FlutterMachineDiscoveryTarget>[],
      initialStickyEndpointUri: 'ws://127.0.0.1:8181/old-token/ws',
    );

    final ensure = await context.ensureConnectedWithPolicy(
      timeout: const Duration(milliseconds: 50),
    );
    expect(ensure.connected, isFalse);
    expect(ensure.code, equals('vm_not_connected'));

    final details = ensure.details! as Map<String, Object?>;
    expect(
      details['stickyEndpoint'],
      equals('ws://127.0.0.1:8181/old-token/ws'),
    );
    expect(details['suggestedActions'], isA<List>());
  });

  test('discoverTargets drops non-Flutter port-scan candidates', () async {
    final context = ConnectionContext(
      defaultHost: 'localhost',
      defaultPort: 8181,
      logger: (final level, final message, {final logger = 'test'}) {},
      discoverPorts: () async => <int>[8181, 9001, 9100],
      probeFlutterTarget: (final endpoint, {required final timeout}) async =>
          endpoint.port == 8181,
    );

    final targets = await context.discoverTargets();
    expect(targets, hasLength(1));
    expect(targets.first.port, equals(8181));
    expect(targets.first.discoverySource, equals('port_scan'));
    expect(
      context.lastDiscoveryDiagnostics['strategyUsed'],
      equals('port_scan_flutter_filtered'),
    );
    expect(context.lastDiscoveryDiagnostics['portCandidateCount'], equals(3));
    expect(context.lastDiscoveryDiagnostics['portFlutterCount'], equals(1));
    expect(
      context.lastDiscoveryDiagnostics['portDroppedNonFlutterCount'],
      equals(2),
    );
  });
}
