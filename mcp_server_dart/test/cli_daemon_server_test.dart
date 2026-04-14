import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('flutter_mcp_cli serve', () {
    late Directory tempDir;
    late String statePath;
    Process? process;
    StreamSubscription<Map<String, dynamic>>? subscription;
    final events = <Map<String, dynamic>>[];

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('flutter_mcp_serve_');
      statePath = '${tempDir.path}/state.json';

      process = await Process.start('dart', [
        'run',
        'bin/flutter_mcp_cli.dart',
        '--state-file',
        statePath,
        'serve',
      ], workingDirectory: Directory.current.path);

      final stream = process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .where((final line) => line.trim().isNotEmpty)
          .map((final line) => jsonDecode(line) as Map<String, dynamic>)
          .asBroadcastStream();

      subscription = stream.listen(events.add);

      process!.stderr
          .transform(utf8.decoder)
          .listen((final _) {}); // keep stderr drained

      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    tearDown(() async {
      await subscription?.cancel();
      process?.kill();
      if (process != null) {
        try {
          await process!.exitCode.timeout(const Duration(seconds: 2));
        } on TimeoutException {
          process!.kill(ProcessSignal.sigkill);
        }
      }

      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
      events.clear();
    });

    test('supports initialize/execute/watch and structured errors', () async {
      final init = await _sendRequest(
        id: 1,
        method: 'initialize',
        params: const <String, Object?>{},
        process: process!,
        events: events,
      );
      expect(init['result'], isNotNull);

      final capabilities = await _sendRequest(
        id: 2,
        method: 'capabilities/get',
        params: const <String, Object?>{},
        process: process!,
        events: events,
      );
      expect(
        (capabilities['result'] as Map<String, dynamic>)['schemaVersion'],
        equals('command-catalog/v1'),
      );

      final status = await _sendRequest(
        id: 3,
        method: 'command/execute',
        params: {'name': 'status', 'args': const <String, Object?>{}},
        process: process!,
        events: events,
      );
      expect((status['result'] as Map<String, dynamic>)['ok'] as bool, isTrue);

      final vmFailure = await _sendRequest(
        id: 4,
        method: 'command/execute',
        params: {'name': 'get_vm', 'args': const <String, Object?>{}},
        process: process!,
        events: events,
      );
      final vmError = vmFailure['error'] as Map<String, dynamic>;
      expect(vmError['data'], isA<Map<String, dynamic>>());
      final errorData = vmError['data'] as Map<String, dynamic>;
      expect(errorData['error'], isA<Map<String, dynamic>>());
      final coreError = errorData['error'] as Map<String, dynamic>;
      expect(coreError['descriptor'], isA<Map<String, dynamic>>());
      expect(
        (coreError['descriptor'] as Map<String, dynamic>)['retryable'],
        isTrue,
      );
      expect(coreError['recovery'], isA<Map<String, dynamic>>());

      final watchStart = await _sendRequest(
        id: 5,
        method: 'watch/start',
        params: {
          'name': 'status',
          'args': const <String, Object?>{},
          'intervalMs': 10,
          'maxEvents': 1,
          'stopOnError': false,
        },
        process: process!,
        events: events,
      );

      final watchId =
          (watchStart['result'] as Map<String, dynamic>)['watchId'] as String;
      expect(watchId, isNotEmpty);

      final started = await _waitForEvent(
        events,
        (final e) =>
            e['method'] == 'watch/event' &&
            (e['params'] as Map<String, dynamic>)['event'] == 'watch_started' &&
            (e['params'] as Map<String, dynamic>)['watchId'] == watchId,
      );
      expect(started, isNotNull);

      final commandResult = await _waitForEvent(
        events,
        (final e) =>
            e['method'] == 'watch/event' &&
            (e['params'] as Map<String, dynamic>)['event'] ==
                'command_result' &&
            (e['params'] as Map<String, dynamic>)['watchId'] == watchId,
      );
      expect(commandResult, isNotNull);

      final stopped = await _waitForEvent(
        events,
        (final e) =>
            e['method'] == 'watch/event' &&
            (e['params'] as Map<String, dynamic>)['event'] == 'watch_stopped' &&
            (e['params'] as Map<String, dynamic>)['watchId'] == watchId,
      );
      expect(stopped, isNotNull);
    });

    test('command/execute honors params.args.connection', () async {
      await _sendRequest(
        id: 10,
        method: 'initialize',
        params: const <String, Object?>{},
        process: process!,
        events: events,
      );

      final response = await _sendRequest(
        id: 11,
        method: 'command/execute',
        params: {
          'name': 'status',
          'args': {
            'connection': {'targetId': 'ws://localhost:9999/ws'},
          },
        },
        process: process!,
        events: events,
      );

      final rpcError = response['error'] as Map<String, dynamic>;
      final errorData = rpcError['data'] as Map<String, dynamic>;
      final coreError = errorData['error'] as Map<String, dynamic>;

      expect(coreError['code'], equals('connect_failed'));
      expect(coreError['details'], isA<Map<String, dynamic>>());
      expect(
        (coreError['details'] as Map<String, dynamic>)['reason'],
        equals('target_not_found'),
      );
    });

    test('watch/start honors params.args.connection', () async {
      await _sendRequest(
        id: 20,
        method: 'initialize',
        params: const <String, Object?>{},
        process: process!,
        events: events,
      );

      final response = await _sendRequest(
        id: 21,
        method: 'watch/start',
        params: {
          'name': 'status',
          'args': {
            'connection': {'targetId': 'ws://localhost:9999/ws'},
          },
          'intervalMs': 25,
          'maxEvents': 1,
          'stopOnError': true,
        },
        process: process!,
        events: events,
      );

      final rpcError = response['error'] as Map<String, dynamic>;
      final errorData = rpcError['data'] as Map<String, dynamic>;
      final coreError = errorData['error'] as Map<String, dynamic>;

      expect(coreError['code'], equals('connect_failed'));
      expect(coreError['details'], isA<Map<String, dynamic>>());
      expect(
        (coreError['details'] as Map<String, dynamic>)['reason'],
        equals('target_not_found'),
      );
    });
  });
}

Future<Map<String, dynamic>> _sendRequest({
  required final int id,
  required final String method,
  required final Map<String, Object?> params,
  required final Process process,
  required final List<Map<String, dynamic>> events,
}) async {
  process.stdin.writeln(
    jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    }),
  );

  final response = await _waitForEvent(events, (final e) => e['id'] == id);

  if (response == null) {
    throw TimeoutException('No response for request $id ($method)');
  }

  return response;
}

Future<Map<String, dynamic>?> _waitForEvent(
  final List<Map<String, dynamic>> events,
  final bool Function(Map<String, dynamic>) predicate,
) async {
  final started = DateTime.now();
  while (DateTime.now().difference(started) < const Duration(seconds: 20)) {
    for (final event in events) {
      if (predicate(event)) {
        return event;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return null;
}
