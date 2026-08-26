import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_toolkit_server/flutter_mcp_core.dart';
import 'package:test/test.dart';

/// Minimal VM service HTTP facade: enough for the discovery probe.
Future<HttpServer> _startFakeVmService({
  required final int pid,
  final int Function()? pidOverride,
  final String? label,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  const isolateId = 'isolates/1';
  unawaited(
    server.forEach((final request) async {
      final result = switch (request.uri.pathSegments.last) {
        'getVM' => {
          'pid': pidOverride?.call() ?? pid,
          'isolates': [
            {'type': '@Isolate', 'id': isolateId, 'name': 'main'},
          ],
        },
        'getIsolate' => {
          'extensionRPCs': [
            'ext.flutter.reassemble',
            if (label != null) 'ext.mcp.toolkit.app_identity',
          ],
        },
        'ext.mcp.toolkit.app_identity' => {'label': label},
        _ => <String, Object?>{},
      };
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'jsonrpc': '2.0', 'result': result}));
      await request.response.close();
    }),
  );
  return server;
}

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

  test('two endpoints of one app auto-attach to the pinned port', () async {
    final app = await _startFakeVmService(pid: 4242);
    final dds = await _startFakeVmService(pid: 4242);
    addTearDown(() => app.close(force: true));
    addTearDown(() => dds.close(force: true));

    final context = ConnectionContext(
      defaultHost: '127.0.0.1',
      defaultPort: 8181,
      logger: (final level, final message, {final logger = 'test'}) {},
      discoverPorts: () async => <int>[app.port, dds.port],
    );

    final targets = await context.discoverTargets();
    expect(targets, hasLength(2));
    expect(targets.every((final t) => t.vmPid == 4242), isTrue);
    expect(targets.first.toJson()['pid'], equals(4242));

    // The fake VM speaks HTTP only, so the attempt dies on the websocket
    // upgrade — reaching that point is the proof no choice was demanded.
    final lowerPort = app.port < dds.port ? app.port : dds.port;
    await expectLater(
      context.connect(),
      throwsA(
        predicate(
          (final e) =>
              e is! CoreConnectionException && '$e'.contains(':$lowerPort/'),
          'websocket attempt against port $lowerPort',
        ),
      ),
    );
  });

  test('two separate apps still require an explicit target', () async {
    final first = await _startFakeVmService(pid: 1);
    final second = await _startFakeVmService(pid: 2);
    addTearDown(() => first.close(force: true));
    addTearDown(() => second.close(force: true));

    final context = ConnectionContext(
      defaultHost: '127.0.0.1',
      defaultPort: 8181,
      logger: (final level, final message, {final logger = 'test'}) {},
      discoverPorts: () async => <int>[first.port, second.port],
    );

    await expectLater(
      context.connect(),
      throwsA(
        isA<CoreConnectionException>().having(
          (final e) => e.reason,
          'reason',
          CoreConnectionFailureReason.multipleTargets,
        ),
      ),
    );
  });

  test('a process that changed hands is not merged from cache', () async {
    var secondPid = 21;
    final first = await _startFakeVmService(pid: 21);
    final second = await _startFakeVmService(
      pid: 21,
      pidOverride: () => secondPid,
    );
    addTearDown(() => first.close(force: true));
    addTearDown(() => second.close(force: true));

    final context = ConnectionContext(
      defaultHost: '127.0.0.1',
      defaultPort: 8181,
      logger: (final level, final message, {final logger = 'test'}) {},
      discoverPorts: () async => <int>[first.port, second.port],
    );

    final targets = await context.discoverTargets();
    expect(
      targets.every((final target) => target.vmPid == 21),
      isTrue,
      reason: 'both endpoints answered as one process on the first pass',
    );

    // Another app takes the endpoint over while the probe cache still holds
    // the old process id.
    secondPid = 22;

    await expectLater(
      context.connect(),
      throwsA(
        isA<CoreConnectionException>().having(
          (final e) => e.reason,
          'reason',
          CoreConnectionFailureReason.multipleTargets,
        ),
      ),
      reason: 'a stale process id must not merge two apps into one target',
    );
  });

  test('discoverTargets labels a target that names itself', () async {
    final server = await _startFakeVmService(pid: 7, label: 'my_app · staging');
    addTearDown(() => server.close(force: true));

    final context = ConnectionContext(
      defaultHost: '127.0.0.1',
      defaultPort: 8181,
      logger: (final level, final message, {final logger = 'test'}) {},
      discoverPorts: () async => <int>[server.port],
    );

    final targets = await context.discoverTargets();
    expect(targets, hasLength(1), reason: 'one endpoint, one target');
    expect(
      targets.first.label,
      equals('my_app · staging'),
      reason: 'the label the app reports reaches the target',
    );
    expect(
      targets.first.toJson()['label'],
      equals('my_app · staging'),
      reason: 'callers read the label from the serialized target',
    );
  });

  test('discoverTargets keeps an unnamed target unlabelled', () async {
    final server = await _startFakeVmService(pid: 8);
    addTearDown(() => server.close(force: true));

    final context = ConnectionContext(
      defaultHost: '127.0.0.1',
      defaultPort: 8181,
      logger: (final level, final message, {final logger = 'test'}) {},
      discoverPorts: () async => <int>[server.port],
    );

    final targets = await context.discoverTargets();
    expect(targets, hasLength(1), reason: 'one endpoint, one target');
    expect(
      targets.first.label,
      isNull,
      reason: 'an app that never named itself has no label',
    );
    expect(
      targets.first.toJson().containsKey('label'),
      isFalse,
      reason: 'an absent label stays out of the serialized target',
    );
  });

  test('preferred label picks between running apps', () async {
    final agent = await _startFakeVmService(pid: 11, label: 'my_app · staging');
    final other = await _startFakeVmService(
      pid: 12,
      label: 'my_app · production',
    );
    addTearDown(() => agent.close(force: true));
    addTearDown(() => other.close(force: true));

    final context = ConnectionContext(
      defaultHost: '127.0.0.1',
      defaultPort: 8181,
      logger: (final level, final message, {final logger = 'test'}) {},
      discoverPorts: () async => <int>[agent.port, other.port],
      preferredTargetLabel: 'staging',
    );

    // The fake VM speaks HTTP only, so the attempt dies on the websocket
    // upgrade — reaching that point is the proof the preference resolved.
    await expectLater(
      context.connect(),
      throwsA(
        predicate(
          (final e) =>
              e is! CoreConnectionException && '$e'.contains(':${agent.port}/'),
          'websocket attempt against the preferred target',
        ),
      ),
      reason: 'the preference names one of two running apps',
    );
  });

  test('a preference does not override the target already chosen', () async {
    final chosen = await _startFakeVmService(
      pid: 15,
      label: 'my_app · staging',
    );
    final preferred = await _startFakeVmService(
      pid: 16,
      label: 'my_app · production',
    );
    addTearDown(() => chosen.close(force: true));
    addTearDown(() => preferred.close(force: true));

    final context = ConnectionContext(
      defaultHost: '127.0.0.1',
      defaultPort: 8181,
      logger: (final level, final message, {final logger = 'test'}) {},
      discoverPorts: () async => <int>[chosen.port, preferred.port],
      initialStickyEndpointUri: 'ws://127.0.0.1:${chosen.port}/ws',
      preferredTargetLabel: 'production',
    );

    // The fake VM speaks HTTP only, so the attempt dies on the websocket
    // upgrade — reaching that point is the proof the sticky target won.
    await expectLater(
      context.connect(),
      throwsA(
        predicate(
          (final e) =>
              e is! CoreConnectionException &&
              '$e'.contains(':${chosen.port}/'),
          'websocket attempt against the sticky target',
        ),
      ),
      reason: 'an app connected to explicitly outranks the preference',
    );
  });

  test('a preference that matches nothing hides nothing', () async {
    final first = await _startFakeVmService(pid: 13, label: 'my_app · staging');
    final second = await _startFakeVmService(
      pid: 14,
      label: 'other_app · staging',
    );
    addTearDown(() => first.close(force: true));
    addTearDown(() => second.close(force: true));

    final context = ConnectionContext(
      defaultHost: '127.0.0.1',
      defaultPort: 8181,
      logger: (final level, final message, {final logger = 'test'}) {},
      discoverPorts: () async => <int>[first.port, second.port],
      preferredTargetLabel: 'nobody',
    );

    await expectLater(
      context.connect(),
      throwsA(
        isA<CoreConnectionException>().having(
          (final e) => e.reason,
          'reason',
          CoreConnectionFailureReason.multipleTargets,
        ),
      ),
      reason: 'a stale preference must not pick an app on its own',
    );
  });
}
