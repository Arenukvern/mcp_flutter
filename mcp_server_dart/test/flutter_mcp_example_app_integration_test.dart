import 'dart:async';
import 'dart:convert';
import 'dart:io';

// MCP harness constructs streams in start() and tears them down in dispose();
// the analyzer cannot connect those scopes.
// ignore_for_file: cancel_subscriptions, close_sinks

import 'package:test/test.dart';

void main() {
  final runIntegration =
      Platform.environment['RUN_FLUTTER_MCP_INTEGRATION'] == '1';

  group('flutter_inspector_mcp with flutter_test_app', () {
    late Process flutterProcess;
    late StreamSubscription<String> flutterStdoutSub;
    late StreamSubscription<String> flutterStderrSub;
    final vmServiceWsUriCompleter = Completer<String>();

    setUpAll(() async {
      if (!runIntegration) return;

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

      flutterStdoutSub = flutterProcess.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((final line) {
            stdout.writeln('[flutter_test_app] $line');
            final vmUri = _extractVmServiceWsUri(line);
            if (vmUri != null && !vmServiceWsUriCompleter.isCompleted) {
              vmServiceWsUriCompleter.complete(vmUri);
            }
          });

      flutterStderrSub = flutterProcess.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((final line) {
            stderr.writeln('[flutter_test_app:stderr] $line');
          });

      _globalVmServiceWsUri = await vmServiceWsUriCompleter.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () => throw TimeoutException(
          'Timed out waiting for VM service URI from flutter run output',
        ),
      );
    });

    tearDownAll(() async {
      if (!runIntegration) return;

      try {
        flutterProcess.stdin.writeln('q');
        await flutterProcess.exitCode.timeout(const Duration(seconds: 20));
      } on Exception catch (_) {
        flutterProcess.kill(ProcessSignal.sigkill);
      }

      await flutterStdoutSub.cancel();
      await flutterStderrSub.cancel();
      _globalVmServiceWsUri = null;
    });

    test(
      'new visual APIs work via MCP tools and resources',
      skip: runIntegration ? false : 'Set RUN_FLUTTER_MCP_INTEGRATION=1 to run',
      timeout: const Timeout(Duration(minutes: 8)),
      () async {
        final harness = await _McpHarness.start(
          workingDirectory: _serverDirectory().path,
        );
        addTearDown(harness.dispose);

        final init = await harness.request(
          method: 'initialize',
          params: {
            'protocolVersion': '2024-11-05',
            'capabilities': {
              'roots': {'listChanged': true},
              'sampling': {},
            },
            'clientInfo': {'name': 'integration-test', 'version': '1.0.0'},
          },
        );
        expect(init['error'], isNull);
        expect(init['result'], isA<Map>());

        final toolsList = await harness.request(method: 'tools/list');
        expect(toolsList['error'], isNull);
        final toolsResult = toolsList['result'] as Map<String, dynamic>;
        final toolNames = (toolsResult['tools'] as List)
            .whereType<Map>()
            .map((final tool) => '${tool['name']}')
            .toSet();
        // T8: tools surface under the "fmt_" capability prefix; the
        // dynamic-registry host machinery (runClientResource) stays
        // unprefixed.
        expect(toolNames.contains('fmt_discover_debug_apps'), isTrue);
        expect(toolNames.contains('fmt_capture_ui_snapshot'), isTrue);
        expect(toolNames.contains('fmt_inspect_widget_at_point'), isTrue);
        expect(toolNames.contains('runClientResource'), isTrue);

        final discover = await harness.request(
          method: 'tools/call',
          params: {
            'name': 'fmt_discover_debug_apps',
            'arguments': <String, Object?>{},
          },
        );
        final discoverData = _decodeToolJsonPayload(discover);
        expect((discoverData['targets'] as List?) ?? const [], isNotEmpty);

        final capture = await _callToolUntilSuccess(
          harness: harness,
          name: 'fmt_capture_ui_snapshot',
          arguments: {
            'connection': {'uri': _globalVmServiceWsUri},
            'errorsCount': 3,
            'includeViewDetails': true,
            'includeErrors': true,
            'compress': true,
            'screenshotMode': 'flutter_layer',
          },
        );
        final captureData = _decodeToolJsonPayload(capture);
        final captureSummary = captureData['summary'] as Map<String, dynamic>;
        expect(captureSummary['imageCount'], isA<int>());
        expect((captureSummary['imageCount'] as int) >= 1, isTrue);
        expect(captureData['viewDetails'], isNotNull);
        expect(captureData['appErrors'], isNotNull);

        final inspect = await harness.request(
          method: 'tools/call',
          params: {
            'name': 'fmt_inspect_widget_at_point',
            'arguments': {
              'x': 120,
              'y': 220,
              'connection': {'uri': _globalVmServiceWsUri},
            },
          },
        );
        final inspectData = _decodeToolJsonPayload(inspect);
        expect(inspectData['hit'], isA<bool>());
        expect(inspectData['summary'], isA<Map>());

        final dynamicList = await harness.request(
          method: 'tools/call',
          params: {
            'name': 'listClientToolsAndResources',
            'arguments': {
              'connection': {'uri': _globalVmServiceWsUri},
            },
          },
        );
        final dynamicData = _decodeToolJsonPayload(
          dynamicList,
          useLastText: true,
        );
        final appStateResourceUri = _findResourceUri(
          dynamicData,
          resourceName: 'app_state',
        );
        expect(appStateResourceUri, isNotNull);

        final runResource = await harness.request(
          method: 'tools/call',
          params: {
            'name': 'runClientResource',
            'arguments': {
              'resourceUri': appStateResourceUri,
              'connection': {'uri': _globalVmServiceWsUri},
            },
          },
        );
        final resourceText = _decodeFirstToolText(runResource);
        expect(resourceText.trim(), isNotEmpty);
        final decodedResource = _tryDecodeJsonMap(resourceText);
        expect(decodedResource, isNotNull);
        // The showcase's AgentState.snapshot() exposes counter, greeting,
        // toggle, slider, lastLog. Accept either an envelope-shaped
        // {parameters: {...}} payload or a raw snapshot map; either way
        // require at least one of those keys to be present (proof the
        // dynamic resource read forwarded the live state).
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
                'expected at least one of $agentSnapshotKeys in '
                'parameters, got: ${params.keys.toList()}',
          );
        } else {
          expect(
            agentSnapshotKeys.any(decodedResource.containsKey) ||
                decodedResource.containsKey('message'),
            isTrue,
          );
        }

        final encodedWs = Uri.encodeQueryComponent(_globalVmServiceWsUri!);
        final viewDetailsResource = await harness.request(
          method: 'resources/read',
          params: {'uri': 'visual://localhost/view/details?uri=$encodedWs'},
        );
        expect(viewDetailsResource['error'], isNull);
        final resourceResult =
            viewDetailsResource['result'] as Map<String, dynamic>;
        final contents = (resourceResult['contents'] as List)
            .whereType<Map>()
            .toList();
        expect(contents, isNotEmpty);
        final textContents = contents
            .map((final entry) => '${entry['text'] ?? ''}'.trim())
            .where((final text) => text.isNotEmpty)
            .toList();
        expect(textContents, isNotEmpty);

        Map<String, dynamic>? detailsPayload;
        for (final text in textContents) {
          detailsPayload = _tryDecodeJsonMap(text);
          if (detailsPayload != null) {
            break;
          }
        }

        if (detailsPayload != null) {
          expect(detailsPayload.isNotEmpty, isTrue);
        }
      },
    );

    test(
      'every fmt_* MCP tool dispatches against the live showcase',
      skip: runIntegration ? false : 'Set RUN_FLUTTER_MCP_INTEGRATION=1 to run',
      timeout: const Timeout(Duration(minutes: 12)),
      () async {
        // This test asserts wire-surface correctness: every prefixed tool can
        // be called and returns a well-formed JSON-RPC envelope. Tools that
        // cannot succeed against the showcase (no dialog open for
        // handle_dialog, no scrollable for scroll-without-ref, etc.) are
        // allowed to return a *structured* error envelope — the cut still
        // counts because dispatch and schema validation succeeded. We
        // distinguish that from transport-level errors (which would show up
        // as `response['error']` rather than `response['result']`).
        final harness = await _McpHarness.start(
          workingDirectory: _serverDirectory().path,
        );
        addTearDown(harness.dispose);

        await harness.request(
          method: 'initialize',
          params: {
            'protocolVersion': '2024-11-05',
            'capabilities': {
              'roots': {'listChanged': true},
              'sampling': {},
            },
            'clientInfo': {'name': 'all-tools-smoke', 'version': '1.0.0'},
          },
        );

        // Sanity: tools/list must contain every prefixed tool from the
        // locked surface (excluding `--dumps` ones since the harness does
        // not pass --dumps).
        final toolsList = await harness.request(method: 'tools/list');
        final names = ((toolsList['result'] as Map)['tools'] as List)
            .whereType<Map>()
            .map((final t) => '${t['name']}')
            .toSet();
        for (final expected in _expectedCoreTools) {
          expect(
            names,
            contains(expected),
            reason:
                '$expected must be present in tools/list under default config',
          );
        }

        final connection = {'uri': _globalVmServiceWsUri};

        // Helper: call by name, assert wire-shape, accept structured error.
        Future<Map<String, dynamic>> dispatch(
          final String name,
          final Map<String, Object?> arguments,
        ) async {
          final response = await harness.request(
            method: 'tools/call',
            params: {'name': name, 'arguments': arguments},
          );
          expect(
            response['error'],
            isNull,
            reason: '$name dispatch produced a JSON-RPC transport error',
          );
          expect(
            response['result'],
            isA<Map>(),
            reason: '$name response missing result',
          );
          return response;
        }

        // 1. semantic_snapshot — must succeed; provides refs for interaction
        // tools below.
        final snapResp = await dispatch('fmt_semantic_snapshot', {
          'connection': connection,
        });
        final snapData = _decodeToolJsonPayload(snapResp);
        final refs = ((snapData['nodes'] as List?) ?? const [])
            .whereType<Map>()
            .map((final n) => '${n['ref'] ?? ''}')
            .where((final r) => r.isNotEmpty)
            .toList();
        expect(
          refs,
          isNotEmpty,
          reason: 'showcase must expose at least one interactive ref',
        );
        final snapshotId = snapData['snapshot_id'] as int?;

        // 2. inspector / VM tools — all should succeed.
        await dispatch('fmt_get_vm', {'connection': connection});
        await dispatch('fmt_get_extension_rpcs', {'connection': connection});
        await dispatch('fmt_discover_debug_apps', {'connection': connection});
        await dispatch('fmt_connect_debug_app', {'connection': connection});

        // 3. inspection / capture tools.
        await dispatch('fmt_get_view_details', {'connection': connection});
        await dispatch('fmt_get_app_errors', {
          'connection': connection,
          'count': 1,
        });
        await dispatch('fmt_get_screenshots', {
          'connection': connection,
          'compress': true,
          'mode': 'flutter_layer',
        });
        await dispatch('fmt_capture_ui_snapshot', {
          'connection': connection,
          'errorsCount': 2,
          'compress': true,
          'includeViewDetails': true,
          'includeErrors': true,
          'screenshotMode': 'flutter_layer',
        });
        await dispatch('fmt_inspect_widget_at_point', {
          'x': 120,
          'y': 220,
          'connection': connection,
        });

        // 4. interaction layer — refs come from the snapshot above.
        final firstRef = refs.first;
        await dispatch('fmt_tap_widget', {
          'ref': firstRef,
          'snapshotId': ?snapshotId,
          'connection': connection,
        });
        await dispatch('fmt_long_press', {
          'ref': firstRef,
          'snapshotId': ?snapshotId,
          'connection': connection,
        });
        // enter_text needs a TextField ref — try the first ref; the showcase
        // exposes `greeting_input_field` as one of the early refs. Schema
        // validation succeeds either way; if the runtime says "not editable"
        // we still get a structured error envelope (acceptable).
        await dispatch('fmt_enter_text', {
          'ref': firstRef,
          'text': 'hello',
          'snapshotId': ?snapshotId,
          'connection': connection,
        });
        await dispatch('fmt_scroll', {
          'direction': 'down',
          'snapshotId': ?snapshotId,
          'connection': connection,
        });
        await dispatch('fmt_swipe', {
          'direction': 'up',
          'snapshotId': ?snapshotId,
          'connection': connection,
        });
        // drag needs two refs; if showcase only has one, reuse it (the call
        // returns a structured no-op or error which still validates wiring).
        final secondRef = refs.length > 1 ? refs[1] : firstRef;
        await dispatch('fmt_drag', {
          'fromRef': firstRef,
          'toRef': secondRef,
          'snapshotId': ?snapshotId,
          'connection': connection,
        });
        await dispatch('fmt_hover', {
          'ref': firstRef,
          'snapshotId': ?snapshotId,
          'connection': connection,
        });
        await dispatch('fmt_press_key', {
          'key': 'Tab',
          'connection': connection,
        });

        // 5. control flow — handle_dialog will likely error (no dialog open),
        // navigate may push/pop depending on showcase routes. Both still
        // exercise dispatch.
        await dispatch('fmt_handle_dialog', {
          'action': 'dismiss',
          'connection': connection,
        });
        await dispatch('fmt_navigate', {
          'action': 'pop',
          'connection': connection,
        });

        // 6. wait / forms — wait_for has a fast-time predicate.
        await dispatch('fmt_wait_for', {
          'predicate': {'kind': 'time', 'ms': 50},
          'connection': connection,
        });
        await dispatch('fmt_fill_form', {
          'fields': <Map<String, Object?>>[
            {'ref': firstRef, 'text': 'a'},
          ],
          'snapshotId': ?snapshotId,
          'connection': connection,
        });

        // 7. logs + runtime introspection.
        await dispatch('fmt_get_recent_logs', {
          'connection': connection,
          'count': 5,
        });
        await dispatch('fmt_evaluate_dart_expression', {
          'expression': '1 + 1',
          'connection': connection,
        });

        // 8. fused edit/preview — runs hot reload + capture.
        await dispatch('fmt_hot_reload_and_capture', {
          'connection': connection,
          'errorsCount': 2,
        });

        // 9. hot reload — non-destructive.
        await dispatch('fmt_hot_reload_flutter', {'connection': connection});

        // 10. hot restart — destructive (resets app state). MUST run last.
        // After this call, refs/snapshot are stale and other tools may not
        // behave as expected — acceptable since this is the final assertion.
        await dispatch('fmt_hot_restart_flutter', {'connection': connection});
      },
    );
  });
}

