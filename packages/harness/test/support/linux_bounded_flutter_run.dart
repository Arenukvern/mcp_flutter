import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:universal_tooling_runtime/universal_tooling_runtime.dart';

import 'linux_machine_protocol.dart';
import 'session_settlement.dart';

/// Linux lifecycle owner via [runBounded] + `flutter run --machine` typed JSON.
final class LinuxBoundedFlutterRunTarget implements AppTarget {
  LinuxBoundedFlutterRunTarget({
    required this.projectDir,
    this.device = 'linux',
    this.extraArgs = const <String>[],
    this.environment = const <String, String>{},
    this.name = 'linux-machine-run',
    this.flutterBin = 'flutter',
    this.vmServiceTimeout = const Duration(minutes: 15),
    this.runDeadline = const Duration(hours: 2),
    this.stopGrace = const Duration(seconds: 8),
  });

  final String projectDir;
  final String device;
  final List<String> extraArgs;
  final Map<String, String> environment;
  final String name;
  final String flutterBin;
  final Duration vmServiceTimeout;
  final Duration runDeadline;
  final Duration stopGrace;

  BoundedSessionSettlement? lastSettlement;
  int _nextMachineRequestId = 1;
  Completer<bool>? _appStopAck;
  int? _lastAppStopRequestId;
  String? _lastMachineAppId;

  @override
  Future<LaunchedApp> launch({bool build = true}) async {
    if (!Platform.isLinux) {
      throw UnsupportedError('LinuxBoundedFlutterRunTarget is Linux-only');
    }

    final tap = LogTap();
    final vmUri = Completer<Uri>();
    String? machineAppId;
    BoundedDuplexHandle? duplex;
    late final Future<BoundedRunResult> boundedRun;
    boundedRun = runBounded(
      flutterBin,
      [
        'run',
        '-d',
        device,
        '--debug',
        '--machine',
        ...extraArgs,
      ],
      workingDirectory: projectDir,
      environment: environment.isEmpty
          ? null
          : <String, String>{...Platform.environment, ...environment},
      deadline: runDeadline,
      grace: stopGrace,
      onDuplexReady: (handle) {
        duplex = handle;
        unawaited(
          _consumeMachineOutput(
            handle,
            tap,
            vmUri,
            onAppId: (id) {
              machineAppId ??= id;
              _lastMachineAppId = id;
            },
            onMachinePayload: _onMachinePayload,
          ),
        );
      },
    );

    try {
      final wsUri = await vmUri.future.timeout(
        vmServiceTimeout,
        onTimeout: () => throw TimeoutException(
          'Timed out waiting for app.debugPort.wsUri from flutter --machine',
        ),
      );
      tap.add('[$name] vm wsUri=$wsUri');

      final handle = duplex;
      if (handle == null) {
        throw StateError('flutter run --machine duplex handle was not ready');
      }

      return LaunchedApp(
        name: name,
        process: null,
        stdout: tap,
        vmUri: wsUri,
        stopOverride: () =>
            _stopBoundedSession(this, handle, boundedRun, tap, machineAppId),
      );
    } on Object catch (error, stack) {
      await _settleBoundedOnLaunchFailure(
        this,
        duplex,
        boundedRun,
        tap,
        error,
        stack,
      );
      rethrow;
    }
  }

  static Future<void> _settleBoundedOnLaunchFailure(
    LinuxBoundedFlutterRunTarget owner,
    BoundedDuplexHandle? duplex,
    Future<BoundedRunResult> boundedRun,
    LogTap tap,
    Object error,
    StackTrace stack,
  ) async {
    tap.add('[$error] launch failed before wsUri: $error');
    final handle = duplex;
    if (handle != null) {
      try {
        await _stopBoundedSession(owner, handle, boundedRun, tap, null);
      } on Object catch (stopError) {
        tap.add('[linux-machine-run] launch-failure settle error: $stopError');
      }
    } else {
      final settled = await boundedRun;
      tap.add(
        '[linux-machine-run] launch-failure bounded exit without duplex: '
        'physicallySettled=${settled.physicallySettled} survivors=${settled.survivors}',
      );
    }
    Error.throwWithStackTrace(error, stack);
  }

  void _onMachinePayload(Map<String, Object?> payload) {
    final stopId = _lastAppStopRequestId;
    final completer = _appStopAck;
    if (stopId == null || completer == null || completer.isCompleted) {
      return;
    }
    final ack = machineAppStopAckFromPayload(
      payload,
      stopRequestId: stopId,
      expectedAppId: _lastMachineAppId,
    );
    if (ack == true) {
      completer.complete(true);
    } else if (ack == false) {
      completer.complete(false);
    }
  }

  static bool _replayStopAckFromTap(
    LogTap tap,
    int stopRequestId,
    String? expectedAppId,
  ) {
    for (final line in tap.lines.reversed.take(120)) {
      final ack = machineAppStopAckFromLine(
        line,
        stopRequestId: stopRequestId,
        expectedAppId: expectedAppId,
      );
      if (ack == true) return true;
      if (ack == false) return false;
    }
    return false;
  }

