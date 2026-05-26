import 'package:agentkit_core/agentkit_core.dart';
import 'package:dart_mcp/client.dart';
import 'package:from_json_to_json/from_json_to_json.dart';

import '../agent_entry_helpers.dart';
import '../mcp_models.dart';
import '../services/control_flow_service.dart';
import '../services/gesture_interaction_service.dart';
import '../services/log_capture_service.dart';
import '../services/semantic_snapshot_service.dart';
import '../services/wait_predicate_service.dart';

/// Returns the set of MCP entries for the interaction toolkit:
/// semantic snapshot, gestures, and log capture.
Set<AgentCallEntry> getInteractionToolkitEntries() => {
  OnSemanticSnapshotEntry(),
  OnTapWidgetEntry(),
  OnEnterTextEntry(),
  OnScrollEntry(),
  OnLongPressEntry(),
  OnSwipeEntry(),
  OnDragEntry(),
  OnGetRecentLogsEntry(),
  OnWaitForEntry(),
  OnPressKeyEntry(),
  OnHandleDialogEntry(),
  OnNavigateEntry(),
  OnHoverEntry(),
};

// ---------------------------------------------------------------------------
// Semantic snapshot
// ---------------------------------------------------------------------------

/// {@template on_semantic_snapshot_entry}
/// Captures a compact semantic tree of interactive widgets with refs.
/// {@endtemplate}
extension type OnSemanticSnapshotEntry._(AgentCallEntry entry)
    implements AgentCallEntry {
  /// {@macro on_semantic_snapshot_entry}
  factory OnSemanticSnapshotEntry() {
    final entry = mcpToolkitTool(
      handler: (final parameters) async {
        final snapshot = await SemanticSnapshotService.buildSemanticSnapshot();
        return MCPCallResult(
          message:
              'Semantic snapshot captured. Use refs to interact with widgets.',
          parameters: snapshot,
        );
      },
      definition: MCPToolDefinition(
        name: 'semantic_snapshot',
        description:
            'Get compact semantic tree of interactive widgets with refs '
            'for interaction tools (tap_widget, enter_text, etc.).',
        inputSchema: ObjectSchema(properties: {}),
      ),
    );
    return OnSemanticSnapshotEntry._(entry);
  }
}

// ---------------------------------------------------------------------------
// Tap widget
// ---------------------------------------------------------------------------

/// {@template on_tap_widget_entry}
/// Taps the widget identified by a semantic ref.
/// {@endtemplate}
extension type OnTapWidgetEntry._(AgentCallEntry entry) implements AgentCallEntry {
  /// {@macro on_tap_widget_entry}
  factory OnTapWidgetEntry() {
    final entry = mcpToolkitTool(
      handler: (final parameters) async {
        final ref = parameters['ref'] ?? '';
        if (ref.isEmpty) {
          return MCPCallResult(
            message: 'Missing required parameter "ref".',
            parameters: <String, dynamic>{'success': false},
          );
        }
        final snapshotIdRaw = jsonDecodeInt(parameters['snapshotId']);
        final snapshotId = snapshotIdRaw == 0 ? null : snapshotIdRaw;
        if (snapshotId != null &&
            snapshotId != SemanticSnapshotService.currentSnapshotId) {
          return MCPCallResult(
            message:
                'Snapshot is stale. Call semantic_snapshot to get fresh refs.',
            parameters: <String, dynamic>{
              'ok': false,
              'error': 'stale_snapshot',
              'providedSnapshotId': snapshotId,
              'currentSnapshotId': SemanticSnapshotService.currentSnapshotId,
            },
          );
        }
        final result = await GestureInteractionService.tapAtRef(ref);
        return MCPCallResult(
          message: result['success'] == true
              ? 'Tapped widget at ref "$ref".'
              : 'Tap failed: ${result['error']}',
          parameters: result,
        );
      },
      definition: MCPToolDefinition(
        name: 'tap_widget',
        description:
            'Tap the centre of a widget identified by a semantic snapshot ref. '
            'Call semantic_snapshot immediately before to get fresh refs. '
            'Pass snapshot_id to detect staleness.',
        inputSchema: ObjectSchema(
          required: ['ref'],
          properties: {
            'ref': StringSchema(
              description: 'Semantic ref string (e.g. "s_0")',
            ),
            'snapshotId': IntegerSchema(
              description: 'Optional snapshot_id - if stale, returns error',
            ),
          },
        ),
      ),
    );
    return OnTapWidgetEntry._(entry);
  }
}

