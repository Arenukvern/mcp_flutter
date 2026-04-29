// mcp_capability_core/lib/src/tools/interaction_tools.dart
import 'dart:convert';

import 'package:dart_mcp/server.dart';
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
        final ref = _stringArgOrNull(args['ref']) ?? '';
        final snapshotId = _intArgOrNull(args['snapshotId']);
        return _runCommand(
          runner,
          args,
          TapWidgetCommand(ref: ref, snapshotId: snapshotId),
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// Execution helpers — copy-pasteable template for T4-B tool migrations.
// ---------------------------------------------------------------------------

/// Standard envelope-preserving execution flow for capability tool handlers.
///
/// Apply per-call connection override → execute the command → translate the
/// CoreResult to a CallToolResult. Override failure short-circuits to the
/// error envelope. Use [onSuccess] for tools whose success payload is not a
/// JSON object (e.g., binary screenshot tools that need ImageContent).
Future<CallToolResult> _runCommand(
  final CommandRunner runner,
  final Map<String, Object?> arguments,
  final CoreCommand command, {
  final CallToolResult Function(Object? data)? onSuccess,
}) async {
  final overrideError = await runner.applyConnectionOverride(arguments);
  if (overrideError != null) return _toErrorResult(overrideError);
  final result = await runner.execute(command);
  if (!result.ok) return _toErrorResult(result);
  return onSuccess != null
      ? onSuccess(result.data)
      : CallToolResult(
          content: [TextContent(text: jsonEncode(result.data))],
        );
}

/// Serialises a [CoreResult] failure to a structured MCP error result.
///
/// The text content is the JSON-encoded [CoreError] envelope:
/// `{code, message, details, descriptor, recovery}` — the shape that MCP
/// clients parse.
CallToolResult _toErrorResult(final CoreResult result) => CallToolResult(
  isError: true,
  content: [TextContent(text: jsonEncode(result.toErrorEnvelopeJson()))],
);

// ---------------------------------------------------------------------------
// Argument coercion helpers.
// ---------------------------------------------------------------------------

/// Returns the string value of [raw] trimmed, or null if absent/non-string.
String? _stringArgOrNull(final Object? raw) {
  if (raw is! String) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Returns the int value of [raw], or null if absent, non-numeric, or zero.
///
/// Zero is treated as absent for legacy parity (`snapshotId == 0` means "not
/// provided" in the wire protocol).
int? _intArgOrNull(final Object? raw) {
  final value = switch (raw) {
    final int v => v,
    final num v when v == v.toInt() => v.toInt(),
    _ => null,
  };
  if (value == null || value == 0) return null;
  return value;
}
