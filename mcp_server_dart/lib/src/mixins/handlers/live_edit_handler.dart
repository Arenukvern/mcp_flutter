// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/base_server.dart';
import 'package:flutter_inspector_mcp_server/src/core/command_catalog.dart';
import 'package:flutter_inspector_mcp_server/src/core/error_codes.dart';
import 'package:flutter_inspector_mcp_server/src/core/executor.dart';
import 'package:flutter_inspector_mcp_server/src/core/results.dart';
import 'package:flutter_inspector_mcp_server/src/mixins/handlers/connection_override.dart';

/// Thin MCP adapter for first-class live-edit commands.
class LiveEditHandler {
  LiveEditHandler({required this.server, required this.executor});

  final BaseMCPToolkitServer server;
  final CoreCommandExecutor executor;

  static final _catalog = CommandCatalog.instance;

  static String _description(final String name, final String fallback) =>
      _catalog.specFor(name)?.description ?? fallback;

  static Tool _tool({
    required final String name,
    required final String fallbackDescription,
    final Map<String, Schema> properties = const <String, Schema>{},
    final List<String> required = const <String>[],
  }) => Tool(
    name: name,
    description: _description(name, fallbackDescription),
    inputSchema: strictToolInputSchema(
      properties: properties,
      required: required,
    ),
  );

  static final liveEditStartSessionTool = _tool(
    name: 'live_edit_start_session',
    fallbackDescription: 'Start or reuse a live edit session.',
    properties: {'sessionId': Schema.string()},
  );

  static final liveEditPrepareSessionTool = _tool(
    name: 'live_edit_prepare_session',
    fallbackDescription:
        'Prepare a live edit session, enable the overlay, and return readiness data.',
    properties: {
      'sessionId': Schema.string(),
      'backendId': Schema.string(),
      'workingDirectory': Schema.string(),
    },
  );

  static final liveEditSetOverlayTool = _tool(
    name: 'live_edit_set_overlay',
    fallbackDescription: 'Enable or disable the live edit overlay.',
    properties: {'sessionId': Schema.string(), 'enabled': Schema.bool()},
    required: const <String>['enabled'],
  );

  static final liveEditGetTreeTool = _tool(
    name: 'live_edit_get_tree',
    fallbackDescription: 'Get the live edit widget tree.',
    properties: {'sessionId': Schema.string()},
  );

  static final liveEditSelectAtPointTool = _tool(
    name: 'live_edit_select_at_point',
    fallbackDescription: 'Select a live edit node at global coordinates.',
    properties: {
      'sessionId': Schema.string(),
      'x': Schema.int(),
      'y': Schema.int(),
      'viewId': Schema.int(),
    },
    required: const <String>['x', 'y'],
  );

  static final liveEditGetSelectionTool = _tool(
    name: 'live_edit_get_selection',
    fallbackDescription: 'Get the current live edit selection.',
    properties: {'sessionId': Schema.string()},
  );

  static final liveEditGetCapabilitiesTool = _tool(
    name: 'live_edit_get_capabilities',
    fallbackDescription: 'Get live edit runtime capabilities.',
    properties: {'sessionId': Schema.string()},
  );

  static final liveEditGetSelectionCandidatesTool = _tool(
    name: 'live_edit_get_selection_candidates',
    fallbackDescription: 'Get the current live edit selection candidates.',
    properties: {'sessionId': Schema.string()},
  );

  static final liveEditSetActiveSelectionTool = _tool(
    name: 'live_edit_set_active_selection',
    fallbackDescription: 'Promote one candidate as the active live edit selection.',
    properties: {
      'sessionId': Schema.string(),
      'nodeId': Schema.string(),
      'index': Schema.int(),
    },
  );

  static final liveEditGetPropertyPanelTool = _tool(
    name: 'live_edit_get_property_panel',
    fallbackDescription: 'Get the current live edit property panel payload.',
    properties: {'sessionId': Schema.string()},
  );

