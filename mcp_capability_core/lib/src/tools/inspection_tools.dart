// mcp_capability_core/lib/src/tools/inspection_tools.dart
// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';
import 'package:mcp_shared_core/mcp_shared_core.dart';

import '_internal/handler_helpers.dart';

/// Registers inspection tools with the host through [context].
/// Registers: get_view_details, inspect_widget_at_point, get_app_errors.
void registerInspectionTools(final CapabilityContext context) {
  final runner = context.require<CommandRunner>();

  context.registerTool(
    ToolRegistration(
      name: 'get_view_details',
      description: 'Get details for all views in the application.',
      inputSchema: <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'properties': <String, Object?>{
          'connection': connectionOverrideJsonSchema(),
        },
      },
      handler: (final request) async {
        final args = request.arguments ?? const <String, Object?>{};
        return runCommand(runner, args, const GetViewDetailsCommand());
      },
    ),
  );

  context.registerTool(
    ToolRegistration(
      name: 'inspect_widget_at_point',
      description:
          'Inspect the deepest widget at global logical coordinates (x, y).',
      inputSchema: <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'required': <String>['x', 'y'],
        'properties': <String, Object?>{
          'x': <String, Object?>{
            'type': 'integer',
            'description': 'Global logical X coordinate.',
          },
          'y': <String, Object?>{
            'type': 'integer',
            'description': 'Global logical Y coordinate.',
          },
          'viewId': <String, Object?>{
            'type': 'integer',
            'description': 'Optional FlutterView id for multi-view apps.',
          },
          'connection': connectionOverrideJsonSchema(),
        },
      },
      handler: (final request) async {
        final args = request.arguments ?? const <String, Object?>{};
        final x = intArgOrNull(args['x']) ?? 0;
        final y = intArgOrNull(args['y']) ?? 0;
        final viewId = intArgOrNull(args['viewId']);
        return runCommand(
          runner,
          args,
          InspectWidgetAtPointCommand(x: x, y: y, viewId: viewId),
        );
      },
    ),
  );

  context.registerTool(
    ToolRegistration(
      name: 'get_app_errors',
      description: 'Get the most recent application errors from Dart VM.',
      inputSchema: <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'properties': <String, Object?>{
          'count': <String, Object?>{
            'type': 'integer',
            'description':
                'Number of recent errors to retrieve (default: 4).',
          },
          'connection': connectionOverrideJsonSchema(),
        },
      },
      handler: (final request) async {
        final args = request.arguments ?? const <String, Object?>{};
        final countRaw = intArgOrNull(args['count']);
        final count = countRaw ?? 4;
        return runCommand(
          runner,
          args,
          GetAppErrorsCommand(count: count),
          onSuccess: (final data) {
            // Legacy parity: fan-out message + per-error TextContent blocks.
            final map = _asMap(data);
            final message = _stringFromMap(map, 'message') ?? 'No errors found';
            final errors = _errorsList(map['errors']);
            return CallToolResult(
              content: [
                TextContent(text: message),
                ...errors.map(
                  (final error) => TextContent(text: jsonEncode(error)),
                ),
              ],
            );
          },
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// Local helpers for get_app_errors data unpacking.
// ---------------------------------------------------------------------------

Map<String, Object?> _asMap(final Object? data) {
  if (data is Map<String, Object?>) return data;
  if (data is Map) return data.cast<String, Object?>();
  return const <String, Object?>{};
}

String? _stringFromMap(final Map<String, Object?> map, final String key) {
  final v = map[key];
  if (v is String && v.isNotEmpty) return v;
  return null;
}

List<Map<String, Object?>> _errorsList(final Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map<Map<String, Object?>>((final e) => e.cast<String, Object?>())
      .toList(growable: false);
}
