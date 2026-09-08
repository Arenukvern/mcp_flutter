// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// Verifies honest reload/restart reporting in [ConnectionContext]:
//
// - when the flutter tool's custom VM services are NOT discovered (late
//   attach / external-runner scenario), the fallback must report
//   `changed: false` with an actionable reason instead of dressing a no-op
//   as success;
// - when the custom services ARE discovered (early connect), the real path
//   keeps working and reports `changed: true`;
// - a wired [RunnerControl] takes precedence and carries delegation metadata,
//   including the relaunch-fallback connection retry.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart'
    show CoreConnectionMode;
import 'package:flutter_mcp_toolkit_server/src/shared_core/runner_control/runner_control.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/types/types.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/vm_connections/connection_context.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/vm_connections/flutter_tool_machine_discovery.dart';
import 'package:test/test.dart';

/// Scriptable fake VM service speaking JSON-RPC 2.0 over a websocket — enough
/// for [ConnectionContext] to attach (getVM / streamListen) and to observe
/// which reload-capable methods the toolkit actually calls.
final class _FakeVmServiceServer {
  _FakeVmServiceServer();

  HttpServer? _server;
  final List<WebSocket> _sockets = <WebSocket>[];
  final List<String> methodsCalled = <String>[];

  /// ServiceRegistered event pushed right after the client listens on this
  /// stream, keyed by stream id (for example `Service`).
  final Map<String, Map<String, Object?>> eventAfterListen = {};

  /// Reply payload for a specific method; defaults by method kind.
  final Map<String, Map<String, Object?>> replies = {};

  int get port => _server!.port;

  /// The VM service URI to connect to (auth-token path like a real
  /// `ws://127.0.0.1:<port>/<token>/ws` endpoint).
  String get wsUri => 'ws://127.0.0.1:$port/PhDrCFCDBwg=/ws';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(
      _server!.forEach((final request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        _sockets.add(socket);
        unawaited(_handleSocket(socket));
      }),
    );
  }

  Future<void> _handleSocket(final WebSocket socket) async {
    await for (final message in socket) {
      if (message is! String) continue;
      Object? decoded;
      try {
        decoded = jsonDecode(message);
      } on FormatException {
        continue;
      }
      if (decoded is! Map || decoded['id'] == null) continue;
      final id = decoded['id'];
      final method = decoded['method']?.toString() ?? '';
      final params = decoded['params'];
      methodsCalled.add(method);

      // Unknown protocol chatter (the DTD handshake lands here first and is
      // rejected by the toolkit anyway).
      if (!replies.containsKey(method) && !_isVmMethod(method)) {
        _send(socket, id, error: <String, Object?>{
          'code': -32601,
          'message': 'method not found: $method',
        });
        continue;
      }

      if (method == 'streamListen') {
        _send(socket, id, result: <String, Object?>{'type': 'Success'});
        final streamId =
            (params is Map ? params['streamId'] : null)?.toString() ?? '';
        final event = eventAfterListen[streamId];
        if (event != null) {
          // Give the client a beat to finish wiring the event listener.
          await Future<void>.delayed(const Duration(milliseconds: 10));
          socket.add(
            jsonEncode(<String, Object?>{
              'jsonrpc': '2.0',
              'method': 'streamNotify',
              'params': <String, Object?>{
                'streamId': streamId,
                'event': <String, Object?>{
                  'type': 'Event',
                  'kind': 'ServiceRegistered',
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                  ...event,
                },
              },
            }),
          );
        }
        continue;
      }

      final reply = replies[method];
      if (reply != null) {
        _send(socket, id, result: reply);
        continue;
      }

      _send(
        socket,
        id,
        result: switch (method) {
          'getVM' => <String, Object?>{
            'type': 'VM',
            'name': 'fake-vm',
            'pid': 4242,
            'isolates': <Object?>[
              <String, Object?>{
                'type': '@Isolate',
                'id': 'isolates/1',
                'name': 'main',
              },
            ],
          },
          _ => <String, Object?>{'type': 'Success', 'success': true},
        },
      );
    }
  }

  bool _isVmMethod(final String method) =>
      method == 'getVM' ||
      method == 'streamListen' ||
      method == 'streamCancel' ||
      method == 'reloadSources' ||
      method == 'hotRestart' ||
      method.startsWith('s0.');

  void _send(
    final WebSocket socket,
    final Object? id, {
    final Map<String, Object?>? result,
    final Map<String, Object?>? error,
  }) {
    socket.add(
      jsonEncode(<String, Object?>{
        'jsonrpc': '2.0',
        'id': id,
        'result': ?result,
        'error': ?error,
      }),
    );
  }

  Future<void> stop() async {
    for (final socket in _sockets) {
      await socket.close();
    }
    _sockets.clear();
    await _server?.close(force: true);
    _server = null;
  }
}

