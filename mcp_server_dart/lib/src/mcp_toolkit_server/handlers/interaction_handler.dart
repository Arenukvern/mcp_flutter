// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/mcp_toolkit_server/base_server.dart';
import 'package:flutter_inspector_mcp_server/src/mcp_toolkit_server/core/to_resources_tools.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/command_executor.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/commands/commands.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/vm_connections/vm_connections.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:is_dart_empty_or_not/is_dart_empty_or_not.dart';

/// Thin MCP adapter for interaction and inspection tools.
class InteractionHandler {
  InteractionHandler({required this.server, required this.executor});

  final BaseMCPToolkitServer server;
  final CoreCommandExecutor executor;
  static final _catalog = CommandCatalog.instance;

  static String _description(final String name, final String fallback) =>
      _catalog.specFor(name)?.description ?? fallback;

  // --- Tool definitions ---

  static final semanticSnapshotTool = Tool(
    name: 'semantic_snapshot',
    description: _description(
      'semantic_snapshot',
      'Get compact semantic tree of interactive widgets with refs usable '
          'by interaction tools (tap_widget, enter_text, etc.)',
    ),
    inputSchema: strictToolInputSchema(),
  );

  static final tapWidgetTool = Tool(
    name: 'tap_widget',
    description: _description(
      'tap_widget',
      'Tap a widget identified by ref from semantic_snapshot. '
          'Call semantic_snapshot immediately before to get fresh refs. '
          'Pass snapshot_id to detect staleness.',
    ),
    inputSchema: strictToolInputSchema(
      required: ['ref'],
      properties: {
        'ref': Schema.string(
          description: 'Widget ref from semantic_snapshot (e.g. "s_0")',
        ),
        'snapshotId': Schema.int(
          description:
              'Optional: snapshot_id from most recent semantic_snapshot. '
              'If stale, call fails.',
        ),
      },
    ),
  );

  static final enterTextTool = Tool(
    name: 'enter_text',
    description: _description(
      'enter_text',
      'Enter text into a text field identified by ref from semantic_snapshot. '
          'Call semantic_snapshot immediately before to get fresh refs. '
          'Pass snapshot_id to detect staleness.',
    ),
    inputSchema: strictToolInputSchema(
      required: ['ref', 'text'],
      properties: {
        'ref': Schema.string(
          description: 'Text field ref from semantic_snapshot',
        ),
        'text': Schema.string(description: 'Text to enter'),
        'snapshotId': Schema.int(
          description:
              'Optional: snapshot_id from most recent semantic_snapshot. '
              'If stale, call fails.',
        ),
      },
    ),
  );

  static final scrollTool = Tool(
    name: 'scroll',
    description: _description(
      'scroll',
      'Scroll in a direction from a ref or from center of screen. '
          'Call semantic_snapshot immediately before to get fresh refs. '
          'Pass snapshot_id to detect staleness.',
    ),
    inputSchema: strictToolInputSchema(
      required: ['direction'],
      properties: {
        'direction': Schema.string(
          description: 'Scroll direction: up, down, left, right',
        ),
        'ref': Schema.string(description: 'Optional ref to scroll from'),
        'distance': Schema.num(
          description: 'Scroll distance in logical pixels (default: 300)',
        ),
        'snapshotId': Schema.int(
          description:
              'Optional: snapshot_id from most recent semantic_snapshot. '
              'If stale, call fails.',
        ),
      },
    ),
  );

  static final longPressTool = Tool(
    name: 'long_press',
    description: _description(
      'long_press',
      'Long press a widget identified by ref from semantic_snapshot. '
          'Call semantic_snapshot immediately before to get fresh refs. '
          'Pass snapshot_id to detect staleness.',
    ),
    inputSchema: strictToolInputSchema(
      required: ['ref'],
      properties: {
        'ref': Schema.string(description: 'Widget ref from semantic_snapshot'),
        'snapshotId': Schema.int(
          description:
              'Optional: snapshot_id from most recent semantic_snapshot. '
              'If stale, call fails.',
        ),
      },
    ),
  );