// ---------------------------------------------------------------------------
// Enter text
// ---------------------------------------------------------------------------

/// {@template on_enter_text_entry}
/// Enters text into a text field identified by a semantic ref.
/// {@endtemplate}
extension type OnEnterTextEntry._(AgentCallEntry entry) implements AgentCallEntry {
  /// {@macro on_enter_text_entry}
  factory OnEnterTextEntry() {
    final entry = mcpToolkitTool(
      handler: (final parameters) async {
        final ref = parameters['ref'] ?? '';
        final text = parameters['text'] ?? '';
        if (ref.isEmpty || text.isEmpty) {
          return MCPCallResult(
            message: 'Missing required parameter(s) "ref" and/or "text".',
            parameters: <String, dynamic>{'success': false},
          );
        }
        final snapshotIdRaw = jsonDecodeInt(parameters['snapshotId']);
        final snapshotId = snapshotIdRaw == 0 ? null : snapshotIdRaw;
        if (snapshotId != null &&
            snapshotId != SemanticSnapshotService.currentSnapshotId) {
          return MCPCallResult(
            message:
                'Snapshot is stale. Call semantic_snapshot to get fresh refs.',
            parameters: <String, dynamic>{
              'ok': false,
              'error': 'stale_snapshot',
              'providedSnapshotId': snapshotId,
              'currentSnapshotId': SemanticSnapshotService.currentSnapshotId,
            },
          );
        }
        final result = await GestureInteractionService.enterTextAtRef(
          ref,
          text,
        );
        return MCPCallResult(
          message: result['success'] == true
              ? 'Text entered at ref "$ref".'
              : 'Enter text failed: ${result['error']}',
          parameters: result,
        );
      },
      definition: MCPToolDefinition(
        name: 'enter_text',
        description:
            'Enter text into a text field identified by a semantic ref. '
            'Taps the field to focus it first, then sets the value. '
            'Call semantic_snapshot immediately before to get fresh refs. '
            'Pass snapshot_id to detect staleness.',
        inputSchema: ObjectSchema(
          required: ['ref', 'text'],
          properties: {
            'ref': StringSchema(
              description: 'Semantic ref of the text field (e.g. "s_2")',
            ),
            'text': StringSchema(description: 'Text to enter into the field'),
            'snapshotId': IntegerSchema(
              description: 'Optional snapshot_id - if stale, returns error',
            ),
          },
        ),
      ),
    );
    return OnEnterTextEntry._(entry);
  }
}

// ---------------------------------------------------------------------------
// Scroll
// ---------------------------------------------------------------------------