final class _StubRunnerControl implements RunnerControl {
  _StubRunnerControl({this.uri, this.reloadOutcome, this.restartOutcome});

  bool alive = true;
  String? uri;
  RunnerControlOutcome? reloadOutcome;
  RunnerControlOutcome? restartOutcome;
  int isAliveCalls = 0;

  @override
  String get runnerName => 'stub-runner';

  @override
  Future<bool> isAlive() async {
    isAliveCalls++;
    return alive;
  }

  @override
  Future<RunnerControlOutcome> reload() async =>
      reloadOutcome ??
      const RunnerControlOutcome(ok: true, raw: <String, Object?>{
        'reloaded': true,
      });

  @override
  Future<RunnerControlOutcome> restart() async =>
      restartOutcome ??
      const RunnerControlOutcome(ok: true, raw: <String, Object?>{
        'restarted': true,
      });

  @override
  Future<String?> liveVmServiceUri() async => uri;
}

ConnectionContext _makeContext({
  required final CoreLogger logger,
  required final List<int> ports,
  final RunnerControl? runnerControl,
  final String? stickyEndpointUri,
  final CoreFlutterTargetProbe? probeFlutterTarget,
  final Future<List<FlutterMachineDiscoveryTarget>> Function()?
  discoverMachineTargets,
}) => ConnectionContext(
  defaultHost: '127.0.0.1',
  defaultPort: 8181,
  logger: logger,
  discoverPorts: () async => ports,
  runnerControl: runnerControl,
  initialStickyEndpointUri: stickyEndpointUri,
  probeFlutterTarget: probeFlutterTarget,
  discoverMachineTargets: discoverMachineTargets,
);

Future<Map<String, dynamic>?> _reload(final _FakeVmServiceServer vm) async {
  final context = _makeContext(
    logger: (final _, final _, {final logger = 'test'}) {},
    ports: const [],
  );
  await context.connect(
    mode: CoreConnectionMode.uri,
    uri: vm.wsUri,
    timeout: const Duration(seconds: 5),
  );
  return context.hotReload();
}

