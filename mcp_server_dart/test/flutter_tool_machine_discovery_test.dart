import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_toolkit_server/flutter_mcp_core.dart';
import 'package:test/test.dart';

void main() {
  group('FlutterToolMachineDiscovery', () {
    test('parseMachineEvent extracts canonical VM WS URI and DTD URI', () {
      final parsed = FlutterToolMachineDiscovery.parseMachineEvent({
        'event': 'app.debugPort',
        'params': {
          'app': {
            'debugPort': {'wsUri': 'WS://LOCALHOST:59490/qwerty/ws'},
            'dtd': {'uri': 'ws://127.0.0.1:59490/dtd/ws'},
          },
        },
      });

      expect(
        parsed.vmServiceWsUri?.toString(),
        equals('ws://localhost:59490/qwerty/ws'),
      );
      expect(parsed.dtdUri?.toString(), equals('ws://127.0.0.1:59490/dtd/ws'));
    });

    test('parseMachineEvent extracts dtd URI from app.dtd.uri event', () {
      final parsed = FlutterToolMachineDiscovery.parseMachineEvent({
        'event': 'app.dtd.uri',
        'params': {'uri': 'ws://127.0.0.1:59490/dtd'},
      });

      expect(parsed.vmServiceWsUri, isNull);
      expect(parsed.dtdUri?.toString(), equals('ws://127.0.0.1:59490/dtd'));
    });

    test('parseVmServiceWsUri rejects legacy host:port style values', () {
      final parsed = FlutterToolMachineDiscovery.parseVmServiceWsUri(
        'localhost:59490',
      );
      expect(parsed, isNull);
    });

    test(
      'parseProcessVmServiceWsUri upgrades http VM URI to canonical ws URI',
      () {
        final parsed = FlutterToolMachineDiscovery.parseProcessVmServiceWsUri(
          '/path/to/dart development-service --vm-service-uri=http://127.0.0.1:55571/jafDCsl7Cz4=/ --bind-address=127.0.0.1 --bind-port=0',
        );

        expect(
          parsed?.toString(),
          equals('ws://127.0.0.1:55571/jafDCsl7Cz4=/ws'),
        );
      },
    );

    test('parseProcessDiscoveryLine extracts target from DDS command line', () {
      final parsed = FlutterToolMachineDiscovery.parseProcessDiscoveryLine(
        '76597 /opt/flutter/bin/cache/dart-sdk/bin/dart development-service --vm-service-uri=http://127.0.0.1:55571/jafDCsl7Cz4=/ --bind-address=127.0.0.1 --bind-port=0 --serve-devtools',
      );

      expect(
        parsed?.vmServiceWsUri.toString(),
        equals('ws://127.0.0.1:55571/jafDCsl7Cz4=/ws'),
      );
      expect(parsed?.sourceEvent, equals('process.vmServiceUri'));
    });

    test(
      'uses Windows tree termination when graceful stop times out',
      () async {
        final process = _StubbornProcess(4242);
        final taskkillProcess = _StubbornProcess(5000)..completeExit(0);
        List<String>? taskkillArguments;
        addTearDown(() async {
          await process.dispose();
          await taskkillProcess.dispose();
        });

        final discovery = FlutterToolMachineDiscovery(
          logger: (final level, final message, {final logger = ''}) {},
          processStarter:
              (
                final executable,
                final arguments, {
                final workingDirectory,
                final runInShell = false,
              }) async {
                if (executable == 'taskkill') {
                  taskkillArguments = List<String>.of(arguments);
                  process.completeExit(-1);
                  return taskkillProcess;
                }
                return process;
              },
          isWindows: true,
          stopTimeout: Duration.zero,
          processLinesProvider: () async => const <String>[],
        );

        await discovery.discover(timeout: Duration.zero);

        expect(taskkillArguments, equals(<String>['/PID', '4242', '/T', '/F']));
        expect(process.killSignals, isEmpty);
        expect(process.stdinText, contains('q'));
      },
    );

    test('falls back when Windows tree termination fails', () async {
      final process = _StubbornProcess(4242);
      final taskkillProcess = _StubbornProcess(5000)..completeExit(1);
      addTearDown(() async {
        await process.dispose();
        await taskkillProcess.dispose();
      });

      final discovery = FlutterToolMachineDiscovery(
        logger: (final level, final message, {final logger = ''}) {},
        processStarter:
            (
              final executable,
              final arguments, {
              final workingDirectory,
              final runInShell = false,
            }) async => executable == 'taskkill' ? taskkillProcess : process,
        isWindows: true,
        stopTimeout: Duration.zero,
        processLinesProvider: () async => const <String>[],
      );

      await discovery.discover(timeout: Duration.zero);

      expect(
        process.killSignals,
        equals(<ProcessSignal>[ProcessSignal.sigterm]),
      );
    });

    test('bounds Windows tree termination before falling back', () async {
      final process = _StubbornProcess(2147483000);
      final taskkillProcess = _StubbornProcess(4242);
      addTearDown(() async {
        await process.dispose();
        await taskkillProcess.dispose();
      });

      final discovery = FlutterToolMachineDiscovery(
        logger: (final level, final message, {final logger = ''}) {},
        processStarter:
            (
              final executable,
              final arguments, {
              final workingDirectory,
              final runInShell = false,
            }) async => executable == 'taskkill' ? taskkillProcess : process,
        isWindows: true,
        stopTimeout: Duration.zero,
        processLinesProvider: () async => const <String>[],
      );

      await discovery
          .discover(timeout: Duration.zero)
          .timeout(const Duration(milliseconds: 100));

      expect(
        process.killSignals,
        equals(<ProcessSignal>[ProcessSignal.sigterm]),
      );
      expect(
        taskkillProcess.killSignals,
        equals(<ProcessSignal>[ProcessSignal.sigterm]),
      );
    });

    test('retains direct kill escalation outside Windows', () async {
      final process = _StubbornProcess(4242, completeOnSigterm: false);
      addTearDown(process.dispose);

      final discovery = FlutterToolMachineDiscovery(
        logger: (final level, final message, {final logger = ''}) {},
        processStarter:
            (
              final executable,
              final arguments, {
              final workingDirectory,
              final runInShell = false,
            }) async => process,
        isWindows: false,
        stopTimeout: Duration.zero,
        processLinesProvider: () async => const <String>[],
      );

      await discovery.discover(timeout: Duration.zero);

      expect(
        process.killSignals,
        equals(<ProcessSignal>[ProcessSignal.sigterm, ProcessSignal.sigkill]),
      );
    });
  });
}

