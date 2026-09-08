// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// Exercises [ExternalSessionRunnerControl] against a fake external-runner TCP
// control server speaking the frozen JSON-lines dev-session contract (spec
// v2; see docs/guides/dev-session-delegation-roadmap.mdx, "The dev session
// contract (spec v2)").

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_toolkit_server/src/shared_core/runner_control/external_session.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/runner_control/runner_control.dart';
import 'package:test/test.dart';

/// Request observed by the fake control server.
final class _ObservedRequest {
  _ObservedRequest({required this.id, required this.method});

  final int id;
  final String method;
}

/// Scriptable fake of an external runner's control channel.
final class _FakeControlServer {
  _FakeControlServer();

  final List<_ObservedRequest> requests = <_ObservedRequest>[];
  /// Response for the next request of [method]: the full JSON-lines reply
  /// payload (including the contract's `ok`/`result`/`error` keys). The `id`
  /// field is injected by the server.
  final Map<String, Map<String, Object?> Function()> responses = {};

  /// When set, the socket is destroyed without responding for this method
  /// (simulates the relaunch-fallback EOF from the frozen contract).
  final Set<String> closeWithoutResponse = {};

  /// Invoked right before the socket is destroyed for a
  /// `closeWithoutResponse` method — lets a test mutate the world (for
  /// example remove the runner's discovery file) at the exact moment the
  /// connection drops.
  void Function(String method)? onConnectionDrop;

  /// When set, the server never responds to this method (timeout test).
  final Set<String> neverRespond = {};

  int get port => _socketServer!.port;

  Future<void> start() async {
    // The control channel is a raw TCP JSON-lines server, not HTTP.
    _socketServer = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _socketServer!.listen(_handleSocket);
  }

  ServerSocket? _socketServer;

  void _handleSocket(final Socket socket) {
    final lines = socket
        .map(utf8.decode)
        .transform(const LineSplitter());
    lines.listen(
      (final line) async {
        final trimmed = line.trim();
        if (trimmed.isEmpty) return;
        final decoded = jsonDecode(trimmed) as Map;
        final id = decoded['id'] as int;
        final method = decoded['method'] as String;
        requests.add(_ObservedRequest(id: id, method: method));

        if (neverRespond.contains(method)) return;
        if (closeWithoutResponse.contains(method)) {
          await socket.flush();
          onConnectionDrop?.call(method);
          socket.destroy();
          return;
        }

        final responder = responses[method];
        final reply = <String, Object?>{'id': id};
        if (responder == null) {
          reply['ok'] = false;
        } else {
          reply.addAll(responder());
        }
        socket.write('${jsonEncode(reply)}\n');
        await socket.flush();
      },
      onError: (final Object _) {},
      cancelOnError: true,
    );
  }

  Future<void> stop() async {
    await _socketServer?.close();
    _socketServer = null;
  }
}

ExternalSessionRunnerControl _makeControl(
  final String sessionFile, {
  final Duration reloadTimeout = const Duration(seconds: 5),
  final Duration restartTimeout = const Duration(seconds: 5),
}) => ExternalSessionRunnerControl(
  sessionFile: sessionFile,
  reloadTimeout: reloadTimeout,
  restartTimeout: restartTimeout,
);

void _writeSessionFile(
  final String path, {
  final int schema = 1,
  final String? runner = 'example-dev',
  final String vmServiceUri = 'ws://127.0.0.1:65250/abc123/ws',
  final int controlPort = 59871,
  final String deviceId = 'emulator-5554',
  final int pid = 12345,
  final String startedAt = '2026-09-08T00:00:00.000Z',
  final Map<String, Object?> extra = const {},
}) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    jsonEncode(<String, Object?>{
      'schema': schema,
      'runner': ?runner,
      'vm_service_uri': vmServiceUri,
      'control_port': controlPort,
      'device_id': deviceId,
      'pid': pid,
      'started_at': startedAt,
      ...extra,
    }),
  );
}

