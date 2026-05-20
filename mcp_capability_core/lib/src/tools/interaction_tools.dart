// mcp_capability_core/lib/src/tools/interaction_tools.dart
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';
import 'package:mcp_shared_core/mcp_shared_core.dart';

import '_internal/handler_helpers.dart';

/// Registers Playwright-parity interaction tools with the host through
/// [context]. Registers: tap_widget, enter_text, scroll, long_press, swipe,
/// drag, hover, press_key, evaluate_dart_expression, hot_reload_and_capture.
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
        final ref = stringArgOrNull(args['ref']) ?? '';
        final snapshotId = intArgOrNull(args['snapshotId']);
        return runCommand(
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
        final ref = stringArgOrNull(args['ref']) ?? '';
        final text = stringArgOrNull(args['text']) ?? '';
        final snapshotId = intArgOrNull(args['snapshotId']);
        return runCommand(
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
        final direction = stringArgOrNull(args['direction']) ?? 'down';
        final ref = stringArgOrNull(args['ref']);
        final distance = doubleArgOrDefault(args['distance'], 300.0);
        final snapshotId = intArgOrNull(args['snapshotId']);
        return runCommand(
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
        final ref = stringArgOrNull(args['ref']) ?? '';
        final snapshotId = intArgOrNull(args['snapshotId']);
        return runCommand(
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
        final direction = stringArgOrNull(args['direction']) ?? 'up';
        final ref = stringArgOrNull(args['ref']);
        final distance = doubleArgOrDefault(args['distance'], 300.0);
        final snapshotId = intArgOrNull(args['snapshotId']);
        return runCommand(
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
        final fromRef = stringArgOrNull(args['fromRef']) ?? '';
        final toRef = stringArgOrNull(args['toRef']) ?? '';
        final snapshotId = intArgOrNull(args['snapshotId']);
        return runCommand(
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
        final ref = stringArgOrNull(args['ref']) ?? '';
        final snapshotId = intArgOrNull(args['snapshotId']);
        return runCommand(
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
        final key = stringArgOrNull(args['key']) ?? '';
        final ctrl = boolArgOrFalse(args['ctrl']);
        final shift = boolArgOrFalse(args['shift']);
        final alt = boolArgOrFalse(args['alt']);
        final meta = boolArgOrFalse(args['meta']);
        return runCommand(
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

  // ─────────────────────────────────────────────────────────────────────────
  // evaluate_dart_expression
  //
  // Run an arbitrary Dart expression in the running app's main isolate and
  // return its evaluated value. Required arg: `expression`.
  // ─────────────────────────────────────────────────────────────────────────
  context.registerTool(
    ToolRegistration(
      name: 'evaluate_dart_expression',
      description:
          'Evaluate a Dart expression in the running app isolate. '
          'Returns the result of the expression as text.',
      inputSchema: <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'required': <String>['expression'],
        'properties': <String, Object?>{
          'expression': <String, Object?>{
            'type': 'string',
            'description':
                'Dart expression to evaluate (e.g. "MyClass.instance.value").',
          },
          'libraryUri': <String, Object?>{
            'type': 'string',
            'description':
                'Optional library URI for evaluation scope '
                '(e.g. package:myapp/main.dart). Defaults to root library.',
          },
          'connection': connectionOverrideJsonSchema(),
        },
      },
      handler: (final request) async {
        final args = request.arguments ?? const <String, Object?>{};
        final expression = stringArgOrNull(args['expression']) ?? '';
        return runCommand(
          runner,
          args,
          EvaluateDartExpressionCommand(
            expression: expression,
            libraryUri: stringArgOrNull(args['libraryUri']),
          ),
        );
      },
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // hot_reload_and_capture
  //
  // Tight edit-preview cycle for AI iteration: hot reload, then capture
  // screenshot + semantic snapshot + errors in one response. All four
  // optional args default to "include": compress=true, includeSemantics=true,
  // includeErrors=true, errorsCount=4.
  // ─────────────────────────────────────────────────────────────────────────
  context.registerTool(
    ToolRegistration(
      name: 'hot_reload_and_capture',
      description:
          'Hot reload then capture screenshot + semantic snapshot + errors '
          'in a single call. Tight edit-preview cycle for AI iteration.',
      inputSchema: <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'properties': <String, Object?>{
          'compress': <String, Object?>{
            'type': 'boolean',
            'description': 'Compress screenshots (default: true).',
          },
          'includeSemantics': <String, Object?>{
            'type': 'boolean',
            'description': 'Include semantic snapshot (default: true).',
          },
          'includeErrors': <String, Object?>{
            'type': 'boolean',
            'description': 'Include app errors (default: true).',
          },
          'errorsCount': <String, Object?>{
            'type': 'integer',
            'description': 'Number of errors to include (default: 4).',
          },
          'connection': connectionOverrideJsonSchema(),
        },
      },
      handler: (final request) async {
        final args = request.arguments ?? const <String, Object?>{};
        final compress = boolArgOrDefault(args['compress'], defaultValue: true);
        final includeSemantics = boolArgOrDefault(
          args['includeSemantics'],
          defaultValue: true,
        );
        final includeErrors = boolArgOrDefault(
          args['includeErrors'],
          defaultValue: true,
        );
        final errorsCount = intArgOrDefault(
          args['errorsCount'],
          defaultValue: 4,
        );
        return runCommand(
          runner,
          args,
          HotReloadAndCaptureCommand(
            compress: compress,
            includeSemantics: includeSemantics,
            includeErrors: includeErrors,
            errorsCount: errorsCount,
          ),
        );
      },
    ),
  );
}