/// Locked v3.0.0 default-config tool surface (no `--dumps`). Mirrors
/// `tool/contracts/expected_tool_surface.txt`.
const _expectedCoreTools = <String>{
  'fmt_capture_ui_snapshot',
  'fmt_connect_debug_app',
  'fmt_discover_debug_apps',
  'fmt_drag',
  'fmt_enter_text',
  'fmt_evaluate_dart_expression',
  'fmt_fill_form',
  'fmt_get_app_errors',
  'fmt_get_extension_rpcs',
  'fmt_get_recent_logs',
  'fmt_get_screenshots',
  'fmt_get_view_details',
  'fmt_get_vm',
  'fmt_handle_dialog',
  'fmt_hot_reload_and_capture',
  'fmt_hot_reload_flutter',
  'fmt_hot_restart_flutter',
  'fmt_hover',
  'fmt_inspect_widget_at_point',
  'fmt_long_press',
  'fmt_navigate',
  'fmt_press_key',
  'fmt_scroll',
  'fmt_semantic_snapshot',
  'fmt_swipe',
  'fmt_tap_widget',
  'fmt_wait_for',
};

String? _globalVmServiceWsUri;

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

Map<String, dynamic> _decodeToolJsonPayload(
  final Map<String, dynamic> response, {
  final bool useLastText = false,
}) {
  final content = _extractToolContent(response);
  final textNodes = content
      .where((final c) => '${c['type']}' == 'text')
      .map((final c) => '${c['text'] ?? ''}')
      .where((final text) => text.trim().isNotEmpty)
      .toList();
  expect(textNodes, isNotEmpty);
  final selectedText = useLastText ? textNodes.last : textNodes.first;
  final decoded = _tryDecodeJsonMap(selectedText);
  expect(decoded, isNotNull);
  return decoded!;
}