void main() {
  late Directory projectDir;

  setUp(() {
    projectDir = Directory.systemTemp.createTempSync('external_session_test');
  });

  tearDown(() {
    projectDir.deleteSync(recursive: true);
  });

  group('discovery file location', () {
    test('default path is <project>/.flutter_mcp/runner-session.json', () {
      expect(
        ExternalSessionRunnerControl.defaultSessionPathFor(projectDir.path),
        endsWith('.flutter_mcp/runner-session.json'),
      );
    });

    test('reads the file at the exact --runner-session-file path', () async {
      final customPath = '${projectDir.path}/somewhere/else/session.json';
      _writeSessionFile(customPath);
      final control = _makeControl(customPath);
      expect(
        await control.liveVmServiceUri(),
        equals('ws://127.0.0.1:65250/abc123/ws'),
      );
      expect(control.sessionFilePath, equals(customPath));
    });
  });

  group('discovery file parsing', () {
    test('no discovery file → not alive, no vm uri', () async {
      final control = _makeControl(
        ExternalSessionRunnerControl.defaultSessionPathFor(projectDir.path),
      );
      expect(await control.isAlive(), isFalse);
      expect(await control.liveVmServiceUri(), isNull);
    });

    test('reads vm_service_uri from a valid discovery file', () async {
      final path = ExternalSessionRunnerControl.defaultSessionPathFor(
        projectDir.path,
      );
      _writeSessionFile(path);
      final control = _makeControl(path);
      expect(
        await control.liveVmServiceUri(),
        equals('ws://127.0.0.1:65250/abc123/ws'),
      );
    });

    test('rejects unknown schema values', () async {
      final path = ExternalSessionRunnerControl.defaultSessionPathFor(
        projectDir.path,
      );
      _writeSessionFile(path, schema: 2);
      final control = _makeControl(path);
      await expectLater(
        control.reload(),
        throwsA(
          isA<RunnerControlException>().having(
            (final e) => '$e',
            'message',
            contains('Unsupported'),
          ),
        ),
      );
    });

    test('rejects corrupt JSON with actionable error', () async {
      final path = ExternalSessionRunnerControl.defaultSessionPathFor(
        projectDir.path,
      );
      File(path).parent.createSync(recursive: true);
      File(path).writeAsStringSync('{not json');
      final control = _makeControl(path);
      await expectLater(
        control.reload(),
        throwsA(
          isA<RunnerControlException>().having(
            (final e) => '$e',
            'message',
            contains('invalid JSON'),
          ),
        ),
      );
    });

    test('rejects missing required fields', () async {
      final path = ExternalSessionRunnerControl.defaultSessionPathFor(
        projectDir.path,
      );
      _writeSessionFile(path);
      File(path).writeAsStringSync(
        jsonEncode({'schema': 1, 'vm_service_uri': 'ws://x/ws'}),
      );
      final control = _makeControl(path);
      await expectLater(
        control.reload(),
        throwsA(
          isA<RunnerControlException>().having(
            (final e) => '$e',
            'message',
            contains('control_port'),
          ),
        ),
      );
    });

    test('tolerates unknown extra fields from future runners', () async {
      final path = ExternalSessionRunnerControl.defaultSessionPathFor(
        projectDir.path,
      );
      _writeSessionFile(path, extra: {'future_field': 42});
      final control = _makeControl(path);
      expect(await control.isAlive(), isFalse); // control port not listening
      expect(
        await control.liveVmServiceUri(),
        equals('ws://127.0.0.1:65250/abc123/ws'),
      );
    });
  });

  group('runner display metadata (from the file, never from code)', () {
    test("runnerName reflects the file's `runner` field", () async {
      final path = ExternalSessionRunnerControl.defaultSessionPathFor(
        projectDir.path,
      );
      _writeSessionFile(path, runner: 'some-runner-v9');
      final control = _makeControl(path);
      expect(control.runnerName, equals('external-session')); // not read yet
      await control.liveVmServiceUri();
      expect(control.runnerName, equals('some-runner-v9'));
    });

    test('absent `runner` field keeps the neutral default', () async {
      final path = ExternalSessionRunnerControl.defaultSessionPathFor(
        projectDir.path,
      );
      _writeSessionFile(path, runner: null);
      final control = _makeControl(path);
      await control.liveVmServiceUri();
      expect(control.runnerName, equals('external-session'));
    });

    test('missing file keeps the neutral default', () async {
      final control = _makeControl(
        ExternalSessionRunnerControl.defaultSessionPathFor(projectDir.path),
      );
      await control.isAlive();
      expect(control.runnerName, equals('external-session'));
    });
  });

  group('isAlive', () {
    test('discovery file + control connect succeeds → true', () async {
      final server = _FakeControlServer();
      await server.start();
      final path = ExternalSessionRunnerControl.defaultSessionPathFor(
        projectDir.path,
      );
      _writeSessionFile(path, controlPort: server.port);
      final control = _makeControl(path);
      expect(await control.isAlive(), isTrue);
      await server.stop();
    });

    test('discovery file but control port closed → false', () async {
      final path = ExternalSessionRunnerControl.defaultSessionPathFor(
        projectDir.path,
      );
      _writeSessionFile(path, controlPort: 1);
      final control = _makeControl(path);
      expect(await control.isAlive(), isFalse);
    });

    test('no discovery file → false even with a server up', () async {
      final server = _FakeControlServer();
      await server.start();
      final control = _makeControl(
        ExternalSessionRunnerControl.defaultSessionPathFor(projectDir.path),
      );
      expect(await control.isAlive(), isFalse);
      expect(server.requests, isEmpty);
      await server.stop();
    });
  });

  group('reload / restart over the control channel', () {
    test('reload returns the actual daemon outcome', () async {
      final server = _FakeControlServer()
        ..responses['reload'] = () => <String, Object?>{
          'ok': true,
          'result': <String, Object?>{'reloaded': true, 'sources': 3},
        };
      await server.start();
      final path = ExternalSessionRunnerControl.defaultSessionPathFor(
        projectDir.path,
      );
      _writeSessionFile(path, controlPort: server.port);
      final control = _makeControl(path);

      final outcome = await control.reload();

      expect(outcome.ok, isTrue);
      expect(outcome.fallback, isFalse);
      expect(outcome.raw, containsPair('reloaded', true));
      expect(server.requests.single.method, equals('reload'));
      await server.stop();
    });

    test('reload surfaces the daemon error verbatim', () async {
      final server = _FakeControlServer()
        ..responses['reload'] = () => <String, Object?>{
          'ok': false,
          'error': 'Fix the compile error in lib/main.dart line 12 first.',
        };
      await server.start();
      final path = ExternalSessionRunnerControl.defaultSessionPathFor(
        projectDir.path,
      );
      _writeSessionFile(path, controlPort: server.port);
      final control = _makeControl(path);

      final outcome = await control.reload();

      expect(outcome.ok, isFalse);
      expect(outcome.error, contains('lib/main.dart line 12'));
      await server.stop();
    });

    test('restart reports the daemon fallback flag', () async {
      final server = _FakeControlServer()
        ..responses['restart'] = () => <String, Object?>{
          'ok': true,
          'result': <String, Object?>{'fallback': true},
        };
      await server.start();
      final path = ExternalSessionRunnerControl.defaultSessionPathFor(
        projectDir.path,
      );
      _writeSessionFile(path, controlPort: server.port);
      final control = _makeControl(path);

      final outcome = await control.restart();

      expect(outcome.ok, isTrue);
      expect(outcome.fallback, isTrue);
      expect(outcome.sessionRelaunched, isFalse);
      await server.stop();
    });

    test('control port refuses → actionable error', () async {
      final path = ExternalSessionRunnerControl.defaultSessionPathFor(
        projectDir.path,
      );
      _writeSessionFile(path, controlPort: 1);
      final control = _makeControl(path);

      final outcome = await control.reload();

      expect(outcome.ok, isFalse);
      expect(outcome.error, contains('runner control channel'));
      expect(outcome.error, contains('still running'));
    });

    test('no response → bounded timeout with actionable error', () async {
      final server = _FakeControlServer()..neverRespond.add('reload');
      await server.start();
      final path = ExternalSessionRunnerControl.defaultSessionPathFor(
        projectDir.path,
      );
      _writeSessionFile(path, controlPort: server.port);
      final control = _makeControl(
        path,
        reloadTimeout: const Duration(milliseconds: 200),
      );

      final outcome = await control.reload();

      expect(outcome.ok, isFalse);
      expect(outcome.error, contains('timed out after 0s'));
      expect(outcome.error, contains(server.port.toString()));
      await server.stop();
    });

    test('reload EOF mid-request reports the connection loss', () async {
      final server = _FakeControlServer()..closeWithoutResponse.add('reload');
      await server.start();
      final path = ExternalSessionRunnerControl.defaultSessionPathFor(
        projectDir.path,
      );
      _writeSessionFile(path, controlPort: server.port);
      final control = _makeControl(path);

      final outcome = await control.reload();

      expect(outcome.ok, isFalse);
      expect(outcome.error, contains('closed during "reload"'));
      expect(outcome.error, contains('still exists'));
      await server.stop();
    });
  });

  group('restart EOF fallback (relaunch + re-attach)', () {
    test(
      'EOF mid-restart → re-reads the discovery file once, reports the new '
      'wsUri, does NOT resend the restart',
      () async {
        final server = _FakeControlServer()..closeWithoutResponse.add('restart');
        await server.start();
        final path = ExternalSessionRunnerControl.defaultSessionPathFor(
          projectDir.path,
        );
        _writeSessionFile(path, controlPort: server.port);
        final control = _makeControl(path);

        // Simulate the relaunched session owning a new app endpoint.
        _writeSessionFile(
          path,
          controlPort: server.port,
          vmServiceUri: 'ws://127.0.0.1:7777/new-token/ws',
          startedAt: '2026-09-08T00:00:01.000Z',
          pid: 12346,
        );

        final outcome = await control.restart();

        expect(outcome.ok, isTrue);
        expect(outcome.fallback, isTrue);
        expect(outcome.sessionRelaunched, isTrue);
        expect(outcome.vmServiceUri, equals('ws://127.0.0.1:7777/new-token/ws'));
        expect(outcome.raw['inferred'], equals('relaunch_fallback_eof'));
        // The restart must NOT have been retried.
        expect(server.requests.map((final r) => r.method), ['restart']);
        await server.stop();
      },
    );

    test('EOF mid-restart with session gone → actionable failure', () async {
      final server = _FakeControlServer()..closeWithoutResponse.add('restart');
      await server.start();
      final path = ExternalSessionRunnerControl.defaultSessionPathFor(
        projectDir.path,
      );
      _writeSessionFile(path, controlPort: server.port);
      final control = _makeControl(path);

      // Simulate the session exiting mid-restart: the discovery file is
      // removed at the exact moment the control connection drops.
      server.onConnectionDrop = (final method) {
        if (method == 'restart') {
          File(path).deleteSync();
        }
      };

      final outcome = await control.restart();

      expect(outcome.ok, isFalse);
      expect(outcome.sessionRelaunched, isTrue);
      expect(outcome.error, contains('session ended'));
      await server.stop();
    });
  });

  group('status', () {
    test('returns the session status payload', () async {
      final server = _FakeControlServer()
        ..responses['status'] = () => <String, Object?>{
          'ok': true,
          'result': <String, Object?>{
            'session': 'ready',
            'device': 'emulator-5554',
            'target': 'lib/main.dart',
            'mode': 'attach',
          },
        };
      await server.start();
      final path = ExternalSessionRunnerControl.defaultSessionPathFor(
        projectDir.path,
      );
      _writeSessionFile(path, controlPort: server.port);
      final control = _makeControl(path);

      final status = await control.status();

      expect(status, containsPair('session', 'ready'));
      expect(status, containsPair('device', 'emulator-5554'));
      await server.stop();
    });
  });
}