final class _StubbornProcess implements Process {
  _StubbornProcess(this.pid, {this.completeOnSigterm = true})
    : _stdinController = StreamController<List<int>>(sync: true),
      _exitCompleter = Completer<int>() {
    _stdinController.stream.listen(stdinBytes.addAll);
    stdin = IOSink(_stdinController.sink);
  }

  final StreamController<List<int>> _stdinController;
  final Completer<int> _exitCompleter;
  final bool completeOnSigterm;
  final List<int> stdinBytes = <int>[];
  final List<ProcessSignal> killSignals = <ProcessSignal>[];

  String get stdinText => utf8.decode(stdinBytes);

  @override
  final int pid;

  @override
  late final IOSink stdin;

  @override
  Stream<List<int>> get stdout => const Stream<List<int>>.empty();

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  Future<int> get exitCode => _exitCompleter.future;

  @override
  bool kill([final ProcessSignal signal = ProcessSignal.sigterm]) {
    killSignals.add(signal);
    if (completeOnSigterm || signal == ProcessSignal.sigkill) {
      completeExit(-1);
    }
    return true;
  }

  void completeExit(final int code) {
    if (!_exitCompleter.isCompleted) {
      _exitCompleter.complete(code);
    }
  }

  Future<void> dispose() async {
    completeExit(-1);
    await stdin.close();
  }
}
