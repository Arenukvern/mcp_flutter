// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// ignore_for_file: avoid_catches_without_on_clauses

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/types/core_types.dart';
import 'package:meta/meta.dart';

final class FlutterMachineDiscoveryTarget {
  const FlutterMachineDiscoveryTarget({
    required this.vmServiceWsUri,
    this.dtdUri,
    this.browserDebugPort,
    this.sourceEvent,
  });

  final Uri vmServiceWsUri;
  final Uri? dtdUri;

  /// Chrome `--remote-debugging-port` when emitted by `flutter run --machine`.
  final int? browserDebugPort;
  final String? sourceEvent;

  FlutterMachineDiscoveryTarget copyWith({
    final Uri? vmServiceWsUri,
    final Uri? dtdUri,
    final int? browserDebugPort,
    final String? sourceEvent,
  }) => FlutterMachineDiscoveryTarget(
    vmServiceWsUri: vmServiceWsUri ?? this.vmServiceWsUri,
    dtdUri: dtdUri ?? this.dtdUri,
    browserDebugPort: browserDebugPort ?? this.browserDebugPort,
    sourceEvent: sourceEvent ?? this.sourceEvent,
  );
}

final class FlutterMachineEventData {
  const FlutterMachineEventData({
    this.eventName,
    this.vmServiceWsUri,
    this.dtdUri,
    this.browserDebugPort,
  });

  final String? eventName;
  final Uri? vmServiceWsUri;
  final Uri? dtdUri;
  final int? browserDebugPort;
}

typedef FlutterAttachArgumentsBuilder = List<String> Function({String? device});
typedef FlutterMachineProcessLinesProvider = Future<List<String>> Function();
typedef FlutterMachineProcessStarter =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      bool runInShell,
    });

/// Discovers active Flutter debug VMs by parsing `flutter attach --machine`.
final class FlutterToolMachineDiscovery {
  const FlutterToolMachineDiscovery({
    required this.logger,
    this.flutterExecutable = 'flutter',
    this.attachArgumentsBuilder = _defaultAttachArgumentsBuilder,
    this.processLinesProvider = _defaultProcessLinesProvider,
    @visibleForTesting this.processStarter = _defaultProcessStarter,
    @visibleForTesting this.isWindows,
    this.settleAfterFirstMatch = const Duration(milliseconds: 250),
    @visibleForTesting this.stopTimeout = const Duration(milliseconds: 400),
    @visibleForTesting this.windowsTreeStopTimeout = const Duration(seconds: 5),
  });

  final CoreLogger logger;
  final String flutterExecutable;
  final FlutterAttachArgumentsBuilder attachArgumentsBuilder;
  final FlutterMachineProcessLinesProvider processLinesProvider;
  @visibleForTesting
  final FlutterMachineProcessStarter processStarter;

  @visibleForTesting
  final bool? isWindows;

  final Duration settleAfterFirstMatch;

  @visibleForTesting
  final Duration stopTimeout;

  @visibleForTesting
  final Duration windowsTreeStopTimeout;

  static final Expando<_DiscoveryCoordinator> _coordinators =
      Expando<_DiscoveryCoordinator>();

  Future<List<FlutterMachineDiscoveryTarget>> discover({
    final String? projectDir,
    final String? device,
    final Duration timeout = const Duration(milliseconds: 2500),
  }) {
    final key = (
      projectDir: projectDir,
      device: device?.trim(),
      timeout: timeout,
    );
    final coordinator = _coordinators[this] ??= _DiscoveryCoordinator();
    final pending = coordinator.pending[key];
    if (pending != null) {
      return pending;
    }

    final operation = coordinator.tail.then(
      (_) => _runDiscovery(
        projectDir: projectDir,
        device: device,
        timeout: timeout,
      ),
    );
    late final Future<List<FlutterMachineDiscoveryTarget>> tracked;
    tracked = operation.whenComplete(() {
      if (identical(coordinator.pending[key], tracked)) {
        coordinator.pending.remove(key)?.ignore();
      }
    });
    coordinator.pending[key] = tracked;
    coordinator.tail = operation.then<void>(
      (_) {},
      onError: (final Object _, final StackTrace _) {},
    );
    return tracked;
  }

