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
        // T8: tools surface under the "core_" capability prefix; the
        // dynamic-registry host machinery (runClientResource) stays
        // unprefixed.
        expect(toolNames.contains('core_discover_debug_apps'), isTrue);
        expect(toolNames.contains('core_capture_ui_snapshot'), isTrue);
        expect(toolNames.contains('core_inspect_widget_at_point'), isTrue);
        expect(toolNames.contains('runClientResource'), isTrue);

        final discover = await harness.request(
          method: 'tools/call',
          params: {
            'name': 'core_discover_debug_apps',
            'arguments': <String, Object?>{},
          },
        );
        final discoverData = _decodeToolJsonPayload(discover);
        expect((discoverData['targets'] as List?) ?? const [], isNotEmpty);

        final capture = await _callToolUntilSuccess(
          harness: harness,
          name: 'core_capture_ui_snapshot',
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
            'name': 'core_inspect_widget_at_point',
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