  static final swipeTool = Tool(
    name: 'swipe',
    description: _description(
      'swipe',
      'Swipe in a direction from a ref or center of screen. '
          'Call semantic_snapshot immediately before to get fresh refs. '
          'Pass snapshot_id to detect staleness.',
    ),
    inputSchema: strictToolInputSchema(
      required: ['direction'],
      properties: {
        'direction': Schema.string(
          description: 'Swipe direction: up, down, left, right',
        ),
        'ref': Schema.string(description: 'Optional ref to swipe from'),
        'distance': Schema.num(
          description: 'Swipe distance in logical pixels (default: 300)',
        ),
        'snapshotId': Schema.int(
          description:
              'Optional: snapshot_id from most recent semantic_snapshot. '
              'If stale, call fails.',
        ),
      },
    ),
  );

  static final dragTool = Tool(
    name: 'drag',
    description: _description(
      'drag',
      'Drag from one widget to another, identified by refs '
          'from semantic_snapshot. '
          'Call semantic_snapshot immediately before to get fresh refs. '
          'Pass snapshot_id to detect staleness.',
    ),
    inputSchema: strictToolInputSchema(
      required: ['fromRef', 'toRef'],
      properties: {
        'fromRef': Schema.string(description: 'Source widget ref'),
        'toRef': Schema.string(description: 'Target widget ref'),
        'snapshotId': Schema.int(
          description:
              'Optional: snapshot_id from most recent semantic_snapshot. '
              'If stale, call fails.',
        ),
      },
    ),
  );

  static final hotReloadAndCaptureTool = Tool(
    name: 'hot_reload_and_capture',
    description: _description(
      'hot_reload_and_capture',
      'Hot reload then capture screenshot + semantic snapshot + errors '
          'in one call. Tight edit-preview cycle.',
    ),
    inputSchema: strictToolInputSchema(
      properties: {
        'compress': Schema.bool(
          description: 'Compress screenshots (default: true)',
        ),
        'includeSemantics': Schema.bool(
          description: 'Include semantic snapshot (default: true)',
        ),
        'includeErrors': Schema.bool(
          description: 'Include app errors (default: true)',
        ),
        'errorsCount': Schema.int(
          description: 'Number of errors to include (default: 4)',
        ),
      },
    ),
  );

  static final evaluateDartExpressionTool = Tool(
    name: 'evaluate_dart_expression',
    description: _description(
      'evaluate_dart_expression',
      'Evaluate a Dart expression in the running app isolate. '
          'Returns the result of the expression.',
    ),
    inputSchema: strictToolInputSchema(
      required: ['expression'],
      properties: {
        'expression': Schema.string(
          description:
              'Dart expression to evaluate '
              '(e.g. "MyClass.instance.value")',
        ),
      },
    ),
  );

  static final getRecentLogsTool = Tool(
    name: 'get_recent_logs',
    description: _description(
      'get_recent_logs',
      'Get recent print() and log output from the running Flutter app',
    ),
    inputSchema: strictToolInputSchema(
      properties: {
        'count': Schema.int(
          description: 'Number of recent log entries (default: 50)',
        ),
      },
    ),
  );

  static final waitForTool = Tool(
    name: 'wait_for',
    description: _description(
      'wait_for',
      'Wait for a UI predicate (text/noText/time/stable) and return a fresh '
          'semantic snapshot. Replaces sleep+snapshot polling. '
          'Default timeout 5000ms, max 30000ms.',
    ),
    inputSchema: strictToolInputSchema(
      required: ['predicate'],
      properties: {
        'predicate': Schema.object(
          additionalProperties: true,
          description:
              'Predicate map. Shapes: '
              '{kind:"time", ms:int} | '
              '{kind:"text", text:String} | '
              '{kind:"noText", text:String} | '
              '{kind:"stable", stableWindowMs:int}',
        ),
        'timeoutMs': Schema.int(
          description: 'Timeout in ms (default 5000, max 30000)',
        ),
      },
    ),
  );

  // --- Handler methods ---