/// {@template on_scroll_entry}
/// Scrolls from a ref or screen centre in a given direction.
/// {@endtemplate}
extension type OnScrollEntry._(AgentCallEntry entry) implements AgentCallEntry {
  /// {@macro on_scroll_entry}
  factory OnScrollEntry() {
    final entry = mcpToolkitTool(
      handler: (final parameters) async {
        final direction = parameters['direction'] ?? 'down';
        final ref = parameters['ref'];
        final distance = jsonDecodeDouble(parameters['distance'] ?? '300');
        final snapshotIdRaw = jsonDecodeInt(parameters['snapshotId']);
        final snapshotId = snapshotIdRaw == 0 ? null : snapshotIdRaw;
        if (snapshotId != null &&
            snapshotId != SemanticSnapshotService.currentSnapshotId) {
          return MCPCallResult(
            message:
                'Snapshot is stale. Call semantic_snapshot to get fresh refs.',
            parameters: <String, dynamic>{
              'ok': false,
              'error': 'stale_snapshot',
              'providedSnapshotId': snapshotId,
              'currentSnapshotId': SemanticSnapshotService.currentSnapshotId,
            },
          );
        }
        final result = await GestureInteractionService.scroll(
          ref: ref,
          direction: direction,
          distance: distance == 0 ? 300 : distance,
        );
        return MCPCallResult(
          message: result['success'] == true
              ? 'Scrolled $direction by ${result['distance']} px.'
              : 'Scroll failed: ${result['error']}',
          parameters: result,
        );
      },
      definition: MCPToolDefinition(
        name: 'scroll',
        description:
            'Scroll in a direction from a ref or the screen centre. '
            'Simulates a drag gesture. '
            'Call semantic_snapshot immediately before to get fresh refs. '
            'Pass snapshot_id to detect staleness.',
        inputSchema: ObjectSchema(
          required: ['direction'],
          properties: {
            'direction': StringSchema(
              description: 'Direction to scroll: up, down, left, right',
            ),
            'ref': StringSchema(
              description:
                  'Optional semantic ref to scroll from '
                  '(defaults to screen centre)',
            ),
            'distance': StringSchema(
              description: 'Distance in logical pixels (default 300)',
            ),
            'snapshotId': IntegerSchema(
              description: 'Optional snapshot_id - if stale, returns error',
            ),
          },
        ),
      ),
    );
    return OnScrollEntry._(entry);
  }
}

// ---------------------------------------------------------------------------
// Long press
// ---------------------------------------------------------------------------

/// {@template on_long_press_entry}
/// Long-presses the widget identified by a semantic ref.
/// {@endtemplate}
extension type OnLongPressEntry._(AgentCallEntry entry) implements AgentCallEntry {
  /// {@macro on_long_press_entry}
  factory OnLongPressEntry() {
    final entry = mcpToolkitTool(
      handler: (final parameters) async {
        final ref = parameters['ref'] ?? '';
        if (ref.isEmpty) {
          return MCPCallResult(
            message: 'Missing required parameter "ref".',
            parameters: <String, dynamic>{'success': false},
          );
        }
        final snapshotIdRaw = jsonDecodeInt(parameters['snapshotId']);
        final snapshotId = snapshotIdRaw == 0 ? null : snapshotIdRaw;
        if (snapshotId != null &&
            snapshotId != SemanticSnapshotService.currentSnapshotId) {
          return MCPCallResult(
            message:
                'Snapshot is stale. Call semantic_snapshot to get fresh refs.',
            parameters: <String, dynamic>{
              'ok': false,
              'error': 'stale_snapshot',
              'providedSnapshotId': snapshotId,
              'currentSnapshotId': SemanticSnapshotService.currentSnapshotId,
            },
          );
        }
        final result = await GestureInteractionService.longPressAtRef(ref);
        return MCPCallResult(
          message: result['success'] == true
              ? 'Long-pressed widget at ref "$ref".'
              : 'Long press failed: ${result['error']}',
          parameters: result,
        );
      },
      definition: MCPToolDefinition(
        name: 'long_press',
        description:
            'Long-press a widget identified by a semantic ref. '
            'Holds for ~500 ms before releasing. '
            'Call semantic_snapshot immediately before to get fresh refs. '
            'Pass snapshot_id to detect staleness.',
        inputSchema: ObjectSchema(
          required: ['ref'],
          properties: {
            'ref': StringSchema(
              description: 'Semantic ref string (e.g. "s_0")',
            ),
            'snapshotId': IntegerSchema(
              description: 'Optional snapshot_id - if stale, returns error',
            ),
          },
        ),
      ),
    );
    return OnLongPressEntry._(entry);
  }
}

// ---------------------------------------------------------------------------
// Swipe
// ---------------------------------------------------------------------------

