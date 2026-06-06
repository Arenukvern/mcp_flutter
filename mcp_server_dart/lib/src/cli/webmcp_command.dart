import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/web_cdp_discovery.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Chromium flags to expose `navigator.modelContext` for WebMCP E2E (pre-stable).
///
/// Pass each via Flutter: `flutter run -d chrome --web-browser-flag="<flag>"`.
const kWebmcpChromeBrowserFlags = <String>[
  '--enable-features=WebModelContext',
  '--enable-experimental-web-platform-features',
];

/// One-line `flutter run` recipe for dogfood / docs.
String buildWebmcpFlutterRunCommand({
  final int webPort = 8080,
  final int vmHostPort = 8181,
  final String projectDir = '.',
}) {
  final flags = kWebmcpChromeBrowserFlags
      .map((final f) => ' --web-browser-flag="$f"')
      .join();
  return 'cd $projectDir && flutter run -d chrome --web-port=$webPort '
      '--host-vmservice-port=$vmHostPort --debug$flags';
}

/// JSON for `webmcp chrome-args`.
Map<String, Object?> webmcpChromeArgsJson({
  final int webPort = 8080,
  final int vmHostPort = 8181,
}) => <String, Object?>{
  'ok': true,
  'webPort': webPort,
  'vmHostPort': vmHostPort,
  'browserFlags': kWebmcpChromeBrowserFlags,
  'flutterRun': buildWebmcpFlutterRunCommand(
    webPort: webPort,
    vmHostPort: vmHostPort,
  ),
  'manualFlag': 'chrome://flags/#enable-webmcp-testing',
  'note':
      'Prefer flutter run --web-browser-flag above; manual flag persists in profile.',
};

Future<int> runWebmcpChromeArgs({
  final int webPort = 8080,
  final int vmHostPort = 8181,
}) async {
  stdout.writeln(
    jsonEncode(webmcpChromeArgsJson(webPort: webPort, vmHostPort: vmHostPort)),
  );
  return 0;
}

/// Probes live Chrome via CDP for `navigator.modelContext`.
Future<int> runWebmcpVerify({
  final int? cdpPort,
  final int preferredWebPort = 8080,
  final Duration timeout = const Duration(seconds: 8),
}) async {
  final ports = <int>{};
  if (cdpPort != null) {
    ports.add(cdpPort);
  }
  ports.addAll(await discoverChromeDebugPortsFromProcesses());
  if (ports.isEmpty) {
    ports.add(9222);
  }

  Map<String, Object?>? lastError;
  for (final port in ports) {
    final targets = await fetchCdpTargetList(port);
    if (targets.isEmpty) {
      lastError = <String, Object?>{'cdpPort': port, 'error': 'no_cdp_targets'};
      continue;
    }
    final page = selectCdpPageTarget(
      targets: targets,
      preferredWebPort: preferredWebPort,
    );
    final wsUrl = page == null ? null : parseCdpPageWebSocketUrl(page);
    if (wsUrl == null) {
      lastError = <String, Object?>{
        'cdpPort': port,
        'error': 'no_page_websocket',
      };
      continue;
    }

    final probe = await _cdpEvaluate(
      wsUrl: wsUrl,
      expression: '''
(() => {
  function probeNav(nav, source) {
    if (!nav) return null;
    const has = 'modelContext' in nav;
    const reg = has && typeof nav.modelContext.registerTool === 'function';
    let toolCount = null;
    if (has && typeof nav.modelContextTesting !== 'undefined' &&
        typeof nav.modelContextTesting.getTools === 'function') {
      try {
        toolCount = nav.modelContextTesting.getTools().length;
      } catch (e) {
        toolCount = -1;
      }
    }
    return { hasModelContext: has, registerTool: reg, testingToolCount: toolCount, source: source };
  }
  const candidates = [
    probeNav(globalThis.navigator, 'globalThis'),
    probeNav(window.navigator, 'window'),
    probeNav(document.defaultView && document.defaultView.navigator, 'defaultView'),
  ].filter(Boolean);
  for (const frame of Array.from(document.querySelectorAll('iframe'))) {
    try {
      candidates.push(probeNav(frame.contentWindow && frame.contentWindow.navigator, 'iframe'));
    } catch (e) {}
  }
  const active = candidates.find((p) => p.hasModelContext && p.registerTool) || candidates[0];
  return active || { hasModelContext: false, registerTool: false, testingToolCount: null, source: 'none' };
})()
''',
      timeout: timeout,
    );

    final cdpOk = probe != null && _probeIndicatesWebmcpActive(probe);
    final logEvidence = _webmcpLogEvidence();
    final ok = cdpOk || logEvidence;
    stdout.writeln(
      jsonEncode(<String, Object?>{
        'ok': ok,
        'cdpPort': port,
        'pageUrl': page?['url'],
        'probe': probe,
        'logEvidence': logEvidence,
        'verdict': cdpOk
            ? 'webmcp_active'
            : logEvidence
            ? 'webmcp_active_log_evidence'
            : 'webmcp_inactive',
        if (!ok) 'fix': buildWebmcpFlutterRunCommand(webPort: preferredWebPort),
      }),
    );
    return ok ? 0 : 1;
  }

  stdout.writeln(
    jsonEncode(<String, Object?>{
      'ok': false,
      'verdict': 'cdp_unreachable',
      'lastError': lastError,
      'fix': buildWebmcpFlutterRunCommand(webPort: preferredWebPort),
    }),
  );
  return 1;
}

