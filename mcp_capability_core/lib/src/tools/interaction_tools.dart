// mcp_capability_core/lib/src/tools/interaction_tools.dart
import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';
import 'package:mcp_shared_core/mcp_shared_core.dart';

/// Registers Playwright-parity interaction tools with the host through
/// [context]. Registers: tap_widget, enter_text, scroll, long_press, swipe,
/// drag, hover, press_key.
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

  context.registerTool(
    ToolRegistration(
      name: 'enter_text',
      description:
          'Enter text into a text field identified by ref from '
          'semantic_snapshot. Taps the field to focus before typing.',
      inputSchema: <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'required': <String>['ref', 'text'],
        'properties': <String, Object?>{
          'ref': <String, Object?>{
            'type': 'string',
            'description': 'Text field ref.',
          },
          'text': <String, Object?>{
            'type': 'string',
            'description': 'Text to enter.',
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
        final text = _stringArgOrNull(args['text']) ?? '';
        final snapshotId = _intArgOrNull(args['snapshotId']);
        return _runCommand(
          runner,
          args,
          EnterTextCommand(ref: ref, text: text, snapshotId: snapshotId),
        );
      },
    ),
  );

  context.registerTool(
    ToolRegistration(
      name: 'scroll',
      description:
          'Scroll to reveal content in a direction. "down" reveals content '
          'below (finger swipes up); "up" reveals content above. Matches '
          'Playwright and user language ("scroll down to see the footer").',
      inputSchema: <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'required': <String>['direction'],
        'properties': <String, Object?>{
          'direction': <String, Object?>{
            'type': 'string',
            'description': 'Scroll direction: up, down, left, right.',
          },
          'ref': <String, Object?>{
            'type': 'string',
            'description': 'Optional ref to scroll from.',
          },
          'distance': <String, Object?>{
            'type': 'number',
            'description': 'Scroll distance in logical pixels (default: 300).',
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
        final direction = _stringArgOrNull(args['direction']) ?? 'down';
        final ref = _stringArgOrNull(args['ref']);
        final distance = _doubleArgOrDefault(args['distance'], 300.0);
        final snapshotId = _intArgOrNull(args['snapshotId']);
        return _runCommand(
          runner,
          args,
          ScrollCommand(
            direction: direction,
            ref: ref,
            distance: distance,
            snapshotId: snapshotId,
          ),
        );
      },
    ),
  );

  context.registerTool(
    ToolRegistration(
      name: 'long_press',
      description: 'Long-press a widget identified by ref.',
      inputSchema: <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'required': <String>['ref'],
        'properties': <String, Object?>{
          'ref': <String, Object?>{
            'type': 'string',
            'description': 'Widget ref.',
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
          LongPressCommand(ref: ref, snapshotId: snapshotId),
        );
      },
    ),
  );

  context.registerTool(
    ToolRegistration(
      name: 'swipe',
      description:
          'Swipe to reveal content in a direction (higher pointer velocity '
          'than scroll; used for flings). "down" reveals content below.',
      inputSchema: <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'required': <String>['direction'],
        'properties': <String, Object?>{
          'direction': <String, Object?>{
            'type': 'string',
            'description': 'Swipe direction: up, down, left, right.',
          },
          'ref': <String, Object?>{
            'type': 'string',
            'description': 'Optional ref to swipe from.',
          },
          'distance': <String, Object?>{
            'type': 'number',
            'description': 'Swipe distance in logical pixels (default: 300).',
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
        final direction = _stringArgOrNull(args['direction']) ?? 'up';
        final ref = _stringArgOrNull(args['ref']);
        final distance = _doubleArgOrDefault(args['distance'], 300.0);
        final snapshotId = _intArgOrNull(args['snapshotId']);
        return _runCommand(
          runner,
          args,
          SwipeCommand(
            direction: direction,
            ref: ref,
            distance: distance,
            snapshotId: snapshotId,
          ),
        );
      },
    ),
  );

  context.registerTool(
    ToolRegistration(
      name: 'drag',
      description: 'Drag from one widget to another, identified by refs.',
      inputSchema: <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'required': <String>['fromRef', 'toRef'],
        'properties': <String, Object?>{
          'fromRef': <String, Object?>{
            'type': 'string',
            'description': 'Source widget ref.',
          },
          'toRef': <String, Object?>{
            'type': 'string',
            'description': 'Target widget ref.',
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
        final fromRef = _stringArgOrNull(args['fromRef']) ?? '';
        final toRef = _stringArgOrNull(args['toRef']) ?? '';
        final snapshotId = _intArgOrNull(args['snapshotId']);
        return _runCommand(
          runner,
          args,
          DragCommand(fromRef: fromRef, toRef: toRef, snapshotId: snapshotId),
        );
      },
    ),
  );

  context.registerTool(
    ToolRegistration(
      name: 'hover',
      description:
          'Synthesize a mouse hover at the centre of a widget identified '
          'by a semantic snapshot ref. Drives MouseRegion.onEnter/onExit '
          'and listeners on PointerHoverEvent. Requires a desktop or web '
          'host (mobile platforms have no hover concept). '
          'Call semantic_snapshot immediately before to get fresh refs. '
          'Pass snapshot_id to detect staleness.',
      inputSchema: <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'required': <String>['ref'],
        'properties': <String, Object?>{
          'ref': <String, Object?>{'type': 'string'},
          'snapshotId': <String, Object?>{'type': 'integer'},
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
          HoverCommand(ref: ref, snapshotId: snapshotId),
        );
      },
    ),
  );

  context.registerTool(
    ToolRegistration(
      name: 'press_key',
      description:
          'Synthesize a keyboard key press (down + up). Accepted keys: '
          'Enter, Escape, Tab, Backspace, Delete, Space, ArrowUp/Down/'
          'Left/Right, and single ASCII chars (a-z, 0-9). Optional '
          'modifiers: ctrl, shift, alt, meta.',
      inputSchema: <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'required': <String>['key'],
        'properties': <String, Object?>{
          'key': <String, Object?>{'type': 'string'},
          'ctrl': <String, Object?>{'type': 'boolean'},
          'shift': <String, Object?>{'type': 'boolean'},
          'alt': <String, Object?>{'type': 'boolean'},
          'meta': <String, Object?>{'type': 'boolean'},
          'connection': connectionOverrideJsonSchema(),
        },
      },
      handler: (final request) async {
        final args = request.arguments ?? const <String, Object?>{};
        final key = _stringArgOrNull(args['key']) ?? '';
        final ctrl = _boolArgOrFalse(args['ctrl']);
        final shift = _boolArgOrFalse(args['shift']);
        final alt = _boolArgOrFalse(args['alt']);
        final meta = _boolArgOrFalse(args['meta']);
        return _runCommand(
          runner,
          args,
          PressKeyCommand(
            key: key,
            ctrl: ctrl,
            shift: shift,
            alt: alt,
            meta: meta,
          ),
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

/// Returns the double value of [raw], or [defaultValue] if absent/non-numeric.
double _doubleArgOrDefault(final Object? raw, final double defaultValue) {
  if (raw == null) return defaultValue;
  if (raw is num) return raw.toDouble();
  return defaultValue;
}

/// Returns the bool value of [raw], or false if absent/non-bool.
bool _boolArgOrFalse(final Object? raw) {
  if (raw is bool) return raw;
  return false;
}
