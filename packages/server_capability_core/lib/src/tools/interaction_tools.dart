// packages/server_capability_core/lib/src/tools/interaction_tools.dart
import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';

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
      inputSchema: tapWidgetInputSchema(),
      handler: (final args) async {
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
      inputSchema: enterTextInputSchema(),
      handler: (final args) async {
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
      name: 'reveal_search',
      description:
          'Find a semantic target that may be off-screen by taking a '
          'snapshot, matching one bounded selector, scrolling up to '
          'maxAttempts, and returning a fresh ref/snapshotId plus trace.',
      inputSchema: revealSearchInputSchema(),
      handler: (final args) async {
        final query = stringArgOrNull(args['query']) ?? '';
        final matchBy = stringArgOrNull(args['matchBy']) ?? 'text';
        final direction = stringArgOrNull(args['direction']) ?? 'down';
        final maxAttempts = switch (args['maxAttempts']) {
          final int value => value,
          final num value when value == value.toInt() => value.toInt(),
          _ => 5,
        };
        final distance = doubleArgOrDefault(args['distance'], 300.0);
        return runCommand(
          runner,
          args,
          RevealSearchCommand(
            query: query,
            matchBy: matchBy,
            direction: direction,
            maxAttempts: maxAttempts,
            distance: distance,
          ),
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
      inputSchema: scrollInputSchema(),
      handler: (final args) async {
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
      inputSchema: longPressInputSchema(),
      handler: (final args) async {
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
      inputSchema: swipeInputSchema(),
      handler: (final args) async {
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
      inputSchema: dragInputSchema(),
      handler: (final args) async {
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
          'Pass snapshotId to detect staleness.',
      inputSchema: hoverInputSchema(),
      handler: (final args) async {
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
      inputSchema: pressKeyInputSchema(),
      handler: (final args) async {
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
      inputSchema: evaluateDartExpressionInputSchema(),
      handler: (final args) async {
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
      inputSchema: hotReloadAndCaptureInputSchema(),
      handler: (final args) async {
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