Map<String, Object?>? _probeFromEvaluateResponse(
  final Map<String, Object?> response,
) {
  final value = response['result'];
  if (value is! Map) {
    return null;
  }
  final inner = value['result'];
  if (inner is! Map) {
    return null;
  }
  final raw = inner['value'];
  if (raw is Map) {
    return Map<String, Object?>.from(raw);
  }
  if (raw is String) {
    final parsed = jsonDecode(raw);
    if (parsed is Map) {
      return Map<String, Object?>.from(parsed);
    }
  }
  return null;
}

bool _probeIndicatesWebmcpActive(final Map<String, Object?>? probe) =>
    probe?['hasModelContext'] == true && probe?['registerTool'] == true;

/// Runtime log tail when CDP isolated-world probe misses Flutter's `window`.
bool _webmcpLogEvidence() {
  final candidates = <String>[
    '.showcase/web_app.log',
    '../.showcase/web_app.log',
  ];
  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) {
      continue;
    }
    final text = file.readAsStringSync();
    final hasApi =
        text.contains('ModelContext') || text.contains('modelContext');
    final hasRegister =
        text.contains('registerTool') || text.contains('Duplicate tool name');
    if (hasApi && hasRegister) {
      return true;
    }
  }
  return false;
}

Future<Map<String, Object?>?> _cdpEvaluate({
  required final Uri wsUrl,
  required final String expression,
  required final Duration timeout,
}) async {
  WebSocketChannel? channel;
  StreamSubscription<dynamic>? sub;
  try {
    channel = WebSocketChannel.connect(wsUrl);
    var id = 0;
    final pending = <int, Completer<Map<String, Object?>>>{};
    final contextIds = <int>[];
    sub = channel.stream.listen(
      (final event) {
        final decoded = jsonDecode(event as String);
        if (decoded is! Map) {
          return;
        }
        final method = decoded['method'];
        if (method == 'Runtime.executionContextCreated') {
          final params = decoded['params'];
          if (params is Map) {
            final ctx = params['context'];
            if (ctx is Map) {
              final ctxId = ctx['id'];
              final aux = ctx['auxData'];
              final isDefault = aux is Map && aux['isDefault'] == true;
              if (ctxId is int) {
                if (isDefault) {
                  contextIds.insert(0, ctxId);
                } else {
                  contextIds.add(ctxId);
                }
              }
            }
          }
          return;
        }
        final msgId = decoded['id'];
        if (msgId is! int) {
          return;
        }
        final completer = pending.remove(msgId);
        if (completer != null && !completer.isCompleted) {
          completer.complete(Map<String, Object?>.from(decoded));
        }
      },
      onError: (final Object e, final StackTrace st) {
        for (final c in pending.values) {
          if (!c.isCompleted) {
            c.completeError(e, st);
          }
        }
        pending.clear();
      },
    );

    Future<Map<String, Object?>> send(final Map<String, Object?> msg) {
      final myId = ++id;
      final completer = Completer<Map<String, Object?>>();
      pending[myId] = completer;
      channel!.sink.add(jsonEncode(<String, Object?>{...msg, 'id': myId}));
      return completer.future.timeout(timeout);
    }

    await send(<String, Object?>{'method': 'Runtime.enable', 'params': {}});
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final candidates = <int?>[...contextIds, null];
    Map<String, Object?>? best;
    for (final contextId in candidates) {
      final params = <String, Object?>{
        'expression': expression,
        'returnByValue': true,
        'awaitPromise': false,
        'contextId': ?contextId,
      };
      final result = await send(<String, Object?>{
        'method': 'Runtime.evaluate',
        'params': params,
      });
      final probe = _probeFromEvaluateResponse(result);
      if (probe == null) {
        continue;
      }
      if (_probeIndicatesWebmcpActive(probe)) {
        return probe;
      }
      best ??= probe;
    }
    return best;
  } on Exception {
    return null;
  } finally {
    await sub?.cancel();
    await channel?.sink.close();
  }
}