void main() {
  group('honest fallback reporting (no compile-capable service discovered)', () {
    test('reload reports changed:false with an actionable reason', () async {
      final vm = _FakeVmServiceServer();
      await vm.start();
      try {
        final result = await _reload(vm);
        expect(result, isNotNull);
        expect(result!['report'], equals(<String, Object?>{
          'type': 'ReloadReport',
          'success': true,
        }));
        expect(result['changed'], isFalse);
        expect(result['reason'], contains('no compile-capable session'));
        expect(result['reason'], contains('RunnerControl'));
        // The raw no-op VM call must not fire anymore.
        expect(vm.methodsCalled, isNot(contains('reloadSources')));
      } finally {
        await vm.stop();
      }
    });

    test('restart method-not-found path reports changed:false', () async {
      final vm = _FakeVmServiceServer();
      await vm.start();
      try {
        final context = _makeContext(
          logger: (final _, final _, {final logger = 'test'}) {},
          ports: const [],
        );
        await context.connect(
          mode: CoreConnectionMode.uri,
          uri: vm.wsUri,
          timeout: const Duration(seconds: 5),
        );
        final result = await context.hotRestart();

        expect(result!['report'], equals(<String, Object?>{
          'type': 'Success',
          'success': false,
        }));
        expect(result['changed'], isFalse);
        expect(result['reason'], contains('no compile-capable session'));
        // The raw `hotRestart` VM method never existed — must not be called.
        expect(vm.methodsCalled, isNot(contains('hotRestart')));
      } finally {
        await vm.stop();
      }
    });
  });

  group('real reload path (custom service discovered, early connect)', () {
    test('reload through discovered s0.reloadSources reports changed:true', () async {
      final vm = _FakeVmServiceServer()
        ..eventAfterListen['Service'] = <String, Object?>{
          'service': 'reloadSources',
          'method': 's0.reloadSources',
        }
        ..replies['s0.reloadSources'] = <String, Object?>{
          'type': 'Success',
        };
      await vm.start();
      try {
        final result = await _reload(vm);
        expect(result!['changed'], isTrue);
        expect(result['report'], equals(<String, Object?>{
          'type': 'ReloadReport',
          'success': true,
        }));
        expect(vm.methodsCalled, contains('s0.reloadSources'));
        expect(vm.methodsCalled, isNot(contains('reloadSources')));
      } finally {
        await vm.stop();
      }
    });

    test(
      'restart through discovered s0.hotRestart reports changed:true',
      () async {
        final vm = _FakeVmServiceServer()
          ..eventAfterListen['Service'] = <String, Object?>{
            'service': 'hotRestart',
            'method': 's0.hotRestart',
          };
        await vm.start();
        try {
          final context = _makeContext(
            logger: (final _, final _, {final logger = 'test'}) {},
            ports: const [],
          );
          await context.connect(
            mode: CoreConnectionMode.uri,
            uri: vm.wsUri,
            timeout: const Duration(seconds: 5),
          );
          final result = await context.hotRestart();
          final report =
              result!['report'] as Map<String, Object?>? ?? const {};

          expect(result['changed'], isTrue);
          expect(report['success'], isTrue);
          expect(vm.methodsCalled, contains('s0.hotRestart'));
          expect(vm.methodsCalled, isNot(contains('hotRestart')));
        } finally {
          await vm.stop();
        }
      },
    );
  });

  group('delegation via RunnerControl', () {
    test('alive runner takes precedence, no VM connection required', () async {
      final control = _StubRunnerControl();
      final context = _makeContext(
        logger: (final _, final _, {final logger = 'test'}) {},
        ports: const [],
        runnerControl: control,
      );

      final result = await context.hotReload();
      final report = result!['report'] as Map<String, Object?>? ?? const {};

      expect(result['changed'], isTrue);
      expect(result['delegated'], isTrue);
      expect(result['runner'], equals('stub-runner'));
      expect(report['success'], isTrue);
      expect(context.vmService, isNull);
      expect(control.isAliveCalls, greaterThan(0));
    });

    test('delegated daemon failure surfaces the actionable error', () async {
      final control = _StubRunnerControl(
        reloadOutcome: const RunnerControlOutcome(
          ok: false,
          error: 'Fix the compile error in lib/main.dart first.',
        ),
      );
      final context = _makeContext(
        logger: (final _, final _, {final logger = 'test'}) {},
        ports: const [],
        runnerControl: control,
      );

      final result = await context.hotReload();

      expect(result!['error'], contains('lib/main.dart'));
      expect(result['delegated'], isTrue);
    });

    test(
      'restart with relaunch fallback retries the CONNECTION, not the restart',
      () async {
        final vm1 = _FakeVmServiceServer();
        final vm2 = _FakeVmServiceServer();
        await vm1.start();
        await vm2.start();
        try {
          final control = _StubRunnerControl(
            restartOutcome: RunnerControlOutcome(
              ok: true,
              fallback: true,
              sessionRelaunched: true,
              vmServiceUri: vm2.wsUri,
              raw: const <String, Object?>{'fallback': true},
            ),
          );
          final context = _makeContext(
            logger: (final _, final _, {final logger = 'test'}) {},
            ports: const [],
            runnerControl: control,
          );
          await context.connect(
            mode: CoreConnectionMode.uri,
            uri: vm1.wsUri,
            timeout: const Duration(seconds: 5),
          );
          final oldEndpoint = context.activeEndpoint?.display;

          final result = await context.hotRestart();

          expect(result!['changed'], isTrue);
          expect(result['runnerFallback'], isTrue);
          expect(result['reattachedTo'], equals(vm2.wsUri));
          expect(context.activeEndpoint?.display, isNot(equals(oldEndpoint)));
          expect(context.activeEndpoint?.display, equals(vm2.wsUri));
          expect(context.vmService, isNotNull);
        } finally {
          await vm1.stop();
          await vm2.stop();
        }
      },
    );
  });

  group('connection fallback + attach suppression', () {
    test(
      'auto-connect falls back to the owning session endpoint when discovery '
      'finds nothing',
      () async {
        final vm = _FakeVmServiceServer();
        await vm.start();
        try {
          final control = _StubRunnerControl(uri: vm.wsUri);
          var machineQueries = 0;
          final context = _makeContext(
            logger: (final _, final _, {final logger = 'test'}) {},
            ports: const [],
            runnerControl: control,
            discoverMachineTargets: () async {
              machineQueries++;
              return const <FlutterMachineDiscoveryTarget>[];
            },
          );

          final result = await context.connect();

          expect(result['connected'], isTrue);
          expect(result['decision'], contains('owning dev session'));
          expect(result['runner'], equals('stub-runner'));
          expect(context.vmService, isNotNull);
          // Machine discovery must never spawn a second attach while the
          // owning session is alive: the provider is not even queried.
          expect(machineQueries, equals(0));
        } finally {
          await vm.stop();
        }
      },
    );

    test(
      'auto-connect prefers the owning session endpoint over other '
      'discoverable targets',
      () async {
        final vm = _FakeVmServiceServer();
        await vm.start();
        try {
          final control = _StubRunnerControl(uri: vm.wsUri);
          final context = _makeContext(
            logger: (final _, final _, {final logger = 'test'}) {},
            ports: const [8181, 8182],
            runnerControl: control,
            discoverMachineTargets: () async =>
                const <FlutterMachineDiscoveryTarget>[],
          );

          final result = await context.connect();

          expect(result['connected'], isTrue);
          expect(result['decision'], contains('owning dev session'));
          expect(context.activeEndpoint?.display, equals(vm.wsUri));
        } finally {
          await vm.stop();
        }
      },
    );

    test(
      'machine discovery runs again once the owning session is gone',
      () async {
        var machineQueries = 0;
        final control = _StubRunnerControl()..alive = false;
        final context = _makeContext(
          logger: (final _, final _, {final logger = 'test'}) {},
          ports: const [],
          runnerControl: control,
          discoverMachineTargets: () async {
            machineQueries++;
            return const <FlutterMachineDiscoveryTarget>[];
          },
        );

        await expectLater(
          context.connect(),
          throwsA(
            isA<CoreConnectionException>().having(
              (final e) => e.reason,
              'reason',
              CoreConnectionFailureReason.noTargets,
            ),
          ),
        );
        expect(machineQueries, equals(1));
      },
    );
  });

  group('precedence: active connection > runner session > sticky > discovery', () {
    test(
      'a live runner endpoint wins over a sticky endpoint in auto mode',
      () async {
        final runnerVm = _FakeVmServiceServer();
        final stickyVm = _FakeVmServiceServer();
        await runnerVm.start();
        await stickyVm.start();
        try {
          final control = _StubRunnerControl(uri: runnerVm.wsUri);
          final context = _makeContext(
            logger: (final _, final _, {final logger = 'test'}) {},
            ports: [stickyVm.port],
            runnerControl: control,
            stickyEndpointUri: stickyVm.wsUri,
            probeFlutterTarget: (_, {required final timeout}) async => true,
          );

          final result = await context.connect();

          expect(result['connected'], isTrue);
          expect(result['decision'], contains('owning dev session'));
          expect(context.activeEndpoint?.display, equals(runnerVm.wsUri));
        } finally {
          await runnerVm.stop();
          await stickyVm.stop();
        }
      },
    );

    test(
      'without a live runner, the sticky endpoint is reused from discovery',
      () async {
        final vm = _FakeVmServiceServer();
        await vm.start();
        try {
          final control = _StubRunnerControl()..alive = false;
          final context = _makeContext(
            logger: (final _, final _, {final logger = 'test'}) {},
            ports: [vm.port],
            runnerControl: control,
            stickyEndpointUri: vm.wsUri,
            probeFlutterTarget: (_, {required final timeout}) async => true,
          );

          final result = await context.connect();

          expect(result['connected'], isTrue);
          expect(
            result['decision'],
            contains('Reused sticky target discovered in current scan'),
          );
          expect(context.activeEndpoint?.display, equals(vm.wsUri));
        } finally {
          await vm.stop();
        }
      },
    );
  });
}
