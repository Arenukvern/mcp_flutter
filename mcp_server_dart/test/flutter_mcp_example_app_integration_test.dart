import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
      } catch (_) {
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
        expect(toolNames.contains('discover_debug_apps'), isTrue);
        expect(toolNames.contains('capture_ui_snapshot'), isTrue);
        expect(toolNames.contains('inspect_widget_at_point'), isTrue);
        expect(toolNames.contains('runClientResource'), isTrue);

        final discover = await harness.request(
          method: 'tools/call',
          params: {
            'name': 'discover_debug_apps',
            'arguments': <String, Object?>{},
          },
        );
        final discoverData = _decodeToolJsonPayload(discover);
        expect((discoverData['targets'] as List?) ?? const [], isNotEmpty);

        final capture = await _callToolUntilSuccess(
          harness: harness,
          name: 'capture_ui_snapshot',
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
            'name': 'inspect_widget_at_point',
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

        await _waitForClientTool(
          harness,
          toolName: 'live_edit_runtime_start_session',
        );

        final liveEditStart = await harness.request(
          method: 'tools/call',
          params: {
            'name': 'live_edit_start_session',
            'arguments': {'sessionId': 'live-edit-mcp'},
          },
        );
        final liveEditStartData = _decodeToolJsonPayload(liveEditStart);
        expect(liveEditStartData['sessionId'], 'live-edit-mcp');

        final liveEditTree = await harness.request(
          method: 'tools/call',
          params: {
            'name': 'live_edit_get_tree',
            'arguments': {'sessionId': 'live-edit-mcp'},
          },
        );
        final liveEditTreeData = _decodeToolJsonPayload(liveEditTree);
        expect(liveEditTreeData['tree'], isNotNull);

        Map<String, dynamic>? selection;
        Map<String, dynamic>? editableProperty;
        for (final point in _liveEditProbePoints) {
          final liveEditSelect = await harness.request(
            method: 'tools/call',
            params: {
              'name': 'live_edit_select_at_point',
              'arguments': {
                'sessionId': 'live-edit-mcp',
                'x': point['x'],
                'y': point['y'],
              },
            },
          );
          final liveEditSelectData = _decodeToolJsonPayload(liveEditSelect);
          if (liveEditSelectData['hit'] != true) {
            continue;
          }
          final candidateSelection = (liveEditSelectData['selection'] as Map)
              .cast<String, dynamic>();
          final candidateProperty = _pickEditableProperty(candidateSelection);
          if (candidateProperty != null) {
            selection = candidateSelection;
            editableProperty = candidateProperty;
            break;
          }
        }
        expect(selection, isNotNull, reason: 'No editable live-edit selection');
        expect(
          editableProperty,
          isNotNull,
          reason: 'No editable live-edit property found at probe points',
        );

        final liveEditSelection = await harness.request(
          method: 'tools/call',
          params: {
            'name': 'live_edit_get_selection',
            'arguments': {'sessionId': 'live-edit-mcp'},
          },
        );
        final liveEditSelectionData = _decodeToolJsonPayload(liveEditSelection);
        expect(liveEditSelectionData['hasSelection'], isTrue);

        final liveEditOverlay = await harness.request(
          method: 'tools/call',
          params: {
            'name': 'live_edit_set_overlay',
            'arguments': {'sessionId': 'live-edit-mcp', 'enabled': true},
          },
        );
        final liveEditOverlayData = _decodeToolJsonPayload(liveEditOverlay);
        expect(liveEditOverlayData['overlayEnabled'], isTrue);

        final liveEditUpdate = await harness.request(
          method: 'tools/call',
          params: {
            'name': 'live_edit_update_draft',
            'arguments': {
              'sessionId': 'live-edit-mcp',
              'change': {
                'nodeId': selection!['nodeId'],
                'propertyId': editableProperty!['id'],
                'targetValue': _draftTargetValue(editableProperty),
                'previewMode': editableProperty['previewMode'],
                'confidence': 0.8,
              },
            },
          },
        );
        final liveEditUpdateData = _decodeToolJsonPayload(liveEditUpdate);
        expect(liveEditUpdateData['updated'], isTrue);

        final liveEditDraft = await harness.request(
          method: 'tools/call',
          params: {
            'name': 'live_edit_get_draft',
            'arguments': {'sessionId': 'live-edit-mcp'},
          },
        );
        final liveEditDraftData = _decodeToolJsonPayload(liveEditDraft);
        expect(
          (liveEditDraftData['draftChanges'] as List?) ?? const [],
          isNotEmpty,
        );

        final backendList = await harness.request(
          method: 'tools/call',
          params: {
            'name': 'live_edit_list_agent_backends',
            'arguments': <String, Object?>{},
          },
        );
        final backendListData = _decodeToolJsonPayload(backendList);
        final defaultBackendId = '${backendListData['defaultBackendId'] ?? ''}'
            .trim();
        expect(defaultBackendId, isNotEmpty);
        expect((backendListData['backends'] as List?) ?? const [], isNotEmpty);

        final backendGet = await harness.request(
          method: 'tools/call',
          params: {
            'name': 'live_edit_get_agent_backend',
            'arguments': {'sessionId': 'live-edit-mcp'},
          },
        );
        final backendGetData = _decodeToolJsonPayload(backendGet);
        expect(backendGetData['backend'], isA<Map>());

        final backendSet = await harness.request(
          method: 'tools/call',
          params: {
            'name': 'live_edit_set_agent_backend',
            'arguments': {
              'sessionId': 'live-edit-mcp',
              'backendId': defaultBackendId,
            },
          },
        );
        final backendSetData = _decodeToolJsonPayload(backendSet);
        expect(
          (backendSetData['backend'] as Map)['id'] as String,
          defaultBackendId,
        );

        final liveEditDiscard = await harness.request(
          method: 'tools/call',
          params: {
            'name': 'live_edit_discard_draft',
            'arguments': {'sessionId': 'live-edit-mcp'},
          },
        );
        final liveEditDiscardData = _decodeToolJsonPayload(liveEditDiscard);
        expect(
          ((liveEditDiscardData['draftChanges'] as List?) ?? const []).isEmpty,
          isTrue,
        );

        final liveEditEnd = await harness.request(
          method: 'tools/call',
          params: {
            'name': 'live_edit_end_session',
            'arguments': {'sessionId': 'live-edit-mcp'},
          },
        );
        final liveEditEndData = _decodeToolJsonPayload(liveEditEnd);
        expect(liveEditEndData['ended'], isTrue);

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
        final parameters = decodedResource!['parameters'];
        if (parameters is Map) {
          final params = parameters.cast<String, dynamic>();
          expect(
            params.containsKey('appName') || params.containsKey('isConnected'),
            isTrue,
          );
        } else {
          expect(
            decodedResource.containsKey('appName') ||
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
  });
}

String? _globalVmServiceWsUri;

const List<Map<String, int>> _liveEditProbePoints = <Map<String, int>>[
  <String, int>{'x': 180, 'y': 400},
  <String, int>{'x': 150, 'y': 320},
  <String, int>{'x': 120, 'y': 220},
];

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
  } catch (_) {
    return null;
  }
}

