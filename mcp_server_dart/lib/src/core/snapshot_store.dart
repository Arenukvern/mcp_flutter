// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:convert';
import 'dart:io' as io;

import 'package:collection/collection.dart';
import 'package:flutter_inspector_mcp_server/src/core/command_catalog.dart';
import 'package:flutter_inspector_mcp_server/src/core/commands.dart';
import 'package:flutter_inspector_mcp_server/src/core/connection_override.dart';
import 'package:flutter_inspector_mcp_server/src/core/error_codes.dart';
import 'package:flutter_inspector_mcp_server/src/core/executor.dart';
import 'package:flutter_inspector_mcp_server/src/core/preconnect.dart';
import 'package:flutter_inspector_mcp_server/src/core/results.dart';

final class SnapshotStore {
  SnapshotStore({required this.snapshotsDir});

  final String snapshotsDir;

  Future<Map<String, Object?>> createSnapshot({
    required final String id,
    required final DefaultCoreCommandExecutor executor,
    required final CommandCatalog catalog,
    final Map<String, Object?> args = const <String, Object?>{},
  }) async {
    final createdAt = DateTime.now().toUtc();
    final plan = _resolvePlan(catalog: catalog, args: args);
    final results = <Map<String, Object?>>[];

    for (final step in plan) {
      final name = '${step['name'] ?? ''}';
      final stepArgs = _asMap(step['args']);
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

    final file = _fileFor(id);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(snapshot),
    );

    return snapshot;
  }

  Future<Map<String, Object?>> loadSnapshot(final String id) async {
    final file = _fileFor(id);
    if (!file.existsSync()) {
      throw ArgumentError('Snapshot not found: $id');
    }

    final raw = file.readAsStringSync();
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.cast<String, Object?>();
    }

    throw StateError('Invalid snapshot payload: $id');
  }

  Future<List<Map<String, Object?>>> listSnapshots() async {
    final dir = io.Directory(snapshotsDir);
    if (!dir.existsSync()) {
      return const <Map<String, Object?>>[];
    }

    final entries = dir
        .listSync()
        .where(
          (final entity) => entity is io.File && entity.path.endsWith('.json'),
        )
        .cast<io.File>()
        .toList();

    entries.sort((final a, final b) => a.path.compareTo(b.path));

    final snapshots = <Map<String, Object?>>[];
    for (final file in entries) {
      try {
        final raw = file.readAsStringSync();
        final decoded = jsonDecode(raw);
        final json = _asMap(decoded);
        snapshots.add({
          'id': '${json['id'] ?? ''}',
          'createdAt': json['createdAt'],
          'path': file.path,
        });
      } on Exception {
        // Skip unreadable files.
      }
    }

    return snapshots;
  }

  Future<Map<String, Object?>> diffSnapshots({
    required final String fromId,
    required final String toId,
  }) async {
    final from = await loadSnapshot(fromId);
    final to = await loadSnapshot(toId);

    final changes = <Map<String, Object?>>[];
    _diffNode(path: r'$', left: from, right: to, out: changes);

    final summary = <String, Object?>{
      'totalChanges': changes.length,
      'added': changes
          .where((final change) => change['type'] == 'added')
          .length,
      'removed': changes
          .where((final change) => change['type'] == 'removed')
          .length,
      'changed': changes
          .where((final change) => change['type'] == 'changed')
          .length,
      'typeChanged': changes
          .where((final change) => change['type'] == 'type_changed')
          .length,
    };

    return {'from': fromId, 'to': toId, 'summary': summary, 'changes': changes};
  }

  List<Map<String, Object?>> _resolvePlan({
    required final CommandCatalog catalog,
    required final Map<String, Object?> args,
  }) {
    final providedPlan = args['commands'];
    final includeViewDetails = _bool(
      args['includeViewDetails'],
      fallback: true,
    );
    final errorCount = _intOrNull(args['errorCount']);

    if (providedPlan is List) {
      return providedPlan
          .map((final step) {
            final json = _asMap(step);
            return <String, Object?>{
              'name': '${json['name'] ?? ''}',
              'args': _asMap(json['args']),
            };
          })
          .where((final step) => catalog.contains('${step['name'] ?? ''}'))
          .toList();
    }

    final defaults = catalog.defaultSnapshotPlan
        .map(
          (final step) => {
            'name': '${step['name'] ?? ''}',
            'args': Map<String, Object?>.from(_asMap(step['args'])),
          },
        )
        .toList();

    if (!includeViewDetails) {
      defaults.removeWhere((final step) => step['name'] == 'get_view_details');
    }

    if (errorCount != null) {
      for (final step in defaults) {
        if (step['name'] == 'get_app_errors') {
          final commandArgs = Map<String, Object?>.from(_asMap(step['args']));
          commandArgs['count'] = errorCount;
          step['args'] = commandArgs;
        }
      }
    }

    return defaults;
  }

  io.File _fileFor(final String id) {
    final safe = id.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return io.File('$snapshotsDir/$safe.json');
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

  static Map<String, Object?> _asMap(final Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, Object?>();
    }
    return const <String, Object?>{};
  }

  static bool _bool(final Object? value, {required final bool fallback}) {
    return switch (value) {
      final bool v => v,
      final num v => v != 0,
      final String v => bool.tryParse(v) ?? fallback,
      _ => fallback,
    };
  }

  static int? _intOrNull(final Object? value) {
    return switch (value) {
      final int v => v,
      final num v => v.toInt(),
      final String v => int.tryParse(v),
      _ => null,
    };
  }

  static const _listEquality = DeepCollectionEquality();

  static void _diffNode({
    required final String path,
    required final Object? left,
    required final Object? right,
    required final List<Map<String, Object?>> out,
  }) {
    if (left == null && right == null) {
      return;
    }

    if (left == null) {
      out.add({'path': path, 'type': 'added', 'after': right});
      return;
    }

    if (right == null) {
      out.add({'path': path, 'type': 'removed', 'before': left});
      return;
    }

    if (left is Map && right is Map) {
      final leftMap = left.cast<String, Object?>();
      final rightMap = right.cast<String, Object?>();
      final allKeys = <String>{...leftMap.keys, ...rightMap.keys}.toList()
        ..sort();

      for (final key in allKeys) {
        _diffNode(
          path: '$path.$key',
          left: leftMap[key],
          right: rightMap[key],
          out: out,
        );
      }
      return;
    }

    if (left is List && right is List) {
      final maxLen = left.length > right.length ? left.length : right.length;
      for (var i = 0; i < maxLen; i += 1) {
        final nextLeft = i < left.length ? left[i] : null;
        final nextRight = i < right.length ? right[i] : null;
        _diffNode(
          path: '$path[$i]',
          left: nextLeft,
          right: nextRight,
          out: out,
        );
      }
      return;
    }

    if (left.runtimeType != right.runtimeType) {
      out.add({
        'path': path,
        'type': 'type_changed',
        'beforeType': left.runtimeType.toString(),
        'afterType': right.runtimeType.toString(),
        'before': left,
        'after': right,
      });
      return;
    }

    if (_listEquality.equals(left, right)) {
      return;
    }

    out.add({'path': path, 'type': 'changed', 'before': left, 'after': right});
  }
}