/// {@template on_swipe_entry}
/// Swipes from a ref or screen centre in a given direction.
/// {@endtemplate}
extension type OnSwipeEntry._(AgentCallEntry entry) implements AgentCallEntry {
  /// {@macro on_swipe_entry}
  factory OnSwipeEntry() {
    final entry = mcpToolkitTool(
      handler: (final parameters) async {
        final direction = parameters['direction'] ?? 'up';
        final ref = parameters['ref'];
        final distance = jsonDecodeDouble(parameters['distance'] ?? '300');
        final snapshotIdRaw = jsonDecodeInt(parameters['snapshotId']);
        final snapshotId = snapshotIdRaw == 0 ? null : snapshotIdRaw;
        if (snapshotId != null &&
            snapshotId != SemanticSnapshotService.currentSnapshotId) {
          return MCPCallResult(
            message:
                'Snapshot is stale. Call semantic_snapshot to get fresh refs.',
            parameters: <String, dynamic>{
              'ok': false,
              'error': 'stale_snapshot',
              'providedSnapshotId': snapshotId,
              'currentSnapshotId': SemanticSnapshotService.currentSnapshotId,
            },
          );
        }
        final result = await GestureInteractionService.swipe(
          direction: direction,
          ref: ref,
          distance: distance == 0 ? 300 : distance,
        );
        return MCPCallResult(
          message: result['success'] == true
              ? 'Swiped $direction by ${result['distance']} px.'
              : 'Swipe failed: ${result['error']}',
          parameters: result,
        );
      },
      definition: MCPToolDefinition(
        name: 'swipe',
        description:
            'Swipe from a ref or the screen centre in a given direction. '
            'Call semantic_snapshot immediately before to get fresh refs. '
            'Pass snapshot_id to detect staleness.',
        inputSchema: ObjectSchema(
          required: ['direction'],
          properties: {
            'direction': StringSchema(
              description: 'Direction to swipe: up, down, left, right',
            ),
            'ref': StringSchema(
              description:
                  'Optional semantic ref to start from '
                  '(defaults to screen centre)',
            ),
            'distance': StringSchema(
              description: 'Distance in logical pixels (default 300)',
            ),
            'snapshotId': IntegerSchema(
              description: 'Optional snapshot_id - if stale, returns error',
            ),
          },
        ),
      ),
    );
    return OnSwipeEntry._(entry);
  }
}

// ---------------------------------------------------------------------------
// Drag
// ---------------------------------------------------------------------------

/// {@template on_drag_entry}
/// Drags from one widget ref to another.
/// {@endtemplate}
extension type OnDragEntry._(AgentCallEntry entry) implements AgentCallEntry {
  /// {@macro on_drag_entry}
  factory OnDragEntry() {
    final entry = mcpToolkitTool(
      handler: (final parameters) async {
        final fromRef = parameters['fromRef'] ?? '';
        final toRef = parameters['toRef'] ?? '';
        if (fromRef.isEmpty || toRef.isEmpty) {
          return MCPCallResult(
            message: 'Missing required parameter(s) "fromRef" and/or "toRef".',
            parameters: <String, dynamic>{'success': false},
          );
        }
        final snapshotIdRaw = jsonDecodeInt(parameters['snapshotId']);
        final snapshotId = snapshotIdRaw == 0 ? null : snapshotIdRaw;
        if (snapshotId != null &&
            snapshotId != SemanticSnapshotService.currentSnapshotId) {
          return MCPCallResult(
            message:
                'Snapshot is stale. Call semantic_snapshot to get fresh refs.',
            parameters: <String, dynamic>{
              'ok': false,
              'error': 'stale_snapshot',
              'providedSnapshotId': snapshotId,
              'currentSnapshotId': SemanticSnapshotService.currentSnapshotId,
            },
          );
        }
        final result = await GestureInteractionService.drag(
          fromRef: fromRef,
          toRef: toRef,
        );
        return MCPCallResult(
          message: result['success'] == true
              ? 'Dragged from "$fromRef" to "$toRef".'
              : 'Drag failed: ${result['error']}',
          parameters: result,
        );
      },
      definition: MCPToolDefinition(
        name: 'drag',
        description:
            'Drag from one widget to another, identified by semantic refs. '
            'Call semantic_snapshot immediately before to get fresh refs. '
            'Pass snapshot_id to detect staleness.',
        inputSchema: ObjectSchema(
          required: ['fromRef', 'toRef'],
          properties: {
            'fromRef': StringSchema(
              description: 'Semantic ref of the drag source',
            ),
            'toRef': StringSchema(
              description: 'Semantic ref of the drag destination',
            ),
            'snapshotId': IntegerSchema(
              description: 'Optional snapshot_id - if stale, returns error',
            ),
          },
        ),
      ),
    );
    return OnDragEntry._(entry);
  }
}