Map<String, dynamic>? _pickEditableProperty(
  final Map<String, dynamic> selection,
) {
  final properties = (selection['properties'] as List?) ?? const [];
  for (final property in properties.whereType<Map>()) {
    final map = property.cast<String, dynamic>();
    if (map['editable'] == true) {
      return map;
    }
  }
  return null;
}

Object? _draftTargetValue(final Map<String, dynamic> property) {
  if (property['value'] != null) {
    return property['value'];
  }

  final kind = '${property['kind'] ?? ''}';
  switch (kind) {
    case 'boolean':
      return false;
    case 'integer':
    case 'number':
      return 0;
    case 'string':
      return '';
    case 'enum':
      final options = (property['options'] as List?) ?? const [];
      if (options.isNotEmpty) {
        return options.first;
      }
      return '';
    default:
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

Future<void> _waitForClientTool(
  final _McpHarness harness, {
  required final String toolName,
}) async {
  final start = DateTime.now();
  const timeout = Duration(seconds: 60);

  while (DateTime.now().difference(start) < timeout) {
    final response = await harness.request(
      method: 'tools/call',
      params: {
        'name': 'listClientToolsAndResources',
        'arguments': {
          'connection': {'uri': _globalVmServiceWsUri},
        },
      },
    );
    final data = _decodeToolJsonPayload(response, useLastText: true);
    final tools = (data['tools'] as List?) ?? const [];
    final names = tools
        .whereType<Map>()
        .map((final entry) => '${entry['name'] ?? ''}')
        .toSet();
    if (names.contains(toolName)) {
      return;
    }

    await Future.delayed(const Duration(seconds: 2));
  }

  fail('Dynamic tool $toolName did not appear in time');
}

final class _McpHarness {
  _McpHarness._({
    required this.process,
    required this.requestController,
    required this.responses,
    required this.stdoutSub,
    required this.stderrSub,
  });

  final Process process;
  final StreamController<String> requestController;
  final List<Map<String, dynamic>> responses;
  final StreamSubscription<Map<String, dynamic>> stdoutSub;
  final StreamSubscription<String> stderrSub;
  int _nextId = 1;

  static Future<_McpHarness> start({
    required final String workingDirectory,
  }) async {
    final process = await Process.start('dart', [
      'run',
      'bin/main.dart',
      '--dart-vm-host=localhost',
      '--dart-vm-port=8181',
      '--resources',
      '--images',
      '--dynamics',
    ], workingDirectory: workingDirectory);

    final requestController = StreamController<String>();
    requestController.stream
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
      stdoutSub: stdoutSub,
      stderrSub: stderrSub,
    );
  }

  Future<Map<String, dynamic>> request({
    required final String method,
    final Map<String, Object?>? params,
  }) async {
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
    await requestController.close();
    await stdoutSub.cancel();
    await stderrSub.cancel();
    process.kill();
    try {
      await process.exitCode.timeout(const Duration(seconds: 8));
    } catch (_) {
      process.kill(ProcessSignal.sigkill);
    }
  }
}
