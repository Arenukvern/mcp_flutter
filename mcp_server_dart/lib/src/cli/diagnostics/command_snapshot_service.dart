// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// ignore_for_file: avoid_catching_errors

import 'package:flutter_mcp_toolkit_server/src/shared_core/command_executor.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/commands/commands.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/types/error_codes.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/types/results.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/vm_connections/connection_override.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/vm_connections/preconnect.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:intentcall_session/intentcall_session.dart';

/// Builds Flutter MCP command snapshots and stores them with [IntentSnapshotStore].
///
/// The persistence/diff substrate is reusable IntentCall code. This service
/// keeps the Flutter-specific command catalog, VM preconnect, and CoreResult
/// serialization in the Flutter MCP server.
final class CommandSnapshotService {
  CommandSnapshotService({required final String snapshotsDir})
    : snapshotStore = IntentSnapshotStore(snapshotsDir: snapshotsDir);

  CommandSnapshotService.withStore({required this.snapshotStore});

  final IntentSnapshotStore snapshotStore;

  Future<Map<String, Object?>> createSnapshot({
    required final String id,
    required final DefaultCoreCommandExecutor executor,
    required final CommandCatalog catalog,
    final Map<String, Object?> args = const <String, Object?>{},
    final SafeWriteOptions writeOptions = const SafeWriteOptions(),
  }) async {
    final createdAt = DateTime.now().toUtc();
    final plan = _resolvePlan(catalog: catalog, args: args);
    final results = <Map<String, Object?>>[];

    for (final step in plan) {
      final name = '${step['name'] ?? ''}';
      final stepArgs = _jsonObjectOrEmpty(step['args']);
      final argsResolution = resolveCommandArgumentsForExecution(
        commandName: name,
        arguments: stepArgs,
      );
      final argsError = argsResolution.error;
      if (argsError != null) {
        results.add({
          'name': name,
          'args': stepArgs,
          'result': argsError.toEnvelopeJson(),
        });
        continue;
      }

      final commandArgs = argsResolution.sanitizedArgs;
      final commandResult = _buildCommandSafely(
        catalog: catalog,
        name: name,
        args: commandArgs,
      );
      final command = commandResult.command;
      if (command == null) {
        results.add({
          'name': name,
          'args': commandArgs,
          'result': commandResult.failure!.toEnvelopeJson(),
        });
        continue;
      }

      final preconnectError = await preconnectForExecution(
        command: command,
        executor: executor,
        sessionManager: executor.sessionManager,
        explicitConnectionOverride: argsResolution.preconnectCommand,
      );
      final result = preconnectError ?? (await executor.execute(command));
      results.add({
        'name': name,
        'args': commandArgs,
        'result': result.toEnvelopeJson(),
      });
    }

    final snapshot = <String, Object?>{
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'args': args,
      'plan': plan,
      'results': results,
    };

    return snapshotStore.saveSnapshot(
      id: id,
      snapshot: snapshot,
      writeOptions: writeOptions,
    );
  }

  Future<Map<String, Object?>> loadSnapshot(final String id) =>
      snapshotStore.loadSnapshot(id);

  Future<List<Map<String, Object?>>> listSnapshots() =>
      snapshotStore.listSnapshots();

  Future<Map<String, Object?>> diffSnapshots({
    required final String fromId,
    required final String toId,
  }) => snapshotStore.diffSnapshots(fromId: fromId, toId: toId);

  List<Map<String, Object?>> _resolvePlan({
    required final CommandCatalog catalog,
    required final Map<String, Object?> args,
  }) {
    final providedPlan = _jsonListOrNull(args['commands']);
    final includeViewDetails = _bool(
      args['includeViewDetails'],
      fallback: true,
    );
    final errorCount = _intOrNull(args['errorCount']);

    if (providedPlan != null) {
      return providedPlan
          .map((final step) {
            final json = _jsonObjectOrEmpty(step);
            return <String, Object?>{
              'name': '${json['name'] ?? ''}',
              'args': _jsonObjectOrEmpty(json['args']),
            };
          })
          .where((final step) => catalog.contains('${step['name'] ?? ''}'))
          .toList();
    }

    final defaults = catalog.defaultSnapshotPlan
        .map(
          (final step) => {
            'name': '${step['name'] ?? ''}',
            'args': Map<String, Object?>.from(_jsonObjectOrEmpty(step['args'])),
          },
        )
        .toList();

    if (!includeViewDetails) {
      defaults.removeWhere((final step) => step['name'] == 'get_view_details');
    }

    if (errorCount != null) {
      for (final step in defaults) {
        if (step['name'] == 'get_app_errors') {
          final commandArgs = Map<String, Object?>.from(
            _jsonObjectOrEmpty(step['args']),
          );
          commandArgs['count'] = errorCount;
          step['args'] = commandArgs;
        }
      }
    }

    return defaults;
  }

  static ({CoreCommand? command, CoreResult? failure}) _buildCommandSafely({
    required final CommandCatalog catalog,
    required final String name,
    required final Map<String, Object?> args,
  }) {
    try {
      return (command: catalog.buildCommand(name, args), failure: null);
    } on ArgumentError catch (e) {
      return (
        command: null,
        failure: CoreResult.failure(
          code: CoreErrorCode.invalidCommand,
          message: '$e',
        ),
      );
    } on Exception catch (e) {
      return (
        command: null,
        failure: CoreResult.failure(
          code: CoreErrorCode.invalidCommand,
          message: 'Failed to build command for snapshot step "$name": $e',
        ),
      );
    }
  }

  static Map<String, Object?> _jsonObjectOrEmpty(final Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, Object?>();
    }
    try {
      return Map<String, Object?>.from(jsonDecodeMap(value));
    } on Exception {
      return const <String, Object?>{};
    }
  }

  static List<Object?>? _jsonListOrNull(final Object? value) {
    if (value == null) {
      return null;
    }
    if (value is List) {
      return value.cast<Object?>();
    }
    final decodableValue = value is String ? value.trim() : value;
    if (!verifyListDecodability(decodableValue)) {
      return null;
    }
    try {
      return jsonDecodeList(decodableValue).cast<Object?>();
    } on Exception {
      return null;
    }
  }

  static bool _bool(final Object? value, {required final bool fallback}) =>
      switch (value) {
        final bool v => v,
        final num v => v != 0,
        final String v => bool.tryParse(v) ?? fallback,
        _ => fallback,
      };

  static int? _intOrNull(final Object? value) => switch (value) {
    final int v => v,
    final num v => v.toInt(),
    final String v => int.tryParse(v),
    _ => null,
  };
}