  static Future<int> _stopBoundedSession(
    LinuxBoundedFlutterRunTarget owner,
    BoundedDuplexHandle handle,
    Future<BoundedRunResult> boundedRun,
    LogTap tap,
    String? appId,
  ) async {
    var appStopAcknowledged = false;
    int? stopRequestId;
    if (appId != null && appId.isNotEmpty) {
      try {
        stopRequestId = owner._nextMachineRequestId++;
        owner._lastAppStopRequestId = stopRequestId;
        owner._appStopAck = Completer<bool>();
        final cmd = jsonEncode([
          {
            'id': stopRequestId,
            'method': 'app.stop',
            'params': {'appId': appId},
          },
        ]);
        await handle.send(utf8.encode('$cmd\n'));
        tap.add(
          '[linux-machine-run] app.stop id=$stopRequestId appId=$appId',
        );
        appStopAcknowledged = await owner._appStopAck!.future.timeout(
          owner.stopGrace,
          onTimeout: () {
            tap.add('[linux-machine-run] app.stop ack timeout id=$stopRequestId');
            return false;
          },
        );
        if (!appStopAcknowledged) {
          final recovered = _replayStopAckFromTap(
            tap,
            stopRequestId!,
            appId,
          );
          if (recovered) {
            appStopAcknowledged = true;
            tap.add(
              '[linux-machine-run] app.stop ack recovered from tap id=$stopRequestId',
            );
          }
        }
      } on Object catch (error) {
        tap.add('[linux-machine-run] app.stop failed: $error');
      } finally {
        owner._appStopAck = null;
      }
    } else {
      try {
        await handle.send(utf8.encode('q\n'));
        tap.add('[linux-machine-run] fallback stop sent q (no appId yet)');
      } on Object {
        // Cooperative quit may already be impossible; owner close still runs.
      }
    }
    await handle.close();
    final settled = await boundedRun;
    final cooperativeAckGap = stopRequestId != null &&
        !appStopAcknowledged &&
        settled.physicallySettled;
    owner.lastSettlement = BoundedSessionSettlement(
      exitCode: settled.exitCode,
      physicallySettled: settled.physicallySettled,
      survivors: List<String>.from(settled.survivors),
      cause: settled.cause.name,
      appStopAcknowledged: appStopAcknowledged,
      appStopRequestId: stopRequestId,
      cooperativeAckGap: cooperativeAckGap,
    );
    tap.add(
      '[linux-machine-run] bounded stop cause=${settled.cause} ok=${settled.ok} '
      'physicallySettled=${settled.physicallySettled} '
      'survivors=${settled.survivors} settlementProblem=${settled.settlementProblem} '
      'appStopAcknowledged=$appStopAcknowledged cooperativeAckGap=$cooperativeAckGap',
    );
    if (!settled.physicallySettled) {
      throw StateError(
        'flutter run session did not physically settle: '
        'survivors=${settled.survivors} '
        'settlementProblem=${settled.settlementProblem}',
      );
    }
    return settled.exitCode;
  }

  static Future<void> _consumeMachineOutput(
    BoundedDuplexHandle handle,
    LogTap tap,
    Completer<Uri> vmUri, {
    void Function(String appId)? onAppId,
    void Function(Map<String, Object?>)? onMachinePayload,
  }) async {
    await for (final frame in handle.output) {
      final line = utf8.decode(frame).trimRight();
      if (line.isEmpty) continue;
      tap.add(line);
      final payload = unwrapFlutterMachineLine(line);
      if (payload != null) {
        onMachinePayload?.call(payload);
      }
      Uri? found;
      String? appId;
      try {
        final decoded = jsonDecode(line);
        found = _wsUriFromMachinePayload(decoded);
        appId = _appIdFromMachinePayload(decoded);
      } on Object {
        found = _wsUriFromMachineLine(line);
      }
      if (appId != null && onAppId != null) {
        onAppId(appId);
      }
      if (found != null && !vmUri.isCompleted) {
        vmUri.complete(found);
      }
    }
  }

  static String? _appIdFromMachinePayload(Object? decoded) {
    if (decoded is List) {
      for (final item in decoded) {
        final found = _appIdFromMachinePayload(item);
        if (found != null) return found;
      }
      return null;
    }
    if (decoded is! Map) return null;
    final params = decoded['params'];
    if (params is Map) {
      final fromParams = params['appId'];
      if (fromParams is String && fromParams.isNotEmpty) return fromParams;
      final app = params['app'];
      if (app is Map) {
        final nested = app['appId'];
        if (nested is String && nested.isNotEmpty) return nested;
      }
    }
    final app = decoded['app'];
    if (app is Map) {
      final nested = app['appId'];
      if (nested is String && nested.isNotEmpty) return nested;
    }
    return null;
  }

  static Uri? _wsUriFromMachineLine(String line) {
    final match = RegExp(
      r'"wsUri"\s*:\s*"(wss?://[^"]+)"',
    ).firstMatch(line);
    return match == null ? null : Uri.parse(match.group(1)!);
  }

  static Uri? _wsUriFromMachinePayload(Object? decoded) {
    if (decoded is List) {
      for (final item in decoded) {
        final found = _wsUriFromMachinePayload(item);
        if (found != null) return found;
      }
      return null;
    }
    if (decoded is! Map) return null;
    final paths = <List<String>>[
      ['params', 'wsUri'],
      ['params', 'debugPort', 'wsUri'],
      ['params', 'app', 'debugPort', 'wsUri'],
      ['app', 'debugPort', 'wsUri'],
      ['debugPort', 'wsUri'],
      ['wsUri'],
    ];
    for (final path in paths) {
      Object? cursor = decoded;
      for (final key in path) {
        if (cursor is Map && cursor[key] != null) {
          cursor = cursor[key];
        } else {
          cursor = null;
          break;
        }
      }
      if (cursor is String && cursor.isNotEmpty) {
        return Uri.parse(cursor);
      }
    }
    return null;
  }
}