  static final liveEditSetEditModeTool = _tool(
    name: 'live_edit_set_edit_mode',
    fallbackDescription: 'Set the live edit overlay mode.',
    properties: {'sessionId': Schema.string(), 'mode': Schema.string()},
    required: const <String>['mode'],
  );

  static final liveEditGetPreviewStateTool = _tool(
    name: 'live_edit_get_preview_state',
    fallbackDescription: 'Get the current live edit preview state.',
    properties: {'sessionId': Schema.string()},
  );

  static final liveEditUpdateDraftTool = _tool(
    name: 'live_edit_update_draft',
    fallbackDescription: 'Update one live edit draft change.',
    properties: {
      'sessionId': Schema.string(),
      'change': Schema.object(additionalProperties: true),
    },
    required: const <String>['change'],
  );

  static final liveEditGetDraftTool = _tool(
    name: 'live_edit_get_draft',
    fallbackDescription: 'Get the current live edit draft.',
    properties: {'sessionId': Schema.string()},
  );

  static final liveEditDiscardDraftTool = _tool(
    name: 'live_edit_discard_draft',
    fallbackDescription: 'Discard the current live edit draft.',
    properties: {'sessionId': Schema.string()},
  );

  static final liveEditEndSessionTool = _tool(
    name: 'live_edit_end_session',
    fallbackDescription: 'End the current live edit session.',
    properties: {'sessionId': Schema.string()},
  );

  static final liveEditListAgentBackendsTool = _tool(
    name: 'live_edit_list_agent_backends',
    fallbackDescription: 'List available live edit agent backends.',
  );

  static final liveEditGetAgentBackendTool = _tool(
    name: 'live_edit_get_agent_backend',
    fallbackDescription: 'Get the active or requested live edit backend.',
    properties: {'sessionId': Schema.string(), 'backendId': Schema.string()},
  );

  static final liveEditSetAgentBackendTool = _tool(
    name: 'live_edit_set_agent_backend',
    fallbackDescription: 'Set the live edit backend for one session.',
    properties: {'sessionId': Schema.string(), 'backendId': Schema.string()},
    required: const <String>['sessionId', 'backendId'],
  );

  static final liveEditResolveDraftTool = _tool(
    name: 'live_edit_resolve_draft',
    fallbackDescription: 'Resolve the current live edit draft into a proposal.',
    properties: {
      'sessionId': Schema.string(),
      'backendId': Schema.string(),
      'workingDirectory': Schema.string(),
      'intentText': Schema.string(),
    },
  );

  static final liveEditAcceptResolutionTool = _tool(
    name: 'live_edit_accept_resolution',
    fallbackDescription: 'Apply a live edit proposal and validate it.',
    properties: {
      'proposalId': Schema.string(),
      'sessionId': Schema.string(),
      'workingDirectory': Schema.string(),
    },
    required: const <String>['proposalId'],
  );

  static final liveEditRejectResolutionTool = _tool(
    name: 'live_edit_reject_resolution',
    fallbackDescription: 'Reject a live edit proposal.',
    properties: {'proposalId': Schema.string()},
    required: const <String>['proposalId'],
  );

  Future<CallToolResult> liveEditStartSession(final CallToolRequest request) =>
      _executeNamed('live_edit_start_session', request);

  Future<CallToolResult> liveEditPrepareSession(final CallToolRequest request) =>
      _executeNamed('live_edit_prepare_session', request);

  Future<CallToolResult> liveEditSetOverlay(final CallToolRequest request) =>
      _executeNamed('live_edit_set_overlay', request);

  Future<CallToolResult> liveEditGetTree(final CallToolRequest request) =>
      _executeNamed('live_edit_get_tree', request);

  Future<CallToolResult> liveEditSelectAtPoint(final CallToolRequest request) =>
      _executeNamed('live_edit_select_at_point', request);

