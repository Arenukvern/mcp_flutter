// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// ignore_for_file: avoid_catches_without_on_clauses

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/core/core_types.dart';

final class FlutterMachineDiscoveryTarget {
  const FlutterMachineDiscoveryTarget({
    required this.vmServiceWsUri,
    this.dtdUri,
    this.sourceEvent,
  });

  final Uri vmServiceWsUri;
  final Uri? dtdUri;
  final String? sourceEvent;

  FlutterMachineDiscoveryTarget copyWith({
    final Uri? vmServiceWsUri,
    final Uri? dtdUri,
    final String? sourceEvent,
  }) {
    return FlutterMachineDiscoveryTarget(
      vmServiceWsUri: vmServiceWsUri ?? this.vmServiceWsUri,
      dtdUri: dtdUri ?? this.dtdUri,
      sourceEvent: sourceEvent ?? this.sourceEvent,
    );
  }
}

final class FlutterMachineEventData {
  const FlutterMachineEventData({
    this.eventName,
    this.vmServiceWsUri,
    this.dtdUri,
  });

  final String? eventName;
  final Uri? vmServiceWsUri;
  final Uri? dtdUri;
}

typedef FlutterAttachArgumentsBuilder = List<String> Function({String? device});
typedef FlutterMachineProcessLinesProvider = Future<List<String>> Function();

/// Discovers active Flutter debug VMs by parsing `flutter attach --machine`.
final class FlutterToolMachineDiscovery {
  const FlutterToolMachineDiscovery({
    required this.logger,
    this.flutterExecutable = 'flutter',
    this.attachArgumentsBuilder = _defaultAttachArgumentsBuilder,
    this.processLinesProvider = _defaultProcessLinesProvider,
    this.settleAfterFirstMatch = const Duration(milliseconds: 250),
  });

  final CoreLogger logger;
  final String flutterExecutable;
  final FlutterAttachArgumentsBuilder attachArgumentsBuilder;
  final FlutterMachineProcessLinesProvider processLinesProvider;
  final Duration settleAfterFirstMatch;

  Future<List<FlutterMachineDiscoveryTarget>> discover({
    final String? projectDir,
    final String? device,
    final Duration timeout = const Duration(milliseconds: 2500),
  }) async {
    final args = attachArgumentsBuilder(device: device?.trim());
    final byWsUri = <String, FlutterMachineDiscoveryTarget>{};
    final dtdByHostPort = <String, Uri>{};
    final stderrLines = <String>[];
    Process process;
    StreamSubscription<String>? stdoutSub;
    StreamSubscription<String>? stderrSub;
    Timer? settleTimer;
    final stopCompleter = Completer<void>();

    void scheduleStop() {
      settleTimer?.cancel();
      settleTimer = Timer(settleAfterFirstMatch, () {
        if (!stopCompleter.isCompleted) {
          stopCompleter.complete();
        }
      });
    }

    try {
      logger(
        LoggingLevel.debug,
        'Running flutter machine discovery: $flutterExecutable ${args.join(' ')}',
        logger: 'FlutterMachineDiscovery',
      );

      process = await Process.start(
        flutterExecutable,
        args,
        workingDirectory: _normalizePath(projectDir),
        runInShell: true,
      );
    } on Exception catch (e) {
      logger(
        LoggingLevel.warning,
        'Flutter machine discovery failed to start: $e',
        logger: 'FlutterMachineDiscovery',
      );
      return const <FlutterMachineDiscoveryTarget>[];
    }

    void handleMachineLine(final String line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        return;
      }

      final decoded = _decodeJsonMap(trimmed);
      if (decoded == null) {
        return;
      }

      final parsed = parseMachineEvent(decoded);
      final vmUri = parsed.vmServiceWsUri;
      final dtdUri = parsed.dtdUri;

      if (dtdUri != null) {
        final dtdHostPort = _hostPortKey(dtdUri);
        if (dtdHostPort != null) {
          dtdByHostPort[dtdHostPort] = dtdUri;
        }
      }

      if (vmUri == null) {
        return;
      }

      final key = vmUri.toString();
      final hostPort = _hostPortKey(vmUri);
      final linkedDtd =
          dtdUri ?? (hostPort == null ? null : dtdByHostPort[hostPort]);
      final existing = byWsUri[key];
      byWsUri[key] = existing == null
          ? FlutterMachineDiscoveryTarget(
              vmServiceWsUri: vmUri,
              dtdUri: linkedDtd,
              sourceEvent: parsed.eventName,
            )
          : existing.copyWith(
              dtdUri: existing.dtdUri ?? linkedDtd,
              sourceEvent: existing.sourceEvent ?? parsed.eventName,
            );

      scheduleStop();
    }

    stdoutSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(handleMachineLine);

    stderrSub = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((final line) {
          if (stderrLines.length < 8) {
            stderrLines.add(line.trim());
          }
        });

    try {
      await Future.any<void>([
        stopCompleter.future,
        process.exitCode.then((final _) {}),
        Future<void>.delayed(timeout),
      ]);
    } finally {
      await _requestStop(process);
      await stdoutSub.cancel();
      await stderrSub.cancel();
      settleTimer?.cancel();
    }

    final processDiscovered = await _discoverFromProcessMetadata();
    for (final target in processDiscovered) {
      byWsUri.putIfAbsent(target.vmServiceWsUri.toString(), () => target);
    }

    final discovered = byWsUri.values.toList()
      ..sort(
        (final a, final b) =>
            a.vmServiceWsUri.toString().compareTo(b.vmServiceWsUri.toString()),
      );

    if (discovered.isEmpty && stderrLines.isNotEmpty) {
      logger(
        LoggingLevel.debug,
        'Flutter machine discovery produced no VM URIs. stderr: '
        '${stderrLines.where((final line) => line.isNotEmpty).join(' | ')}',
        logger: 'FlutterMachineDiscovery',
      );
    }

    return discovered;
  }

  Future<List<FlutterMachineDiscoveryTarget>>
  _discoverFromProcessMetadata() async {
    try {
      final lines = await processLinesProvider();
      final byWsUri = <String, FlutterMachineDiscoveryTarget>{};
      for (final line in lines) {
        final target = parseProcessDiscoveryLine(line);
        if (target == null) {
          continue;
        }
        byWsUri.putIfAbsent(target.vmServiceWsUri.toString(), () => target);
      }
      return byWsUri.values.toList()..sort(
        (final a, final b) =>
            a.vmServiceWsUri.toString().compareTo(b.vmServiceWsUri.toString()),
      );
    } on Exception catch (e) {
      logger(
        LoggingLevel.debug,
        'Process metadata discovery failed: $e',
        logger: 'FlutterMachineDiscovery',
      );
      return const <FlutterMachineDiscoveryTarget>[];
    }
  }

  static FlutterMachineEventData parseMachineEvent(
    final Map<String, Object?> payload,
  ) {
    final eventName =
        _stringAtPath(payload, const <String>['event']) ??
        _stringAtPath(payload, const <String>['name']) ??
        _stringAtPath(payload, const <String>['method']);

    final vmUri = parseVmServiceWsUri(
      _firstNonEmpty(<String?>[
        _stringAtPath(payload, const <String>['params', 'wsUri']),
        _stringAtPath(payload, const <String>['params', 'debugPort', 'wsUri']),
        _stringAtPath(payload, const <String>[
          'params',
          'app',
          'debugPort',
          'wsUri',
        ]),
        _stringAtPath(payload, const <String>['app', 'debugPort', 'wsUri']),
        _stringAtPath(payload, const <String>['debugPort', 'wsUri']),
        _stringAtPath(payload, const <String>['wsUri']),
        _stringAtPath(payload, const <String>['vmServiceWsUri']),
      ]),
    );

    final lowerEventName = eventName?.toLowerCase() ?? '';
    final dtdUri = parseAnyUri(
      _firstNonEmpty(<String?>[
        _stringAtPath(payload, const <String>['params', 'dtdUri']),
        _stringAtPath(payload, const <String>['params', 'dtd', 'uri']),
        _stringAtPath(payload, const <String>['params', 'app', 'dtd', 'uri']),
        _stringAtPath(payload, const <String>['app', 'dtd', 'uri']),
        _stringAtPath(payload, const <String>['dtd', 'uri']),
        _stringAtPath(payload, const <String>['dtdUri']),
        if (lowerEventName.contains('dtd'))
          _stringAtPath(payload, const <String>['params', 'uri']),
        if (lowerEventName.contains('dtd'))
          _stringAtPath(payload, const <String>['uri']),
      ]),
    );

    return FlutterMachineEventData(
      eventName: eventName,
      vmServiceWsUri: vmUri,
      dtdUri: dtdUri,
    );
  }

  static FlutterMachineDiscoveryTarget? parseProcessDiscoveryLine(
    final String line,
  ) {
    final trimmed = line.trim();
    if (trimmed.isEmpty ||
        !trimmed.contains('development-service') ||
        !trimmed.contains('--vm-service-uri=')) {
      return null;
    }

    final vmUri = parseProcessVmServiceWsUri(trimmed);
    if (vmUri == null) {
      return null;
    }

    return FlutterMachineDiscoveryTarget(
      vmServiceWsUri: vmUri,
      sourceEvent: 'process.vmServiceUri',
    );
  }

  static Uri? parseProcessVmServiceWsUri(final String commandLine) {
    final match = RegExp(r'--vm-service-uri=([^\s]+)').firstMatch(commandLine);
    final rawValue = match?.group(1);
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }

    final parsed = parseAnyUri(rawValue);
    if (parsed == null) {
      return null;
    }

    final scheme = parsed.scheme.toLowerCase();
    if (scheme == 'ws' || scheme == 'wss') {
      return canonicalizeVmServiceWsUri(parsed);
    }
    if (scheme != 'http' && scheme != 'https') {
      return null;
    }

    final tokenSegments = parsed.pathSegments.where(
      (final segment) => segment.isNotEmpty,
    );
    if (tokenSegments.isEmpty) {
      return null;
    }

    return Uri(
      scheme: scheme == 'https' ? 'wss' : 'ws',
      host: parsed.host.toLowerCase(),
      port: parsed.hasPort ? parsed.port : 0,
      pathSegments: <String>[...tokenSegments, 'ws'],
    );
  }

  static Uri? parseVmServiceWsUri(final String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final parsed = Uri.tryParse(value.trim());
    if (parsed == null) {
      return null;
    }

    final scheme = parsed.scheme.toLowerCase();
    if ((scheme != 'ws' && scheme != 'wss') ||
        parsed.host.isEmpty ||
        !parsed.hasPort ||
        parsed.port <= 0) {
      return null;
    }

    return canonicalizeVmServiceWsUri(parsed);
  }

  static Uri canonicalizeVmServiceWsUri(final Uri uri) {
    final normalizedPath = _normalizeWsPath(uri.path);
    return uri.replace(
      scheme: uri.scheme.toLowerCase(),
      host: uri.host.toLowerCase(),
      path: normalizedPath,
    );
  }

  static Uri? parseAnyUri(final String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final parsed = Uri.tryParse(value.trim());
    if (parsed == null || parsed.scheme.isEmpty || parsed.host.isEmpty) {
      return null;
    }

    return parsed.replace(
      scheme: parsed.scheme.toLowerCase(),
      host: parsed.host.toLowerCase(),
    );
  }

  static List<String> _defaultAttachArgumentsBuilder({final String? device}) {
    final args = <String>['attach', '--machine'];
    final normalizedDevice = device?.trim();
    if (normalizedDevice != null && normalizedDevice.isNotEmpty) {
      args
        ..add('-d')
        ..add(normalizedDevice);
    }
    return args;
  }

  static Future<List<String>> _defaultProcessLinesProvider() async {
    if (!(Platform.isMacOS || Platform.isLinux)) {
      return const <String>[];
    }

    final result = await Process.run('ps', const <String>[
      '-wwaxo',
      'pid=,command=',
    ]);
    if (result.exitCode != 0) {
      return const <String>[];
    }

    return '${result.stdout}'
        .split('\n')
        .map((final line) => line.trimRight())
        .where((final line) => line.trim().isNotEmpty)
        .toList(growable: false);
  }

  static String _normalizeWsPath(final String path) {
    final rawPath = path.trim();
    if (rawPath.isEmpty) {
      return '/ws';
    }
    return rawPath.startsWith('/') ? rawPath : '/$rawPath';
  }

  static String? _normalizePath(final String? path) {
    if (path == null) {
      return null;
    }
    final trimmed = path.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static Map<String, Object?>? _decodeJsonMap(final String line) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is Map<String, Object?>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.cast<String, Object?>();
      }
    } on Exception {
      // Ignore non-JSON or malformed machine lines.
    }
    return null;
  }

  static String? _stringAtPath(final Object? root, final List<String> path) {
    Object? current = root;
    for (final segment in path) {
      if (current is! Map) {
        return null;
      }
      if (!current.containsKey(segment)) {
        return null;
      }
      current = current[segment];
    }

    if (current is! String) {
      return null;
    }

    final trimmed = current.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _firstNonEmpty(final List<String?> values) {
    for (final value in values) {
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static String? _hostPortKey(final Uri uri) {
    if (uri.host.isEmpty || !uri.hasPort || uri.port <= 0) {
      return null;
    }
    return '${uri.host.toLowerCase()}:${uri.port}';
  }

  Future<void> _requestStop(final Process process) async {
    try {
      process.stdin.writeln('q');
      await process.stdin.flush();
    } catch (_) {
      // Ignore stdin close/write errors.
    }

    await process.exitCode.timeout(
      const Duration(milliseconds: 400),
      onTimeout: () {
        process.kill();
        return process.exitCode.timeout(
          const Duration(milliseconds: 400),
          onTimeout: () {
            process.kill(ProcessSignal.sigkill);
            return -1;
          },
        );
      },
    );
  }
}