// ---------------------------------------------------------------------------
// Recent logs
// ---------------------------------------------------------------------------

/// {@template on_get_recent_logs_entry}
/// Returns recently captured print / log output.
/// {@endtemplate}
extension type OnGetRecentLogsEntry._(AgentCallEntry entry)
    implements AgentCallEntry {
  /// {@macro on_get_recent_logs_entry}
  factory OnGetRecentLogsEntry() {
    final entry = mcpToolkitTool(
      handler: (final parameters) {
        final count = jsonDecodeInt(parameters['count'] ?? '50');
        final logs = LogCaptureService.getRecentLogs(
          count: count == 0 ? 50 : count,
        );
        return MCPCallResult(
          message: logs.isEmpty
              ? 'No log output captured yet.'
              : '${logs.length} recent log entries returned.',
          parameters: <String, dynamic>{'logs': logs},
        );
      },
      definition: MCPToolDefinition(
        name: 'get_recent_logs',
        description:
            'Get recent print() / debugPrint() output captured from the '
            'running Flutter app.',
        inputSchema: ObjectSchema(
          properties: {
            'count': IntegerSchema(
              description: 'Number of recent entries to return (default 50)',
              minimum: 1,
              maximum: 200,
            ),
          },
        ),
      ),
    );
    return OnGetRecentLogsEntry._(entry);
  }
}

// ---------------------------------------------------------------------------
// Wait for predicate
// ---------------------------------------------------------------------------

/// {@template on_wait_for_entry}
/// Block until a UI predicate holds or a timeout elapses, then return a
/// fresh semantic snapshot. Eliminates sleep+snapshot polling loops.
/// {@endtemplate}
extension type OnWaitForEntry._(AgentCallEntry entry) implements AgentCallEntry {
  /// {@macro on_wait_for_entry}
  factory OnWaitForEntry() {
    final entry = mcpToolkitTool(
      handler: (final parameters) async {
        final predicate = Map<String, Object?>.from(
          jsonDecodeMap(parameters['predicate'] ?? '{}'),
        );
        final timeoutMs = jsonDecodeInt(parameters['timeoutMs'] ?? '5000');
        final result = await WaitPredicateService.waitFor(
          predicate: predicate,
          timeoutMs: timeoutMs == 0 ? 5000 : timeoutMs,
        );
        return MCPCallResult(
          message: result['matched'] == true
              ? 'wait_for matched after ${result['elapsedMs']}ms.'
              : 'wait_for timed out after ${result['elapsedMs']}ms.',
          parameters: result,
        );
      },
      definition: MCPToolDefinition(
        name: 'wait_for',
        description:
            'Wait for a UI predicate (text/noText/time/stable/noError) and '
            'return a fresh semantic snapshot. Default timeout 5000ms, max 30000ms.',
        inputSchema: ObjectSchema(
          properties: {
            'predicate': ObjectSchema(),
            'timeoutMs': IntegerSchema(minimum: 1, maximum: 30000),
          },
          required: const ['predicate'],
        ),
      ),
    );
    return OnWaitForEntry._(entry);
  }
}