  Future<CallToolResult> liveEditGetSelection(final CallToolRequest request) =>
      _executeNamed('live_edit_get_selection', request);

  Future<CallToolResult> liveEditGetCapabilities(
    final CallToolRequest request,
  ) => _executeNamed('live_edit_get_capabilities', request);

  Future<CallToolResult> liveEditGetSelectionCandidates(
    final CallToolRequest request,
  ) => _executeNamed('live_edit_get_selection_candidates', request);

  Future<CallToolResult> liveEditSetActiveSelection(
    final CallToolRequest request,
  ) => _executeNamed('live_edit_set_active_selection', request);

  Future<CallToolResult> liveEditGetPropertyPanel(
    final CallToolRequest request,
  ) => _executeNamed('live_edit_get_property_panel', request);

  Future<CallToolResult> liveEditSetEditMode(final CallToolRequest request) =>
      _executeNamed('live_edit_set_edit_mode', request);

  Future<CallToolResult> liveEditGetPreviewState(
    final CallToolRequest request,
  ) => _executeNamed('live_edit_get_preview_state', request);

  Future<CallToolResult> liveEditUpdateDraft(final CallToolRequest request) =>
      _executeNamed('live_edit_update_draft', request);

  Future<CallToolResult> liveEditGetDraft(final CallToolRequest request) =>
      _executeNamed('live_edit_get_draft', request);

  Future<CallToolResult> liveEditDiscardDraft(final CallToolRequest request) =>
      _executeNamed('live_edit_discard_draft', request);

  Future<CallToolResult> liveEditEndSession(final CallToolRequest request) =>
      _executeNamed('live_edit_end_session', request);

  Future<CallToolResult> liveEditListAgentBackends(
    final CallToolRequest request,
  ) => _executeNamed('live_edit_list_agent_backends', request);

  Future<CallToolResult> liveEditGetAgentBackend(
    final CallToolRequest request,
  ) => _executeNamed('live_edit_get_agent_backend', request);

  Future<CallToolResult> liveEditSetAgentBackend(
    final CallToolRequest request,
  ) => _executeNamed('live_edit_set_agent_backend', request);

  Future<CallToolResult> liveEditResolveDraft(final CallToolRequest request) =>
      _executeNamed('live_edit_resolve_draft', request);

  Future<CallToolResult> liveEditAcceptResolution(
    final CallToolRequest request,
  ) => _executeNamed('live_edit_accept_resolution', request);

  Future<CallToolResult> liveEditRejectResolution(
    final CallToolRequest request,
  ) => _executeNamed('live_edit_reject_resolution', request);

  Future<CallToolResult> _executeNamed(
    final String name,
    final CallToolRequest request,
  ) async {
    final spec = _catalog.specFor(name);
    if (spec == null) {
      return toCallToolErrorResult(
        CoreResult.failure(
          code: CoreErrorCode.invalidCommand,
          message: 'Unknown live edit command: $name',
        ),
        prefix: '$name failed',
      );
    }

    if (spec.requiresVm) {
      final connectError = await applyConnectionOverride(
        request: request,
        executor: executor,
      );
      if (connectError != null) {
        return toCallToolErrorResult(connectError, prefix: 'Failed to connect');
      }
    }

    final arguments = Map<String, Object?>.from(
      request.arguments ?? const <String, Object?>{},
    )..remove('connection');

    try {
      final command = _catalog.buildCommand(name, arguments);
      final result = await executor.execute(command);
      if (!result.ok) {
        return toCallToolErrorResult(result, prefix: '$name failed');
      }
      return CallToolResult(
        content: [TextContent(text: jsonEncode(result.data))],
      );
    } on ArgumentError catch (error) {
      return toCallToolErrorResult(
        CoreResult.failure(
          code: CoreErrorCode.invalidCommand,
          message: 'Invalid arguments for $name: ${error.message}',
        ),
        prefix: '$name failed',
      );
    }
  }
}
