import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:universal_tooling_runtime/universal_tooling_runtime.dart';

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

  @override
  Future<LaunchedApp> launch({bool build = true}) async {
    if (!Platform.isLinux) {
      throw UnsupportedError('LinuxBoundedFlutterRunTarget is Linux-only');
    }

    final tap = LogTap();
    final vmUri = Completer<Uri>();
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
        unawaited(_consumeMachineOutput(handle, tap, vmUri));
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
        stopOverride: () => _stopBoundedSession(handle, boundedRun, tap),
      );
    } on Object catch (error, stack) {
      await _settleBoundedOnLaunchFailure(duplex, boundedRun, tap, error, stack);
      rethrow;
    }
  }

  static Future<void> _settleBoundedOnLaunchFailure(
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
        await _stopBoundedSession(handle, boundedRun, tap);
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

  static Future<int> _stopBoundedSession(
    BoundedDuplexHandle handle,
    Future<BoundedRunResult> boundedRun,
    LogTap tap,
  ) async {
    try {
      await handle.send(utf8.encode('q\n'));
    } on Object {
      // Cooperative quit may already be impossible; owner close still runs.
    }
    await handle.close();
    final settled = await boundedRun;
    tap.add(
      '[linux-machine-run] bounded stop cause=${settled.cause} ok=${settled.ok} '
      'physicallySettled=${settled.physicallySettled} '
      'survivors=${settled.survivors} settlementProblem=${settled.settlementProblem}',
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
    Completer<Uri> vmUri,
  ) async {
    await for (final frame in handle.output) {
      final line = utf8.decode(frame).trimRight();
      if (line.isEmpty) continue;
      tap.add(line);
      Uri? found;
      try {
        final decoded = jsonDecode(line);
        found = _wsUriFromMachinePayload(decoded);
      } on Object {
        found = _wsUriFromMachineLine(line);
      }
      if (found != null && !vmUri.isCompleted) {
        vmUri.complete(found);
      }
    }
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