// ---------------------------------------------------------------------------
// Press key
// ---------------------------------------------------------------------------

/// {@template on_press_key_entry}
/// Synthesize a keyboard key press (down + up) with optional modifiers.
/// Reaches Focus widgets, Shortcuts, Actions, and Tab traversal. Does NOT
/// trigger `TextField.onSubmitted` or IME composition (those go through
/// the `flutter/textinput` channel) — use `tap_widget` on the submit
/// button instead.
/// {@endtemplate}
extension type OnPressKeyEntry._(AgentCallEntry entry) implements AgentCallEntry {
  /// {@macro on_press_key_entry}
  factory OnPressKeyEntry() {
    final entry = mcpToolkitTool(
      handler: (final parameters) async {
        final key = jsonDecodeString(parameters['key']);
        final result = await ControlFlowService.pressKey(
          key: key,
          ctrl: jsonDecodeBool(parameters['ctrl']),
          shift: jsonDecodeBool(parameters['shift']),
          alt: jsonDecodeBool(parameters['alt']),
          meta: jsonDecodeBool(parameters['meta']),
        );
        return MCPCallResult(
          message: result['success'] == true
              ? 'press_key dispatched: $key.'
              : 'press_key failed: ${result['error']}.',
          parameters: result,
        );
      },
      definition: MCPToolDefinition(
        name: 'press_key',
        description:
            'Synthesize a keyboard key press (down+up). '
            'Accepted keys: Enter, Escape, Tab, Backspace, Delete, Space, '
            'ArrowUp/Down/Left/Right, single ASCII chars (a-z, 0-9). '
            'Optional modifiers: ctrl, shift, alt, meta. '
            'Reaches Focus widgets / Shortcuts / Actions / Tab traversal. '
            'Does NOT trigger TextField.onSubmitted (use tap_widget on the '
            'submit button instead) or IME composition.',
        inputSchema: ObjectSchema(
          properties: {
            'key': StringSchema(),
            'ctrl': BooleanSchema(),
            'shift': BooleanSchema(),
            'alt': BooleanSchema(),
            'meta': BooleanSchema(),
          },
          required: const ['key'],
        ),
      ),
    );
    return OnPressKeyEntry._(entry);
  }
}

// ---------------------------------------------------------------------------
// Handle dialog
// ---------------------------------------------------------------------------

/// {@template on_handle_dialog_entry}
/// Dismiss the topmost popup/dialog route on the registered Navigator.
/// {@endtemplate}
extension type OnHandleDialogEntry._(AgentCallEntry entry)
    implements AgentCallEntry {
  /// {@macro on_handle_dialog_entry}
  factory OnHandleDialogEntry() {
    final entry = mcpToolkitTool(
      handler: (final parameters) async {
        final action = jsonDecodeString(parameters['action']);
        if (action != 'dismiss') {
          return MCPCallResult(
            message: 'handle_dialog: unsupported action "$action".',
            parameters: <String, Object?>{
              'success': false,
              'error': 'unsupported_action',
              'action': action,
            },
          );
        }
        final result = await ControlFlowService.dismissDialog();
        return MCPCallResult(
          message: result['success'] == true
              ? 'Dialog dismissed.'
              : 'handle_dialog failed: ${result['error']}.',
          parameters: result,
        );
      },
      definition: MCPToolDefinition(
        name: 'handle_dialog',
        description:
            'Dismiss the topmost popup/dialog route on the registered '
            'Navigator. Currently only action="dismiss" is supported. '
            'Requires MCPToolkitBinding.instance.navigatorKey = key.',
        inputSchema: ObjectSchema(
          properties: {'action': StringSchema()},
          required: const ['action'],
        ),
      ),
    );
    return OnHandleDialogEntry._(entry);
  }
}

// ---------------------------------------------------------------------------
// Navigate
// ---------------------------------------------------------------------------

