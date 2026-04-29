import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  final runIntegration =
      Platform.environment['RUN_FLUTTER_CLI_INTEGRATION'] == '1';

  group('flutter-mcp-toolkit with flutter_test_app', () {
    late Process flutterProcess;
    late StreamSubscription<String> stdoutSub;
    late StreamSubscription<String> stderrSub;
    late Directory stateDir;
    final vmServiceWsUriCompleter = Completer<String>();

    setUpAll(() async {
      if (!runIntegration) return;

      stateDir = Directory.systemTemp.createTempSync(
        'flutter_mcp_toolkit_integration_',
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
        final status = await _runCli([
          'exec',
          '--name',
          'status',
          '--args',
          '{}',
        ]);
        expect(status['ok'], isTrue);

        final connect = await _runCli([
          'exec',
          '--name',
          'connect',
          '--args',
          jsonEncode({'mode': 'uri', 'uri': _globalVmServiceWsUri}),
        ]);
        expect(connect['ok'], isTrue);

        final vm = await _runCli(['exec', '--name', 'get_vm', '--args', '{}']);
        expect(vm['ok'], isTrue);
        expect((vm['data'] as Map<String, dynamic>)['isolates'], isNotNull);

        final exts = await _runCli([
          'exec',
          '--name',
          'get_extension_rpcs',
          '--args',
          '{}',
        ]);
        expect(exts['ok'], isTrue);
        final extList = (exts['data'] as List).cast<String>();
        expect(extList.any((final e) => e.startsWith('ext.flutter')), isTrue);
        expect(
          extList.any(
            (final e) => e.contains('ext.mcp.toolkit.registerDynamics'),
          ),
          isTrue,
        );
        expect(
          extList.any(
            (final e) => e.contains('ext.mcp.toolkit.inspect_widget_at_point'),
          ),
          isTrue,
        );

        final discover = await _runCli([
          'exec',
          '--name',
          'discover_debug_apps',
          '--args',
          '{}',
        ]);
        expect(discover['ok'], isTrue);
        final discoverData = discover['data'] as Map<String, dynamic>;
        final targets = (discoverData['targets'] as List)
            .whereType<Map>()
            .map((final e) => e.cast<String, Object?>())
            .toList();
        expect(targets, isNotEmpty);

        final viewDetails = await _runCli([
          'exec',
          '--name',
          'get_view_details',
          '--args',
          '{}',
        ]);
        expect(viewDetails['ok'], isTrue);

        final snapshot = await _runCli([
          'exec',
          '--name',
          'capture_ui_snapshot',
          '--args',
          jsonEncode({
            'connection': {'uri': _globalVmServiceWsUri},
            'errorsCount': 3,
            'includeViewDetails': true,
            'includeErrors': true,
            'compress': true,
            'screenshotMode': 'flutter_layer',
          }),
        ]);
        expect(snapshot['ok'], isTrue);
        final snapshotData = snapshot['data'] as Map<String, dynamic>;
        expect(snapshotData['viewDetails'], isNotNull);
        expect(snapshotData['appErrors'], isNotNull);
        final snapshotSummary = snapshotData['summary'] as Map<String, dynamic>;
        expect(snapshotSummary['imageCount'], isA<int>());
        expect((snapshotSummary['imageCount'] as int) >= 1, isTrue);

        final inspectAtPoint = await _runCli([
          'exec',
          '--name',
          'inspect_widget_at_point',
          '--args',
          jsonEncode({
            'x': 120,
            'y': 220,
            'connection': {'uri': _globalVmServiceWsUri},
          }),
        ]);
        expect(inspectAtPoint['ok'], isTrue);
        final inspectData = inspectAtPoint['data'] as Map<String, dynamic>;
        expect(inspectData['hit'], isA<bool>());
        expect(inspectData['summary'], isA<Map>());

        final dynamicList = await _waitForDynamicTool(
          'get_agent_showcase_state',
        );
        expect(dynamicList['ok'], isTrue);
        final dynamicData = dynamicList['data'] as Map<String, dynamic>;
        final appStateResourceUri = _findResourceUri(
          dynamicData,
          resourceName: 'app_state',
        );
        expect(appStateResourceUri, isNotNull);

        final runTool = await _runCli([
          'exec',
          '--name',
          'runClientTool',
          '--args',
          '{"toolName":"get_agent_showcase_state","arguments":{}}',
        ]);
        expect(runTool['ok'], isTrue);

        final runResource = await _runCli([
          'exec',
          '--name',
          'runClientResource',
          '--args',
          jsonEncode({'resourceUri': appStateResourceUri}),
        ]);
        expect(runResource['ok'], isTrue);
        final resourceData = runResource['data'] as Map<String, dynamic>;
        final content = '${resourceData['content'] ?? ''}'.trim();
        expect(content, isNotEmpty);
        expect('${resourceData['mimeType'] ?? ''}'.trim(), isNotEmpty);
        final decodedResource = _tryDecodeJsonMap(content);
        expect(decodedResource, isNotNull);
        // Showcase AgentState.snapshot() keys (post-v3.0.0 cleanup of the
        // flutter_test_app to drop flutter_live_edit_toolkit deps).
        final agentSnapshotKeys = <String>[
          'counter',
          'greeting',
          'toggle',
          'slider',
          'lastLog',
        ];
        final parameters = decodedResource!['parameters'];
        if (parameters is Map) {
          final params = parameters.cast<String, dynamic>();
          expect(
            agentSnapshotKeys.any(params.containsKey),
            isTrue,
            reason:
                'expected at least one of $agentSnapshotKeys in parameters',
          );
        } else {
          expect(
            agentSnapshotKeys.any(decodedResource.containsKey) ||
                decodedResource.containsKey('message'),
            isTrue,
          );
        }

        final sessionStart = await _runCli([
          'exec',
          '--name',
          'session_start',
          '--args',
          jsonEncode({'mode': 'uri', 'uri': _globalVmServiceWsUri}),
        ]);
        expect(sessionStart['ok'], isTrue);
        final sessionId =
            (sessionStart['data'] as Map<String, dynamic>)['sessionId']
                as String;
        expect(sessionId, isNotEmpty);

        final sessionExec = await _runCli([
          'exec',
          '--name',
          'session_exec',
          '--args',
          jsonEncode({
            'sessionId': sessionId,
            'command': 'get_vm',
            'arguments': <String, Object?>{},
          }),
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

        final diagnose = await _runCli([
          'exec',
          '--name',
          'diagnose',
          '--args',
          '{"includeViewDetails":true}',
        ]);
        expect(diagnose['ok'], isTrue);
        final summary =
            (diagnose['data'] as Map<String, dynamic>)['summary']
                as Map<String, dynamic>;
        expect(summary['total'], greaterThan(0));

        final watchSnapshot = await _runCli([
          'exec',
          '--name',
          'watch',
          '--args',
          jsonEncode({
            'sessionId': sessionId,
            'command': 'get_app_errors',
            'arguments': <String, Object?>{'count': 1},
            'intervalMs': 300,
            'maxEvents': 2,
          }),
        ]);
        expect(watchSnapshot['ok'], isTrue);

        final explain = await _runCli([
          'exec',
          '--name',
          'explain_errors',
          '--args',
          '{"count":4,"includeSummary":false}',
        ]);
        expect(explain['ok'], isTrue);
        // The simplified showcase has no auto-firing fixture errors. Just
        // assert the envelope shape is valid (causes is a list, possibly
        // empty). A specific cause code (e.g. render_flex_overflow) used to
        // be expected here when the live-edit codex fixture was wired in;
        // that fixture is gone in v3.0.0.
        final causes =
            (((explain['data'] as Map<String, dynamic>)['causes'] as List?) ??
                    const [])
                .cast<Map<String, dynamic>>();
        expect(causes, isA<List<Map<String, dynamic>>>());

        final sessionEnd = await _runCli([
          'exec',
          '--name',
          'session_end',
          '--args',
          jsonEncode({'sessionId': sessionId}),
        ]);
        expect(sessionEnd['ok'], isTrue);

        final hotReload = await _runCli([
          'exec',
          '--name',
          'hot_reload_flutter',
          '--args',
          '{}',
        ]);
        expect(hotReload['ok'], isTrue);
      },
    );

    test(
      'every catalog command exec\'s against the live showcase',
      skip: runIntegration ? false : 'Set RUN_FLUTTER_CLI_INTEGRATION=1 to run',
      timeout: const Timeout(Duration(minutes: 12)),
      () async {
        // Wire-surface smoke for every CLI catalog command. Like its MCP
        // counterpart, this asserts that exec dispatches and returns a
        // well-formed envelope — `ok: true` for tools that can succeed
        // standalone, `ok: false` with an error envelope for tools that
        // need preconditions the showcase doesn't satisfy (e.g. no dialog
        // open for handle_dialog). Both shapes prove wiring.
        Future<Map<String, dynamic>> exec(
          final String name,
          final Object args, {
          final bool requireOk = false,
        }) async {
          final raw = await _runCliRaw([
            'exec',
            '--name',
            name,
            '--args',
            args is String ? args : jsonEncode(args),
          ]);
          expect(
            raw.envelope.containsKey('ok'),
            isTrue,
            reason: '$name envelope missing top-level ok field',
          );
          if (requireOk) {
            expect(
              raw.envelope['ok'],
              isTrue,
              reason: '$name expected ok=true, got: ${raw.envelope}',
            );
          }
          return raw.envelope;
        }

        final connection = {'uri': _globalVmServiceWsUri};
        final connArgs = jsonEncode({'connection': connection});

        // 1. semantic_snapshot — must succeed; provides refs.
        final snap = await exec(
          'semantic_snapshot',
          connArgs,
          requireOk: true,
        );
        final snapData = snap['data'] as Map<String, dynamic>;
        final refs = ((snapData['nodes'] as List?) ?? const [])
            .whereType<Map>()
            .map((final n) => '${n['ref'] ?? ''}')
            .where((final r) => r.isNotEmpty)
            .toList();
        expect(refs, isNotEmpty);
        final snapshotId = snapData['snapshot_id'] as int?;
        final firstRef = refs.first;
        final secondRef = refs.length > 1 ? refs[1] : firstRef;

        // 2. inspector / VM / discovery — must succeed.
        await exec('get_vm', '{}', requireOk: true);
        await exec('get_extension_rpcs', '{}', requireOk: true);
        await exec('discover_debug_apps', '{}', requireOk: true);
        await exec('get_app_errors', {'count': 1}, requireOk: true);
        await exec('get_view_details', '{}', requireOk: true);
        await exec(
          'get_screenshots',
          {
            'connection': connection,
            'compress': true,
            'mode': 'flutter_layer',
          },
          requireOk: true,
        );
        await exec(
          'capture_ui_snapshot',
          {
            'connection': connection,
            'errorsCount': 1,
            'compress': true,
            'includeViewDetails': true,
            'includeErrors': true,
            'screenshotMode': 'flutter_layer',
          },
          requireOk: true,
        );
        await exec('inspect_widget_at_point', {
          'x': 120,
          'y': 220,
          'connection': connection,
        }, requireOk: true);

        // 3. interaction layer.
        await exec('tap_widget', {
          'ref': firstRef,
          if (snapshotId != null) 'snapshotId': snapshotId,
          'connection': connection,
        });
        await exec('long_press', {
          'ref': firstRef,
          if (snapshotId != null) 'snapshotId': snapshotId,
          'connection': connection,
        });
        await exec('enter_text', {
          'ref': firstRef,
          'text': 'hi',
          if (snapshotId != null) 'snapshotId': snapshotId,
          'connection': connection,
        });
        await exec('scroll', {
          'direction': 'down',
          if (snapshotId != null) 'snapshotId': snapshotId,
          'connection': connection,
        });
        await exec('swipe', {
          'direction': 'up',
          if (snapshotId != null) 'snapshotId': snapshotId,
          'connection': connection,
        });
        await exec('drag', {
          'fromRef': firstRef,
          'toRef': secondRef,
          if (snapshotId != null) 'snapshotId': snapshotId,
          'connection': connection,
        });
        await exec('hover', {
          'ref': firstRef,
          if (snapshotId != null) 'snapshotId': snapshotId,
          'connection': connection,
        });
        await exec('press_key', {
          'key': 'Tab',
          'connection': connection,
        });

        // 4. control flow.
        await exec('handle_dialog', {
          'action': 'dismiss',
          'connection': connection,
        });
        await exec('navigate', {
          'action': 'pop',
          'connection': connection,
        });

        // 5. wait / forms.
        await exec(
          'wait_for',
          {
            'predicate': {'kind': 'time', 'ms': 50},
            'connection': connection,
          },
          requireOk: true,
        );
        await exec('fill_form', {
          'fields': <Map<String, Object?>>[
            {'ref': firstRef, 'text': 'a'},
          ],
          if (snapshotId != null) 'snapshotId': snapshotId,
          'connection': connection,
        });

        // 6. logs + runtime introspection.
        await exec(
          'get_recent_logs',
          {'connection': connection, 'count': 5},
          requireOk: true,
        );
        await exec(
          'evaluate_dart_expression',
          {'expression': '1 + 1', 'connection': connection},
          requireOk: true,
        );

        // 7. hot_reload_and_capture — must succeed.
        await exec(
          'hot_reload_and_capture',
          {'connection': connection, 'errorsCount': 1},
          requireOk: true,
        );

        // 8. hot_restart_flutter LAST (destructive — resets app state).
        await exec(
          'hot_restart_flutter',
          '{}',
          requireOk: true,
        );
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
      'exec',
      '--name',
      'connect',
      '--args',
      jsonEncode({'mode': 'uri', 'uri': vmServiceWsUri}),
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
    final result = await _runCli([
      'exec',
      '--name',
      'listClientToolsAndResources',
      '--args',
      '{}',
    ]);
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

String? _findResourceUri(
  final Map<String, dynamic> dynamicData, {
  required final String resourceName,
}) {
  final resources = (dynamicData['resources'] as List?) ?? const [];
  for (final resource in resources.whereType<Map>()) {
    final map = resource.cast<String, Object?>();
    final name = '${map['name'] ?? ''}'.trim();
    final uri = '${map['uri'] ?? ''}'.trim();
    if (name == resourceName && uri.isNotEmpty) {
      return uri;
    }
    if (uri.contains(resourceName)) {
      return uri;
    }
  }
  return null;
}

Map<String, dynamic>? _tryDecodeJsonMap(final String value) {
  try {
    final decoded = jsonDecode(value);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
    return null;
  } catch (_) {
    return null;
  }
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

List<String> _buildCliArgs(final List<String> args) {
  final fullArgs = <String>['run', 'bin/flutter_mcp_toolkit.dart'];

  final statePath = _stateFilePath;
  if (statePath != null && statePath.isNotEmpty) {
    fullArgs.addAll(['--state-file', statePath]);
  }

  final vmServiceUri = _globalVmServiceWsUri;
  final isExecConnect =
      args.length >= 3 &&
      args[0] == 'exec' &&
      args[1] == '--name' &&
      args[2] == 'connect';
  if (vmServiceUri != null && vmServiceUri.isNotEmpty && !isExecConnect) {
    fullArgs.addAll(['--vm-service-uri', vmServiceUri]);
  }

  fullArgs.addAll(args);
  return fullArgs;
}
