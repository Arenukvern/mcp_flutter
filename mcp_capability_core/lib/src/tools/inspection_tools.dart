// mcp_capability_core/lib/src/tools/inspection_tools.dart
// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';
import 'package:mcp_shared_core/mcp_shared_core.dart';

import '_internal/handler_helpers.dart';

/// Registers inspection tools with the host through [context].
/// Registers: get_view_details, inspect_widget_at_point, get_app_errors,
/// get_screenshots, capture_ui_snapshot.
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
            'description': 'Number of recent errors to retrieve (default: 4).',
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

  // ---------------------------------------------------------------------------
  // get_screenshots
  // ---------------------------------------------------------------------------
  // Legacy tool name: get_screenshots (resource_handler.dart:43).
  // NOTE: The toolkit VM extension is ext.mcp.toolkit.view_screenshots, but
  // the MCP-exposed tool name has always been get_screenshots. Preserving
  // legacy MCP name for T8 swap-out parity.
  //
  // Dual return shape (matching legacy resource_handler.dart getScreenshots):
  //   • data['fileUrls'] non-empty → TextContent per URL + meta fileUrls map.
  //   • else → ImageContent (base64 png) per entry in data['images'].
  //
  // NOTE: Legacy also gates this tool on configuration.imagesSupported.
  // That gating is NOT applied here — it is deferred to T4-E (wiring step)
  // which will plumb the flag into CapabilityConfig.
  context.registerTool(
    ToolRegistration(
      name: 'get_screenshots',
      description: 'Get screenshots of all views in the application.',
      inputSchema: <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'properties': <String, Object?>{
          'compress': <String, Object?>{
            'type': 'boolean',
            'description': 'Whether to compress the images (default: true).',
          },
          'mode': <String, Object?>{
            'type': 'string',
            'description':
                'Screenshot mode: auto, flutter_layer, or desktop_window '
                '(default: auto).',
          },
          'permissionPolicy': <String, Object?>{
            'type': 'string',
            'description':
                'Permission policy: check_only, auto_request_once, or '
                'request_always (default: check_only).',
          },
          'connection': connectionOverrideJsonSchema(),
        },
      },
      handler: (final request) async {
        final args = request.arguments ?? const <String, Object?>{};
        final compress = _boolArg(args['compress'], defaultValue: true);
        return runCommand(
          runner,
          args,
          GetScreenshotsCommand(
            compress: compress,
            mode: parseScreenshotMode(args['mode']),
            permissionPolicy: parsePermissionPolicy(args['permissionPolicy']),
          ),
          onSuccess: (final data) {
            final map = _asMap(data);
            final fileUrls = _stringList(map['fileUrls']);
            if (fileUrls.isNotEmpty) {
              // URL-based mode: return text references + meta.
              return CallToolResult(
                meta: Meta.fromMap({'fileUrls': fileUrls}),
                content: fileUrls
                    .map(
                      (final url) => TextContent(
                        text: 'Analyse with vision image by URL $url',
                      ),
                    )
                    .toList(),
              );
            }
            // Binary mode: return ImageContent blocks.
            final images = _stringList(map['images']);
            return CallToolResult(
              content: images
                  .map(
                    (final image) =>
                        ImageContent(data: image, mimeType: 'image/png'),
                  )
                  .toList(),
            );
          },
        );
      },
    ),
  );

  // ---------------------------------------------------------------------------
  // capture_ui_snapshot
  // ---------------------------------------------------------------------------
  // The "bundle" described in docs is JSON inside a single TextContent.
  // Legacy resource_handler.dart captureUiSnapshot (lines 472-474) returns
  //   CallToolResult(content: [TextContent(text: jsonEncode(result.data))]).
  // No multi-content transform required — standard runCommand with no onSuccess.
  context.registerTool(
    ToolRegistration(
      name: 'capture_ui_snapshot',
      description:
          'Capture screenshots, view details, and app errors in one response.',
      inputSchema: <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'properties': <String, Object?>{
          'errorsCount': <String, Object?>{
            'type': 'integer',
            'description': 'Number of recent errors to include (default: 4).',
          },
          'compress': <String, Object?>{
            'type': 'boolean',
            'description':
                'Whether screenshots should be compressed (default: true).',
          },
          'includeViewDetails': <String, Object?>{
            'type': 'boolean',
            'description': 'Include detailed view/widget data (default: true).',
          },
          'includeErrors': <String, Object?>{
            'type': 'boolean',
            'description': 'Include app errors (default: true).',
          },
          'screenshotMode': <String, Object?>{
            'type': 'string',
            'description':
                'Screenshot mode: auto, flutter_layer, or desktop_window '
                '(default: auto).',
          },
          'permissionPolicy': <String, Object?>{
            'type': 'string',
            'description':
                'Permission policy: check_only, auto_request_once, or '
                'request_always (default: check_only).',
          },
          'connection': connectionOverrideJsonSchema(),
        },
      },
      handler: (final request) async {
        final args = request.arguments ?? const <String, Object?>{};
        final errorsCount = intArgOrNull(args['errorsCount']) ?? 4;
        final compress = _boolArg(args['compress'], defaultValue: true);
        final includeViewDetails = _boolArg(
          args['includeViewDetails'],
          defaultValue: true,
        );
        final includeErrors = _boolArg(
          args['includeErrors'],
          defaultValue: true,
        );
        return runCommand(
          runner,
          args,
          CaptureUiSnapshotCommand(
            errorsCount: errorsCount,
            compress: compress,
            includeViewDetails: includeViewDetails,
            includeErrors: includeErrors,
            screenshotMode: parseScreenshotMode(args['screenshotMode']),
            permissionPolicy: parsePermissionPolicy(args['permissionPolicy']),
          ),
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// Local helpers for data unpacking.
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

/// Returns a flat list of strings from [raw] (which may be a `List<dynamic>`).
List<String> _stringList(final Object? raw) {
  if (raw is! List) return const <String>[];
  return raw.whereType<String>().toList(growable: false);
}

/// Parses a bool argument, accepting `bool` or `String` (case-insensitive).
/// Falls back to [defaultValue] when the value is absent or unrecognised.
bool _boolArg(final Object? raw, {required final bool defaultValue}) {
  if (raw is bool) return raw;
  if (raw is String) return raw.toLowerCase() != 'false';
  return defaultValue;
}
