// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_toolkit_server/src/shared_core/types/core_types.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/vm_connections/connection_context.dart';

/// Resolved Chrome DevTools Protocol endpoint for web tab capture.
final class WebCdpEndpoint {
  const WebCdpEndpoint({
    required this.debugPort,
    required this.pageWsUrl,
    this.pageUrl,
    this.discoverySource = 'unknown',
  });

  final int debugPort;
  final Uri pageWsUrl;
  final String? pageUrl;
  final String discoverySource;

  Map<String, Object?> toMetadata() => <String, Object?>{
    'cdpDebugPort': debugPort,
    if (pageUrl != null) 'pageUrl': pageUrl,
    'cdpDiscoverySource': discoverySource,
  };
}

/// Parses Chrome `--remote-debugging-port` values from process listings.
List<int> parseChromeDebugPortsFromProcessList(final String processListing) {
  final ports = <int>{};
  final pattern = RegExp(r'--remote-debugging-port=(\d+)');
  for (final match in pattern.allMatches(processListing)) {
    final port = int.tryParse(match.group(1) ?? '');
    if (port != null && port > 0 && port <= 65535) {
      ports.add(port);
    }
  }
  return ports.toList()..sort();
}

Future<List<int>> discoverChromeDebugPortsFromProcesses() async {
  if (Platform.isWindows) {
    return const <int>[];
  }
  try {
    // macOS truncates `args` without -ww; Chrome command lines exceed the limit.
    final result = Platform.isMacOS
        ? await Process.run('ps', const <String>['-ww', '-eo', 'args'])
        : await Process.run('ps', const <String>['-eo', 'args']);
    if (result.exitCode != 0) {
      return const <int>[];
    }
    final text = '${result.stdout}\n${result.stderr}';
    if (!text.toLowerCase().contains('chrom')) {
      return parseChromeDebugPortsFromProcessList(text);
    }
    return parseChromeDebugPortsFromProcessList(text);
  } on Exception {
    return const <int>[];
  }
}

bool isLoopbackHost(final String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '::1' ||
      normalized == '[::1]';
}

/// Fetches Chrome DevTools target list from `http://127.0.0.1:{port}/json/list`.
Future<List<Map<String, Object?>>> fetchCdpTargetList(final int port) async {
  if (port <= 0 || port > 65535) {
    return const <Map<String, Object?>>[];
  }
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      Uri.parse('http://127.0.0.1:$port/json/list'),
    );
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 3));
    if (response.statusCode != 200) {
      return const <Map<String, Object?>>[];
    }
    final body = await response.transform(utf8.decoder).join();
    final decoded = jsonDecode(body);
    if (decoded is! List) {
      return const <Map<String, Object?>>[];
    }
    return decoded
        .whereType<Map>()
        .map(Map<String, Object?>.from)
        .toList(growable: false);
  } on Exception {
    return const <Map<String, Object?>>[];
  } finally {
    client.close(force: true);
  }
}

Map<String, Object?>? selectCdpPageTarget({
  required final List<Map<String, Object?>> targets,
  final int? preferredWebPort,
}) {
  final pages = targets.where((final t) => '${t['type']}' == 'page').toList();
  if (pages.isEmpty) {
    return null;
  }

  Map<String, Object?>? best;
  var bestScore = -1;

  for (final page in pages) {
    final url = '${page['url'] ?? ''}';
    final ws = '${page['webSocketDebuggerUrl'] ?? ''}';
    if (ws.isEmpty) {
      continue;
    }
    var score = 0;
    if (url.contains('localhost') || url.contains('127.0.0.1')) {
      score += 2;
    }
    if (preferredWebPort != null &&
        url.contains(':$preferredWebPort') &&
        !url.contains('devtools')) {
      score += 5;
    }
    if (url.contains('flutter') || url.contains('dart')) {
      score += 1;
    }
    if (score > bestScore) {
      bestScore = score;
      best = page;
    }
  }

  return best ?? pages.first;
}

Uri? parseCdpPageWebSocketUrl(final Map<String, Object?> target) {
  final raw = target['webSocketDebuggerUrl']?.toString().trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(raw);
  if (uri == null || !isLoopbackHost(uri.host)) {
    return null;
  }
  return uri;
}

/// Discovery order: sticky target port, CLI override, process scan + HTTP verify.
Future<WebCdpEndpoint?> discoverWebCdpEndpoint({
  required final CoreRuntimeConfiguration configuration,
  final CoreConnectionTarget? connectionTarget,
  final List<int> extraCandidatePorts = const <int>[],
}) async {
  final candidates = <int>{};

  final stickyPort = connectionTarget?.browserDebugPort;
  if (stickyPort != null) {
    candidates.add(stickyPort);
  }

  final override = configuration.webBrowserDebuggingPort;
  if (override != null) {
    candidates.add(override);
  }

  candidates.addAll(extraCandidatePorts);
  candidates.addAll(await discoverChromeDebugPortsFromProcesses());

  for (final port in candidates) {
    final targets = await fetchCdpTargetList(port);
    final page = selectCdpPageTarget(
      targets: targets,
      preferredWebPort: configuration.webPort,
    );
    final pageWs = page == null ? null : parseCdpPageWebSocketUrl(page);
    if (pageWs == null) {
      continue;
    }
    return WebCdpEndpoint(
      debugPort: port,
      pageWsUrl: pageWs,
      pageUrl: page?['url']?.toString(),
      discoverySource: stickyPort == port
          ? 'connection_target'
          : override == port
          ? 'cli_override'
          : 'process_scan',
    );
  }

  return null;
}

/// Lightweight viability probe for broker permission checks.
Future<bool> isWebCdpCaptureViable({
  required final CoreRuntimeConfiguration configuration,
  final CoreConnectionTarget? connectionTarget,
}) async {
  final endpoint = await discoverWebCdpEndpoint(
    configuration: configuration,
    connectionTarget: connectionTarget,
  );
  return endpoint != null;
}

bool isWebFlutterDevice(final String? device) {
  switch (device) {
    case 'chrome':
    case 'web':
    case 'web-server':
      return true;
    default:
      return false;
  }
}