/// {@template on_navigate_entry}
/// Drive the registered Navigator: push a named route, pop the topmost
/// route, or popUntil a named route.
/// {@endtemplate}
extension type OnNavigateEntry._(AgentCallEntry entry) implements AgentCallEntry {
  /// {@macro on_navigate_entry}
  factory OnNavigateEntry() {
    final entry = mcpToolkitTool(
      handler: (final parameters) async {
        final action = jsonDecodeString(parameters['action']);
        final route = jsonDecodeString(parameters['route']);
        final argsRaw = parameters['arguments'];
        final arguments = argsRaw == null || argsRaw.isEmpty
            ? null
            : jsonDecodeMap(argsRaw);
        final result = await ControlFlowService.navigate(
          action: action,
          route: route.isEmpty ? null : route,
          arguments: arguments,
        );
        return MCPCallResult(
          message: result['success'] == true
              ? 'navigate $action ok.'
              : 'navigate failed: ${result['error']}.',
          parameters: result,
        );
      },
      definition: MCPToolDefinition(
        name: 'navigate',
        description:
            'Drive the registered Navigator. action=push|pop|popUntil. '
            'push/popUntil require route. push accepts arguments. '
            'Requires MCPToolkitBinding.instance.navigatorKey = key.',
        inputSchema: ObjectSchema(
          properties: {
            'action': StringSchema(),
            'route': StringSchema(),
            'arguments': ObjectSchema(),
          },
          required: const ['action'],
        ),
      ),
    );
    return OnNavigateEntry._(entry);
  }
}

// ---------------------------------------------------------------------------
// Hover
// ---------------------------------------------------------------------------

/// {@template on_hover_entry}
/// Synthesize a mouse hover at the centre of a widget identified by ref.
/// Drives MouseRegion.onEnter/onExit. Requires a desktop or web host
/// (mobile platforms have no hover concept).
/// {@endtemplate}
extension type OnHoverEntry._(AgentCallEntry entry) implements AgentCallEntry {
  /// {@macro on_hover_entry}
  factory OnHoverEntry() {
    final entry = mcpToolkitTool(
      handler: (final parameters) async {
        final ref = jsonDecodeString(parameters['ref']);
        if (ref.isEmpty) {
          return MCPCallResult(
            message: 'Missing required parameter "ref".',
            parameters: const <String, Object?>{
              'success': false,
              'error': 'missing_ref',
            },
          );
        }
        final snapshotIdRaw = jsonDecodeInt(parameters['snapshotId']);
        final snapshotId = snapshotIdRaw == 0 ? null : snapshotIdRaw;
        if (snapshotId != null &&
            snapshotId != SemanticSnapshotService.currentSnapshotId) {
          return MCPCallResult(
            message:
                'Snapshot is stale. Call semantic_snapshot to get fresh refs.',
            parameters: <String, Object?>{
              'ok': false,
              'error': 'stale_snapshot',
              'providedSnapshotId': snapshotId,
              'currentSnapshotId': SemanticSnapshotService.currentSnapshotId,
            },
          );
        }
        final result = await GestureInteractionService.hoverAtRef(ref);
        return MCPCallResult(
          message: result['success'] == true
              ? 'Hovered widget at ref "$ref".'
              : 'hover failed: ${result['error']}.',
          parameters: result,
        );
      },
      definition: MCPToolDefinition(
        name: 'hover',
        description:
            'Synthesize a mouse hover at the centre of a widget identified '
            'by a semantic ref. Drives MouseRegion.onEnter/onExit and '
            'listeners on PointerHoverEvent. Desktop/web only — mobile '
            'has no hover concept. Call semantic_snapshot immediately '
            'before to get fresh refs.',
        inputSchema: ObjectSchema(
          required: const ['ref'],
          properties: {'ref': StringSchema(), 'snapshotId': IntegerSchema()},
        ),
      ),
    );
    return OnHoverEntry._(entry);
  }
}