  Future<CallToolResult> semanticSnapshot(final CallToolRequest request) async {
    final connectError = await applyConnectionOverride(
      request: request,
      executor: executor,
    );
    if (connectError != null) {
      return toCallToolErrorResult(connectError, prefix: 'Failed to connect');
    }

    final result = await executor.execute(const SemanticSnapshotCommand());
    if (!result.ok) {
      return toCallToolErrorResult(
        result,
        prefix: 'Failed to get semantic snapshot',
      );
    }

    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
    );
  }

  Future<CallToolResult> tapWidget(final CallToolRequest request) async {
    final connectError = await applyConnectionOverride(
      request: request,
      executor: executor,
    );
    if (connectError != null) {
      return toCallToolErrorResult(connectError, prefix: 'Failed to connect');
    }

    final ref = jsonDecodeString(request.arguments?['ref']).whenEmptyUse('');
    final snapshotIdRaw = jsonDecodeInt(request.arguments?['snapshotId']);
    final result = await executor.execute(
      TapWidgetCommand(
        ref: ref,
        snapshotId: snapshotIdRaw == 0 ? null : snapshotIdRaw,
      ),
    );
    if (!result.ok) {
      return toCallToolErrorResult(result, prefix: 'Failed to tap widget');
    }

    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
    );
  }

  Future<CallToolResult> enterText(final CallToolRequest request) async {
    final connectError = await applyConnectionOverride(
      request: request,
      executor: executor,
    );
    if (connectError != null) {
      return toCallToolErrorResult(connectError, prefix: 'Failed to connect');
    }

    final ref = jsonDecodeString(request.arguments?['ref']).whenEmptyUse('');
    final text = jsonDecodeString(request.arguments?['text']).whenEmptyUse('');
    final snapshotIdRaw = jsonDecodeInt(request.arguments?['snapshotId']);
    final result = await executor.execute(
      EnterTextCommand(
        ref: ref,
        text: text,
        snapshotId: snapshotIdRaw == 0 ? null : snapshotIdRaw,
      ),
    );
    if (!result.ok) {
      return toCallToolErrorResult(result, prefix: 'Failed to enter text');
    }

    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
    );
  }

  Future<CallToolResult> scroll(final CallToolRequest request) async {
    final connectError = await applyConnectionOverride(
      request: request,
      executor: executor,
    );
    if (connectError != null) {
      return toCallToolErrorResult(connectError, prefix: 'Failed to connect');
    }

    final direction = jsonDecodeString(
      request.arguments?['direction'],
    ).whenEmptyUse('down');
    final ref = jsonDecodeString(request.arguments?['ref']);
    final distance =
        (request.arguments?['distance'] as num?)?.toDouble() ?? 300.0;
    final snapshotIdRaw = jsonDecodeInt(request.arguments?['snapshotId']);
    final result = await executor.execute(
      ScrollCommand(
        ref: ref.isEmpty ? null : ref,
        direction: direction,
        distance: distance,
        snapshotId: snapshotIdRaw == 0 ? null : snapshotIdRaw,
      ),
    );
    if (!result.ok) {
      return toCallToolErrorResult(result, prefix: 'Failed to scroll');
    }

    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
    );
  }

  Future<CallToolResult> longPress(final CallToolRequest request) async {
    final connectError = await applyConnectionOverride(
      request: request,
      executor: executor,
    );
    if (connectError != null) {
      return toCallToolErrorResult(connectError, prefix: 'Failed to connect');
    }

    final ref = jsonDecodeString(request.arguments?['ref']).whenEmptyUse('');
    final snapshotIdRaw = jsonDecodeInt(request.arguments?['snapshotId']);
    final result = await executor.execute(
      LongPressCommand(
        ref: ref,
        snapshotId: snapshotIdRaw == 0 ? null : snapshotIdRaw,
      ),
    );
    if (!result.ok) {
      return toCallToolErrorResult(result, prefix: 'Failed to long press');
    }

    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
    );
  }

  Future<CallToolResult> swipe(final CallToolRequest request) async {
    final connectError = await applyConnectionOverride(
      request: request,
      executor: executor,
    );
    if (connectError != null) {
      return toCallToolErrorResult(connectError, prefix: 'Failed to connect');
    }

    final direction = jsonDecodeString(
      request.arguments?['direction'],
    ).whenEmptyUse('up');
    final ref = jsonDecodeString(request.arguments?['ref']);
    final distance =
        (request.arguments?['distance'] as num?)?.toDouble() ?? 300.0;
    final snapshotIdRaw = jsonDecodeInt(request.arguments?['snapshotId']);
    final result = await executor.execute(
      SwipeCommand(
        direction: direction,
        ref: ref.isEmpty ? null : ref,
        distance: distance,
        snapshotId: snapshotIdRaw == 0 ? null : snapshotIdRaw,
      ),
    );
    if (!result.ok) {
      return toCallToolErrorResult(result, prefix: 'Failed to swipe');
    }

    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
    );
  }

  Future<CallToolResult> drag(final CallToolRequest request) async {
    final connectError = await applyConnectionOverride(
      request: request,
      executor: executor,
    );
    if (connectError != null) {
      return toCallToolErrorResult(connectError, prefix: 'Failed to connect');
    }

    final fromRef = jsonDecodeString(
      request.arguments?['fromRef'],
    ).whenEmptyUse('');
    final toRef = jsonDecodeString(
      request.arguments?['toRef'],
    ).whenEmptyUse('');
    final snapshotIdRaw = jsonDecodeInt(request.arguments?['snapshotId']);
    final result = await executor.execute(
      DragCommand(
        fromRef: fromRef,
        toRef: toRef,
        snapshotId: snapshotIdRaw == 0 ? null : snapshotIdRaw,
      ),
    );
    if (!result.ok) {
      return toCallToolErrorResult(result, prefix: 'Failed to drag');
    }

    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
    );
  }

  Future<CallToolResult> hotReloadAndCapture(
    final CallToolRequest request,
  ) async {
    final connectError = await applyConnectionOverride(
      request: request,
      executor: executor,
    );
    if (connectError != null) {
      return toCallToolErrorResult(connectError, prefix: 'Failed to connect');
    }

    final compress = switch (request.arguments?['compress']) {
      final bool v => v,
      final String v => v.toLowerCase() != 'false',
      _ => true,
    };
    final includeSemantics = switch (request.arguments?['includeSemantics']) {
      final bool v => v,
      final String v => v.toLowerCase() != 'false',
      _ => true,
    };
    final includeErrors = switch (request.arguments?['includeErrors']) {
      final bool v => v,
      final String v => v.toLowerCase() != 'false',
      _ => true,
    };
    final errorsCount = jsonDecodeInt(
      request.arguments?['errorsCount'],
    ).whenZeroUse(4);
    final result = await executor.execute(
      HotReloadAndCaptureCommand(
        compress: compress,
        includeSemantics: includeSemantics,
        includeErrors: includeErrors,
        errorsCount: errorsCount,
      ),
    );
    if (!result.ok) {
      return toCallToolErrorResult(
        result,
        prefix: 'Failed to hot reload and capture',
      );
    }

    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
    );
  }

  Future<CallToolResult> evaluateDartExpression(
    final CallToolRequest request,
  ) async {
    final connectError = await applyConnectionOverride(
      request: request,
      executor: executor,
    );
    if (connectError != null) {
      return toCallToolErrorResult(connectError, prefix: 'Failed to connect');
    }

    final expression = jsonDecodeString(
      request.arguments?['expression'],
    ).whenEmptyUse('');
    final result = await executor.execute(
      EvaluateDartExpressionCommand(expression: expression),
    );
    if (!result.ok) {
      return toCallToolErrorResult(
        result,
        prefix: 'Failed to evaluate expression',
      );
    }

    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
    );
  }

  Future<CallToolResult> getRecentLogs(final CallToolRequest request) async {
    final connectError = await applyConnectionOverride(
      request: request,
      executor: executor,
    );
    if (connectError != null) {
      return toCallToolErrorResult(connectError, prefix: 'Failed to connect');
    }

    final count = jsonDecodeInt(request.arguments?['count']).whenZeroUse(50);
    final result = await executor.execute(GetRecentLogsCommand(count: count));
    if (!result.ok) {
      return toCallToolErrorResult(result, prefix: 'Failed to get logs');
    }

    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
    );
  }

  Future<CallToolResult> waitFor(final CallToolRequest request) async {
    final connectError = await applyConnectionOverride(
      request: request,
      executor: executor,
    );
    if (connectError != null) {
      return toCallToolErrorResult(connectError, prefix: 'Failed to connect');
    }

    final args = request.arguments ?? const {};
    final predicateRaw = args['predicate'];
    final predicate = predicateRaw is Map
        ? Map<String, Object?>.from(predicateRaw)
        : <String, Object?>{};
    final timeoutMs = jsonDecodeInt(args['timeoutMs']);

    final result = await executor.execute(
      WaitForCommand(
        predicate: predicate,
        timeoutMs: timeoutMs == 0 ? 5000 : timeoutMs,
      ),
    );
    if (!result.ok) {
      return toCallToolErrorResult(result, prefix: 'wait_for failed');
    }
    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
    );
  }
}
