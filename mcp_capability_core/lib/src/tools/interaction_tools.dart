// mcp_capability_core/lib/src/tools/interaction_tools.dart
import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:is_dart_empty_or_not/is_dart_empty_or_not.dart';
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';
import 'package:mcp_shared_core/mcp_shared_core.dart';

/// Registers Playwright-parity interaction tools with the host through
/// [context]. Currently registers `tap_widget`; remaining tools land in
/// follow-up dispatches (T4-B).
void registerInteractionTools(final CapabilityContext context) {
  final runner = context.require<CommandRunner>();

  context.registerTool(
    ToolRegistration(
      name: 'tap_widget',
      description:
          'Tap a widget identified by ref from semantic_snapshot. '
          'Refs are session-scoped to the most recent semantic_snapshot call.',
      inputSchema: <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'required': <String>['ref'],
        'properties': <String, Object?>{
          'ref': <String, Object?>{
            'type': 'string',
            'description': 'Widget ref from semantic_snapshot (e.g. "s_0").',
          },
          'snapshotId': <String, Object?>{
            'type': 'integer',
            'description':
                'Optional: snapshot_id returned by most recent '
                'semantic_snapshot. If provided and stale, the call fails '
                'with stale_snapshot.',
          },
          'connection': connectionOverrideJsonSchema(),
        },
      },
      handler: (final request) async {
        final args = request.arguments ?? const <String, Object?>{};

        // Apply per-call connection override before the main command.
        final connectError = await runner.applyConnectionOverride(args);
        if (connectError != null) {
          return _toErrorResult(connectError);
        }

        final ref = jsonDecodeString(args['ref']).whenEmptyUse('');
        final snapshotIdRaw = jsonDecodeInt(args['snapshotId']);
        final snapshotId = snapshotIdRaw == 0 ? null : snapshotIdRaw;

        final result = await runner.execute(
          TapWidgetCommand(ref: ref, snapshotId: snapshotId),
        );

        if (!result.ok) {
          return _toErrorResult(result);
        }

        return CallToolResult(
          content: [TextContent(text: jsonEncode(result.data))],
        );
      },
    ),
  );
}

/// Serialises a [CoreResult] failure to a structured MCP error result.
///
/// The text content is the JSON-encoded [CoreError] envelope:
/// `{code, message, details, descriptor, recovery}` — the shape that MCP
/// clients parse.
CallToolResult _toErrorResult(final CoreResult result) {
  final error = result.error;
  final errorJson = error != null
      ? error.toJson()
      : CoreResult.failure(
          code: CoreErrorCode.unknown,
          message: 'Unknown error',
        ).error!.toJson();
  return CallToolResult(
    isError: true,
    content: [TextContent(text: jsonEncode(errorJson))],
  );
}