  Future<List<FlutterMachineDiscoveryTarget>> _runDiscovery({
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

    late DateTime processStartedAfter;
    late DateTime processStartedBefore;
    try {
      logger(
        LoggingLevel.debug,
        'Running flutter machine discovery: $flutterExecutable ${args.join(' ')}',
        logger: 'FlutterMachineDiscovery',
      );

      processStartedAfter = DateTime.now().toUtc();
      process = await processStarter(
        flutterExecutable,
        args,
        workingDirectory: _normalizePath(projectDir),
        runInShell: true,
      );
      processStartedBefore = DateTime.now().toUtc();
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
      final browserDebugPort = parsed.browserDebugPort;

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
              browserDebugPort: browserDebugPort,
              sourceEvent: parsed.eventName,
            )
          : existing.copyWith(
              dtdUri: existing.dtdUri ?? linkedDtd,
              browserDebugPort: existing.browserDebugPort ?? browserDebugPort,
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
      await _requestStop(
        process,
        processStartedAfter: processStartedAfter,
        processStartedBefore: processStartedBefore,
      );
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

    final browserDebugPort = _parseBrowserDebugPort(payload);

    return FlutterMachineEventData(
      eventName: eventName,
      vmServiceWsUri: vmUri,
      dtdUri: dtdUri,
      browserDebugPort: browserDebugPort,
    );
  }

  static int? _parseBrowserDebugPort(final Map<String, Object?> payload) {
    final candidates = <Object?>[
      _objectAtPath(payload, const <String>['params', 'port']),
      _stringAtPath(payload, const <String>['params', 'port']),
      _stringAtPath(payload, const <String>['params', 'browserDebugPort']),
      _stringAtPath(payload, const <String>['params', 'chromeDebugPort']),
      _stringAtPath(payload, const <String>['params', 'debugPort', 'port']),
      _stringAtPath(payload, const <String>[
        'params',
        'app',
        'debugPort',
        'port',
      ]),
      _stringAtPath(payload, const <String>['port']),
    ];
    for (final value in candidates) {
      if (value is int && value > 0) {
        return value;
      }
      if (value is num && value > 0) {
        return value.toInt();
      }
      final parsed = int.tryParse('$value');
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }
    return null;
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

  static Future<Process> _defaultProcessStarter(
    final String executable,
    final List<String> arguments, {
    final String? workingDirectory,
    final bool runInShell = false,
  }) => Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    runInShell: runInShell,
  );

  Future<bool> _terminateWindowsProcessTree(
    final int pid, {
    required final DateTime processStartedAfter,
    required final DateTime processStartedBefore,
  }) => _runWindowsTerminator('powershell.exe', <String>[
    '-NoLogo',
    '-NoProfile',
    '-NonInteractive',
    '-ExecutionPolicy',
    'Bypass',
    '-Command',
    _windowsTreeTerminationScript(
      pid,
      processStartedAfter: processStartedAfter,
      processStartedBefore: processStartedBefore,
      expectedFlutterExecutable: flutterExecutable,
    ),
  ], timeout: windowsTreeStopTimeout);

  Future<bool> _runWindowsTerminator(
    final String executable,
    final List<String> arguments, {
    required final Duration timeout,
  }) async {
    Process terminatorProcess;
    try {
      terminatorProcess = await processStarter(
        executable,
        arguments,
        runInShell: false,
      );
    } on Exception {
      return false;
    }

    unawaited(terminatorProcess.stdout.drain<void>());
    unawaited(terminatorProcess.stderr.drain<void>());

    try {
      return await terminatorProcess.exitCode.timeout(timeout) == 0;
    } on TimeoutException {
      terminatorProcess.kill();
      try {
        await terminatorProcess.exitCode.timeout(stopTimeout);
      } on TimeoutException {
        terminatorProcess.kill(ProcessSignal.sigkill);
        await terminatorProcess.exitCode.timeout(
          stopTimeout,
          onTimeout: () => -1,
        );
      }
      return false;
    }
  }

  static String _windowsTreeTerminationScript(
    final int rootPid, {
    required final DateTime processStartedAfter,
    required final DateTime processStartedBefore,
    required final String expectedFlutterExecutable,
  }) =>
      r'''
$rootPid = __ROOT_PID__
$ErrorActionPreference = 'Stop'
$startedAfter = [DateTimeOffset]::Parse('__STARTED_AFTER__').UtcDateTime
$startedBefore = [DateTimeOffset]::Parse('__STARTED_BEFORE__').UtcDateTime
$flutterPattern = [regex]::Escape('__FLUTTER_EXECUTABLE__') +
  '(?:["'']?)\s+attach\s+--machine(?:\s|$)'
$all = @(Get-CimInstance Win32_Process -ErrorAction Stop)
$root = @($all | Where-Object { [int]$_.ProcessId -eq $rootPid }) |
  Select-Object -First 1
if ($null -eq $root) { exit 2 }
$rootCreated = ([DateTime]$root.CreationDate).ToUniversalTime()
$rootCommand = [string]$root.CommandLine
if ($root.Name -ne 'cmd.exe' -or
    $rootCreated -lt $startedAfter -or
    $rootCreated -gt $startedBefore -or
    $rootCommand -notmatch $flutterPattern) {
  exit 3
}

$rootHandle = Get-Process -Id $rootPid -ErrorAction Stop
$handleCreated = $rootHandle.StartTime.ToUniversalTime()
if ([Math]::Abs($handleCreated.Ticks - $rootCreated.Ticks) -gt 10) {
  exit 4
}
[void]$rootHandle.Handle

$lineage = @{$rootPid = [long]$rootCreated.Ticks}
$rootStoppedBefore = $null
function Add-Lineage([object[]]$processes, [DateTime]$latestCreation) {
  $processesById = @{}
  foreach ($process in $processes) {
    $processesById[[int]$process.ProcessId] = $process
  }
  $changed = $true
  while ($changed) {
    $changed = $false
    foreach ($process in $processes) {
      $processId = [int]$process.ProcessId
      $parentId = [int]$process.ParentProcessId
      if (-not $lineage.ContainsKey($parentId)) {
        continue
      }
      if ($processesById.ContainsKey($parentId)) {
        $parentProcess = $processesById[$parentId]
        $parentCreated = ([DateTime]$parentProcess.CreationDate).ToUniversalTime()
        if ([long]$parentCreated.Ticks -ne [long]$lineage[$parentId]) {
          continue
        }
      } elseif ($parentId -ne $rootPid -or $null -eq $rootStoppedBefore) {
        continue
      }
      $created = ([DateTime]$process.CreationDate).ToUniversalTime()
      if (-not $lineage.ContainsKey($processId) -and
          $created -ge $rootCreated -and
          $created -le $latestCreation) {
        $lineage[$processId] = [long]$created.Ticks
        $changed = $true
      }
    }
  }
}

Add-Lineage $all ([DateTime]::UtcNow)
$rootHandle.Kill()
if (-not $rootHandle.WaitForExit(2000)) { exit 5 }
$rootStoppedBefore = $rootHandle.ExitTime.ToUniversalTime()
$deadline = [DateTime]::UtcNow.AddSeconds(2)
$quietPasses = 0
while ([DateTime]::UtcNow -lt $deadline) {
  $all = @(Get-CimInstance Win32_Process -ErrorAction Stop)
  Add-Lineage $all $rootStoppedBefore
  $targets = @($all | Where-Object {
    $created = ([DateTime]$_.CreationDate).ToUniversalTime()
    $lineage.ContainsKey([int]$_.ProcessId) -and
    [long]$created.Ticks -eq [long]$lineage[[int]$_.ProcessId] -and
    $_.Name -in @('dart.exe', 'dartvm.exe') -and
    $created -ge $rootCreated -and
    $created -le $rootStoppedBefore -and
    $_.CommandLine -match 'flutter_tools\.snapshot.*attach\s+--machine(?:\s|$)'
  })
  if ($targets.Count -eq 0) {
    $quietPasses++
    if ($quietPasses -ge 2) { exit 0 }
    Start-Sleep -Milliseconds 100
    continue
  }

  $quietPasses = 0
  foreach ($target in $targets) {
    try {
      $targetHandle = Get-Process -Id ([int]$target.ProcessId) -ErrorAction Stop
      $targetCreated = ([DateTime]$target.CreationDate).ToUniversalTime()
      $targetHandleCreated = $targetHandle.StartTime.ToUniversalTime()
      if ([Math]::Abs(
            $targetHandleCreated.Ticks - $targetCreated.Ticks
          ) -gt 10) {
        continue
      }
      [void]$targetHandle.Handle
      $targetHandle.Kill()
      [void]$targetHandle.WaitForExit(500)
    } catch {
      continue
    }
  }
  Start-Sleep -Milliseconds 100
}
exit 6
'''
          .replaceAll('__ROOT_PID__', '$rootPid')
          .replaceAll(
            '__STARTED_AFTER__',
            processStartedAfter.toUtc().toIso8601String(),
          )
          .replaceAll(
            '__STARTED_BEFORE__',
            processStartedBefore.toUtc().toIso8601String(),
          )
          .replaceAll(
            '__FLUTTER_EXECUTABLE__',
            expectedFlutterExecutable.replaceAll("'", "''"),
          );

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

  static Object? _objectAtPath(final Object? root, final List<String> path) {
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
    return current;
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

  Future<void> _requestStop(
    final Process process, {
    required final DateTime processStartedAfter,
    required final DateTime processStartedBefore,
  }) async {
    if (isWindows ?? Platform.isWindows) {
      final terminatedTree = await _terminateWindowsProcessTree(
        process.pid,
        processStartedAfter: processStartedAfter,
        processStartedBefore: processStartedBefore,
      );
      if (terminatedTree) {
        await process.exitCode.timeout(stopTimeout, onTimeout: () => -1);
        return;
      }
      logger(
        LoggingLevel.warning,
        'Failed to terminate Flutter machine discovery process tree; '
        'falling back to a graceful stdin stop.',
        logger: 'FlutterMachineDiscovery',
      );
      try {
        process.stdin.writeln('q');
        await process.stdin.flush();
      } catch (_) {
        // Ignore stdin close/write errors during the safe fallback.
      }
      await process.exitCode.timeout(stopTimeout, onTimeout: () => -1);
      return;
    }

    try {
      process.stdin.writeln('q');
      await process.stdin.flush();
    } catch (_) {
      // Ignore stdin close/write errors.
    }

    await process.exitCode.timeout(
      stopTimeout,
      onTimeout: () {
        process.kill();
        return process.exitCode.timeout(
          stopTimeout,
          onTimeout: () {
            process.kill(ProcessSignal.sigkill);
            return -1;
          },
        );
      },
    );
  }
}

final class _DiscoveryCoordinator {
  final Map<
    ({String? projectDir, String? device, Duration timeout}),
    Future<List<FlutterMachineDiscoveryTarget>>
  >
  pending = {};

  Future<void> tail = Future<void>.value();
}
