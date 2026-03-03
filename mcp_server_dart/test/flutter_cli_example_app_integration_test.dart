import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  final runIntegration =
      Platform.environment['RUN_FLUTTER_CLI_INTEGRATION'] == '1';

  group('flutter_mcp_cli with flutter_test_app', () {
    late Process flutterProcess;
    late StreamSubscription<String> stdoutSub;
    late StreamSubscription<String> stderrSub;
    late Directory stateDir;
    final vmServiceWsUriCompleter = Completer<String>();

    setUpAll(() async {
      if (!runIntegration) return;

      stateDir = Directory.systemTemp.createTempSync(
        'flutter_mcp_cli_integration_',
      );
      _stateFilePath = '${stateDir.path}/state.json';

      final appDir = _appDirectory();
      final pubGet = await Process.run('flutter', [
        'pub',
        'get',
      ], workingDirectory: appDir.path);
      if (pubGet.exitCode != 0) {
        fail('flutter pub get failed: ${pubGet.stderr}\n${pubGet.stdout}');
      }

      flutterProcess = await Process.start('flutter', [
        'run',
        '--debug',
        '--host-vmservice-port=8181',
        '-d',
        'macos',
      ], workingDirectory: appDir.path);

      stdoutSub = flutterProcess.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((final line) {
            stdout.writeln('[flutter_test_app] $line');

            final vmUri = _extractVmServiceWsUri(line);
            if (vmUri != null && !vmServiceWsUriCompleter.isCompleted) {
              vmServiceWsUriCompleter.complete(vmUri);
            }
          });

      stderrSub = flutterProcess.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((final line) {
            stderr.writeln('[flutter_test_app:stderr] $line');
          });

      final vmServiceWsUri = await vmServiceWsUriCompleter.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () => throw TimeoutException(
          'Timed out waiting for VM service URI from flutter run output',
        ),
      );
      _globalVmServiceWsUri = vmServiceWsUri;

      await _waitForCliConnectable(
        vmServiceWsUri: vmServiceWsUri,
        timeout: const Duration(minutes: 2),
        interval: const Duration(seconds: 2),
      );
    });

    tearDownAll(() async {
      if (!runIntegration) return;

      try {
        flutterProcess.stdin.writeln('q');
        await flutterProcess.exitCode.timeout(const Duration(seconds: 20));
      } catch (_) {
        flutterProcess.kill(ProcessSignal.sigkill);
      }

      await stdoutSub.cancel();
      await stderrSub.cancel();
      _globalVmServiceWsUri = null;
      _stateFilePath = null;
      if (stateDir.existsSync()) {
        stateDir.deleteSync(recursive: true);
      }
    });

    test(
      'can connect and execute canonical commands',
      skip: runIntegration ? false : 'Set RUN_FLUTTER_CLI_INTEGRATION=1 to run',
      timeout: const Timeout(Duration(minutes: 8)),
      () async {
        final status = await _runCli(['status']);
        expect(status['ok'], isTrue);

        final connect = await _runCli([
          'connect',
          '--mode',
          'uri',
          '--uri',
          _globalVmServiceWsUri!,
        ]);
        expect(connect['ok'], isTrue);

        final vm = await _runCli(['get_vm']);
        expect(vm['ok'], isTrue);
        expect((vm['data'] as Map<String, dynamic>)['isolates'], isNotNull);

        final exts = await _runCli(['get_extension_rpcs']);
        expect(exts['ok'], isTrue);
        final extList = ((exts['data'] as List).cast<String>());
        expect(extList.any((final e) => e.startsWith('ext.flutter')), isTrue);
        expect(
          extList.any(
            (final e) => e.contains('ext.mcp.toolkit.registerDynamics'),
          ),
          isTrue,
        );

        final viewDetails = await _runCli(['get_view_details']);
        expect(viewDetails['ok'], isTrue);

        final dynamicList = await _waitForDynamicTool('get_app_ui_state');
        expect(dynamicList['ok'], isTrue);

        final runTool = await _runCli([
          'runClientTool',
          '--tool-name',
          'get_app_ui_state',
          '--arguments',
          '{}',
        ]);
        expect(runTool['ok'], isTrue);

        final sessionStart = await _runCli([
          'session_start',
          '--mode',
          'uri',
          '--uri',
          _globalVmServiceWsUri!,
        ]);
        expect(sessionStart['ok'], isTrue);
        final sessionId =
            (sessionStart['data'] as Map<String, dynamic>)['sessionId']
                as String;
        expect(sessionId, isNotEmpty);

        final sessionExec = await _runCli([
          'session_exec',
          '--session-id',
          sessionId,
          '--command',
          'get_vm',
          '--arguments',
          '{}',
        ]);
        expect(sessionExec['ok'], isTrue);
        expect(
          (sessionExec['data'] as Map<String, dynamic>)['isolates'],
          isNotNull,
        );
        expect(
          (sessionExec['meta'] as Map<String, dynamic>)['sessionId'],
          sessionId,
        );

        final diagnose = await _runCli(['diagnose', '--include-view-details']);
        expect(diagnose['ok'], isTrue);
        final summary =
            (diagnose['data'] as Map<String, dynamic>)['summary']
                as Map<String, dynamic>;
        expect(summary['total'], greaterThan(0));

        final watchEvents = await _runCliWatch([
          'watch',
          '--session-id',
          sessionId,
          '--command',
          'get_app_errors',
          '--arguments',
          '{"count":1}',
          '--interval-ms',
          '300',
          '--max-events',
          '2',
        ]);
        expect(watchEvents.first['event'], equals('watch_started'));
        expect(watchEvents.last['event'], equals('watch_stopped'));
        expect(
          watchEvents.where((final e) => e['event'] == 'command_result').length,
          equals(2),
        );

        final explain = await _runCli([
          'explain_errors',
          '--count',
          '4',
          '--no-include-summary',
        ]);
        expect(explain['ok'], isTrue);
        final causes =
            ((explain['data'] as Map<String, dynamic>)['causes'] as List)
                .cast<Map<String, dynamic>>();
        expect(
          causes.any((final cause) => cause['code'] == 'render_flex_overflow'),
          isTrue,
        );

        final sessionEnd = await _runCli([
          'session_end',
          '--session-id',
          sessionId,
        ]);
        expect(sessionEnd['ok'], isTrue);

        final hotReload = await _runCli(['hot_reload_flutter']);
        expect(hotReload['ok'], isTrue);
      },
    );
  });
}