String _decodeFirstToolText(final Map<String, dynamic> response) {
  final content = _extractToolContent(response);
  final textNodes = content
      .where((final c) => '${c['type']}' == 'text')
      .map((final c) => '${c['text'] ?? ''}')
      .where((final text) => text.trim().isNotEmpty)
      .toList();
  expect(textNodes, isNotEmpty);
  return textNodes.first;
}

List<Map<String, dynamic>> _extractToolContent(
  final Map<String, dynamic> response,
) {
  expect(response['error'], isNull);
  final result = response['result'] as Map<String, dynamic>;
  final isError = result['isError'] as bool?;
  final content = (result['content'] as List)
      .whereType<Map>()
      .map((final entry) => entry.cast<String, dynamic>())
      .toList();
  if (isError == true) {
    final errorText = content
        .map((final entry) => '${entry['text'] ?? entry['data'] ?? entry}')
        .join('\n')
        .trim();
    fail('MCP tool returned error payload: $errorText');
  }
  return content;
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
  } on Object catch (_) {
    return null;
  }
}

Future<Map<String, dynamic>> _callToolUntilSuccess({
  required final _McpHarness harness,
  required final String name,
  required final Map<String, Object?> arguments,
  final int maxAttempts = 4,
}) async {
  Map<String, dynamic>? lastResponse;
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    final response = await harness.request(
      method: 'tools/call',
      params: {'name': name, 'arguments': arguments},
    );
    lastResponse = response;
    final result = response['result'];
    final isError =
        result is Map<String, dynamic> && (result['isError'] as bool?) == true;
    if (!isError) {
      return response;
    }
    if (attempt < maxAttempts - 1) {
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  return lastResponse ?? <String, dynamic>{};
}

final class _McpHarness {
  _McpHarness._({
    required this.process,
    required this.requestController,
    required this.responses,
    required this.stdinSub,
    required this.stdoutSub,
    required this.stderrSub,
  });

  final Process process;
  final StreamController<String> requestController;
  final List<Map<String, dynamic>> responses;
  final StreamSubscription<String> stdinSub;
  final StreamSubscription<Map<String, dynamic>> stdoutSub;
  final StreamSubscription<String> stderrSub;
  int _nextId = 1;

  static Future<_McpHarness> start({
    required final String workingDirectory,
  }) async {
    final process = await Process.start('dart', [
      'run',
      'bin/flutter_mcp_toolkit_server.dart',
      '--dart-vm-host=localhost',
      '--dart-vm-port=8181',
      '--resources',
      '--images',
      '--dynamics',
    ], workingDirectory: workingDirectory);

    final requestController = StreamController<String>();
    final stdinSub = requestController.stream
        .map((final request) => '$request\n')
        .listen(process.stdin.write);

    final responses = <Map<String, dynamic>>[];
    final stdoutSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((final line) => line.trim().isNotEmpty)
        .map((final line) => jsonDecode(line) as Map<String, dynamic>)
        .listen(responses.add);

    final stderrSub = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((final line) {
          stderr.writeln('[mcp_server:stderr] $line');
        });

    await Future.delayed(const Duration(milliseconds: 600));
    return _McpHarness._(
      process: process,
      requestController: requestController,
      responses: responses,
      stdinSub: stdinSub,
      stdoutSub: stdoutSub,
      stderrSub: stderrSub,
    );
  }

  Future<Map<String, dynamic>> request({
    required final String method,
    final Map<String, Object?>? params,
  }) {
    final id = _nextId++;
    final requestEnvelope = <String, Object?>{
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params ?? <String, Object?>{},
    };

    requestController.add(jsonEncode(requestEnvelope));
    return _waitForResponse((final response) => response['id'] == id);
  }

  Future<Map<String, dynamic>> _waitForResponse(
    final bool Function(Map<String, dynamic>) predicate,
  ) async {
    final start = DateTime.now();
    const timeout = Duration(seconds: 45);
    const poll = Duration(milliseconds: 100);

    while (DateTime.now().difference(start) < timeout) {
      for (var i = 0; i < responses.length; i++) {
        final candidate = responses[i];
        if (predicate(candidate)) {
          return responses.removeAt(i);
        }
      }
      await Future.delayed(poll);
    }

    throw TimeoutException('Timed out waiting for MCP response');
  }

  Future<void> dispose() async {
    await stdinSub.cancel();
    await requestController.close();
    await stdoutSub.cancel();
    await stderrSub.cancel();
    try {
      await process.stdin.close();
    } on Object catch (_) {}
    process.kill();
    try {
      await process.exitCode.timeout(const Duration(seconds: 8));
    } on TimeoutException catch (_) {
      process.kill(ProcessSignal.sigkill);
    }
  }
}
