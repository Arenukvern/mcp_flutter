import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_mcp/server.dart' show LoggingLevel;
import 'package:flutter_mcp_toolkit_server/flutter_mcp_core.dart';
import 'package:test/test.dart';

void _discardLog(
  final LoggingLevel level,
  final String message, {
  final String logger = '',
}) {}

Future<List<String>> _emptyProcessLines() async => const <String>[];

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
      'uses parent-aware Windows cleanup before the shell wrapper can exit',
      () async {
        final process = _StubbornProcess(4242);
        final powershellProcess = _StubbornProcess(5000)..completeExit(0);
        List<String>? powershellArguments;
        var taskkillStarted = false;
        addTearDown(() async {
          await process.dispose();
          await powershellProcess.dispose();
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
                if (executable == 'powershell.exe') {
                  powershellArguments = List<String>.of(arguments);
                  process.completeExit(-1);
                  return powershellProcess;
                }
                if (executable == 'taskkill') {
                  taskkillStarted = true;
                }
                return process;
              },
          isWindows: true,
          stopTimeout: Duration.zero,
          windowsTreeStopTimeout: Duration.zero,
          processLinesProvider: () async => const <String>[],
        );

        await discovery.discover(timeout: Duration.zero);

        expect(powershellArguments, isNotNull);
        expect(powershellArguments, contains('-Command'));
        expect(powershellArguments!.last, contains('ParentProcessId'));
        expect(powershellArguments!.last, contains('flutter_tools'));
        expect(powershellArguments!.last, contains('CreationDate'));
        expect(powershellArguments!.last, contains('WaitForExit'));
        expect(powershellArguments!.last, contains('ExitTime'));
        expect(
          powershellArguments!.last,
          contains(r"$ErrorActionPreference = 'Stop'"),
        );
        expect(
          powershellArguments!.last,
          contains(r'[void]$rootHandle.Handle'),
        );
        expect(powershellArguments!.last, contains(r'$parentId -ne $rootPid'));
        expect(powershellArguments!.last, contains(r'$quietPasses'));
        expect(powershellArguments!.last, contains(r'$created.Ticks'));
        expect(
          powershellArguments!.last,
          isNot(contains(r'$lineage[$processId] = $true')),
        );
        expect(
          powershellArguments!.last,
          isNot(contains(r'Stop-Process -Id $rootPid')),
        );
        expect(taskkillStarted, isFalse);
        expect(process.killSignals, isEmpty);
        expect(process.stdinText, isEmpty);
      },
    );

    test('preserves the public const constructor', () {
      const discovery = FlutterToolMachineDiscovery(
        logger: _discardLog,
        processLinesProvider: _emptyProcessLines,
      );

      expect(discovery, isA<FlutterToolMachineDiscovery>());
    });

    test('coalesces overlapping discovery requests', () async {
      final allowProcessStart = Completer<void>();
      final processes = <_StubbornProcess>[];
      var processStartCount = 0;
      addTearDown(() async {
        for (final process in processes) {
          await process.dispose();
        }
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
              processStartCount++;
              await allowProcessStart.future;
              final process = _StubbornProcess(4200 + processStartCount);
              processes.add(process);
              return process;
            },
        isWindows: false,
        stopTimeout: Duration.zero,
        processLinesProvider: () async => const <String>[],
      );

      final first = discovery.discover(timeout: Duration.zero);
      final second = discovery.discover(timeout: Duration.zero);
      allowProcessStart.complete();

      await Future.wait(<Future<Object?>>[first, second]);

      expect(processStartCount, 1);
    });

    test(
      'does not coalesce overlapping requests with different inputs',
      () async {
        final allowProcessStart = Completer<void>();
        final processes = <_StubbornProcess>[];
        var processStartCount = 0;
        addTearDown(() async {
          for (final process in processes) {
            await process.dispose();
          }
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
                processStartCount++;
                await allowProcessStart.future;
                final process = _StubbornProcess(4300 + processStartCount);
                processes.add(process);
                return process;
              },
          isWindows: false,
          stopTimeout: Duration.zero,
          processLinesProvider: () async => const <String>[],
        );

        final first = discovery.discover(
          device: 'windows',
          timeout: Duration.zero,
        );
        final second = discovery.discover(
          device: 'chrome',
          timeout: Duration.zero,
        );
        allowProcessStart.complete();

        await Future.wait(<Future<Object?>>[first, second]);

        expect(processStartCount, 2);
      },
    );

    test('falls back when Windows tree termination fails', () async {
      final process = _StubbornProcess(4242);
      final powershellProcess = _StubbornProcess(5001)..completeExit(1);
      final taskkillProcess = _StubbornProcess(5000)..completeExit(1);
      var powershellStarted = false;
      var taskkillStarted = false;
      addTearDown(() async {
        await process.dispose();
        await powershellProcess.dispose();
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
              if (executable == 'powershell.exe') {
                powershellStarted = true;
                return powershellProcess;
              }
              if (executable == 'taskkill') {
                taskkillStarted = true;
                return taskkillProcess;
              }
              return process;
            },
        isWindows: true,
        stopTimeout: Duration.zero,
        windowsTreeStopTimeout: Duration.zero,
        processLinesProvider: () async => const <String>[],
      );

      await discovery.discover(timeout: Duration.zero);

      expect(powershellStarted, isTrue);
      expect(taskkillStarted, isFalse);
      expect(process.killSignals, isEmpty);
      expect(process.stdinText, contains('q'));
    });

    test('bounds Windows tree termination before falling back', () async {
      final process = _StubbornProcess(2147483000);
      final powershellProcess = _StubbornProcess(4243);
      final taskkillProcess = _StubbornProcess(4242)..completeExit(1);
      var taskkillStarted = false;
      addTearDown(() async {
        await process.dispose();
        await powershellProcess.dispose();
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
                taskkillStarted = true;
                return taskkillProcess;
              }
              return executable == 'powershell.exe'
                  ? powershellProcess
                  : process;
            },
        isWindows: true,
        stopTimeout: Duration.zero,
        windowsTreeStopTimeout: Duration.zero,
        processLinesProvider: () async => const <String>[],
      );

      await discovery
          .discover(timeout: Duration.zero)
          .timeout(const Duration(milliseconds: 100));

      expect(taskkillStarted, isFalse);
      expect(process.killSignals, isEmpty);
      expect(process.stdinText, contains('q'));
      expect(
        powershellProcess.killSignals,
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