String? _globalVmServiceWsUri;
String? _stateFilePath;

Directory _serverDirectory() => Directory.current;

Directory _appDirectory() =>
    Directory('${Directory.current.path}/../flutter_test_app');

String? _extractVmServiceWsUri(final String line) {
  final match = RegExp(
    r'A Dart VM Service on .* is available at: (http://\S+)',
  ).firstMatch(line);
  if (match == null) {
    return null;
  }

  final httpUri = Uri.parse(match.group(1)!);
  final pathWithWs = httpUri.path.endsWith('/')
      ? '${httpUri.path}ws'
      : '${httpUri.path}/ws';
  return httpUri.replace(scheme: 'ws', path: pathWithWs).toString();
}

Future<void> _waitForCliConnectable({
  required final String vmServiceWsUri,
  required final Duration timeout,
  required final Duration interval,
}) async {
  final start = DateTime.now();

  while (DateTime.now().difference(start) < timeout) {
    final connect = await _runCliRaw([
      'connect',
      '--mode',
      'uri',
      '--uri',
      vmServiceWsUri,
    ]);

    if (connect.envelope['ok'] == true) {
      return;
    }

    await Future.delayed(interval);
  }

  fail('Timed out waiting for flutter_test_app to become connectable via CLI');
}

Future<Map<String, dynamic>> _waitForDynamicTool(final String toolName) async {
  final start = DateTime.now();
  const timeout = Duration(seconds: 60);

  while (DateTime.now().difference(start) < timeout) {
    final result = await _runCli(['listClientToolsAndResources']);
    if (result['ok'] == true) {
      final data = result['data'] as Map<String, dynamic>;
      final tools = (data['tools'] as List?) ?? const [];
      final names = tools
          .whereType<Map>()
          .map((final t) => '${t['name']}')
          .toSet();
      if (names.contains(toolName)) {
        return result;
      }
    }

    await Future.delayed(const Duration(seconds: 2));
  }

  fail('Dynamic tool $toolName did not appear in time');
}

Future<Map<String, dynamic>> _runCli(final List<String> args) async {
  final raw = await _runCliRaw(args);
  if (raw.result.exitCode != 0) {
    fail(
      'CLI failed for args $args\nexit=${raw.result.exitCode}\n'
      'stdout=${raw.result.stdout}\n'
      'stderr=${raw.result.stderr}',
    );
  }
  return raw.envelope;
}

Future<({ProcessResult result, Map<String, dynamic> envelope})> _runCliRaw(
  final List<String> args,
) async {
  final fullArgs = _buildCliArgs(args);

  final result = await Process.run(
    'dart',
    fullArgs,
    workingDirectory: _serverDirectory().path,
  );

  final stdoutText = (result.stdout as String).trim();
  if (stdoutText.isEmpty) {
    return (
      result: result,
      envelope: <String, dynamic>{'ok': false, 'error': 'empty_stdout'},
    );
  }

  final envelope = jsonDecode(stdoutText) as Map<String, dynamic>;
  return (result: result, envelope: envelope);
}

Future<List<Map<String, dynamic>>> _runCliWatch(final List<String> args) async {
  final fullArgs = _buildCliArgs(args);
  final result = await Process.run(
    'dart',
    fullArgs,
    workingDirectory: _serverDirectory().path,
  );

  if (result.exitCode != 0) {
    fail(
      'CLI watch failed for args $args\nexit=${result.exitCode}\n'
      'stdout=${result.stdout}\n'
      'stderr=${result.stderr}',
    );
  }

  final lines = (result.stdout as String)
      .split('\n')
      .map((final l) => l.trim())
      .where((final l) => l.isNotEmpty)
      .toList();

  return lines
      .map((final line) => jsonDecode(line) as Map<String, dynamic>)
      .toList();
}

List<String> _buildCliArgs(final List<String> args) {
  final fullArgs = <String>['run', 'bin/flutter_mcp_cli.dart'];

  final statePath = _stateFilePath;
  if (statePath != null && statePath.isNotEmpty) {
    fullArgs.addAll(['--state-file', statePath]);
  }

  final vmServiceUri = _globalVmServiceWsUri;
  if (vmServiceUri != null &&
      vmServiceUri.isNotEmpty &&
      args.isNotEmpty &&
      args.first != 'connect') {
    fullArgs.addAll(['--vm-service-uri', vmServiceUri]);
  }

  fullArgs.addAll(args);
  return fullArgs;
}
