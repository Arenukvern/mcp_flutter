// mcp_capability_core/lib/src/tools/interaction_tools.dart
import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:is_dart_empty_or_not/is_dart_empty_or_not.dart';
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';

const _extBase = 'ext.mcp.toolkit';

/// Registers Playwright-parity interaction tools with the host through
/// [context]. Currently registers `tap_widget`; remaining tools land in
/// follow-up dispatches (T4-B).
void registerInteractionTools(final CapabilityContext context) {
  final vmService = context.require<VmServiceClient>();

  context.registerTool(
    ToolRegistration(
      name: 'tap_widget',
      description:
          'Tap a widget identified by ref from semantic_snapshot. '
          'Refs are session-scoped to the most recent semantic_snapshot call.',
      inputSchema: const <String, Object?>{
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
        },
      },
      handler: (final request) async {
        final args = request.arguments ?? const <String, Object?>{};
        final ref = jsonDecodeString(args['ref']).whenEmptyUse('');
        final snapshotIdRaw = jsonDecodeInt(args['snapshotId']);
        final snapshotId = snapshotIdRaw == 0 ? null : snapshotIdRaw;

        try {
          final response = await vmService.callServiceExtension(
            '$_extBase.tap_widget',
            args: <String, Object?>{
              'ref': ref,
              'snapshotId': ?snapshotId,
            },
          );
          return CallToolResult(
            content: [TextContent(text: jsonEncode(response))],
          );
        } on Exception catch (e) {
          return CallToolResult(
            isError: true,
            content: [TextContent(text: 'Failed to tap widget: $e')],
          );
        }
      },
    ),
  );
}
