// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/base_server.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';
import 'package:flutter_inspector_mcp_server/src/core/command_catalog.dart';
import 'package:flutter_inspector_mcp_server/src/core/error_codes.dart';
import 'package:flutter_inspector_mcp_server/src/core/executor.dart';
import 'package:flutter_inspector_mcp_server/src/core/results.dart';
import 'package:flutter_inspector_mcp_server/src/mixins/handlers/connection_override.dart';

/// Thin MCP adapter for first-class live-edit commands.
class LiveEditHandler {
  LiveEditHandler({required this.server, required this.executor});

  static final _catalog = CommandCatalog.instance;
  static final liveEditStartSessionTool = _tool(
    name: LiveEditMcpToolNames.startSession,
    fallbackDescription: 'Start or reuse a live edit session.',
    properties: {'sessionId': Schema.string(), 'targetDomain': Schema.string()},
  );

  static final liveEditPrepareSessionTool = _tool(
    name: LiveEditMcpToolNames.prepareSession,
    fallbackDescription:
        'Prepare a live edit session, enable the overlay, and return readiness data.',
    properties: {
      'sessionId': Schema.string(),
      'backendId': Schema.string(),
      'inferenceConfig': _inferenceConfigSchema(),
      'workingDirectory': Schema.string(),
      'targetDomain': Schema.string(),
    },
  );

  static final liveEditSetOverlayTool = _tool(
    name: LiveEditMcpToolNames.setOverlay,
    fallbackDescription: 'Enable or disable the live edit overlay.',
    properties: {'sessionId': Schema.string(), 'enabled': Schema.bool()},
    required: const <String>['enabled'],
  );

  static final liveEditGetTreeTool = _tool(
    name: LiveEditMcpToolNames.getTree,
    fallbackDescription: 'Get the live edit widget tree.',
    properties: {'sessionId': Schema.string(), 'targetDomain': Schema.string()},
  );

  static final liveEditSelectAtPointTool = _tool(
    name: LiveEditMcpToolNames.selectAtPoint,
    fallbackDescription: 'Select a live edit node at global coordinates.',
    properties: {
      'sessionId': Schema.string(),
      'x': Schema.int(),
      'y': Schema.int(),
      'viewId': Schema.int(),
      'selectionPolicy': Schema.string(),
      'targetDomain': Schema.string(),
    },
    required: const <String>['x', 'y'],
  );

  static final liveEditGetSelectionTool = _tool(
    name: LiveEditMcpToolNames.getSelection,
    fallbackDescription: 'Get the current live edit selection.',
    properties: {'sessionId': Schema.string(), 'targetDomain': Schema.string()},
  );

  static final liveEditGetCapabilitiesTool = _tool(
    name: LiveEditMcpToolNames.getCapabilities,
    fallbackDescription: 'Get live edit runtime capabilities.',
    properties: {'sessionId': Schema.string(), 'targetDomain': Schema.string()},
  );

  static final liveEditGetSelectionCandidatesTool = _tool(
    name: LiveEditMcpToolNames.getSelectionCandidates,
    fallbackDescription: 'Get the current live edit selection candidates.',
    properties: {'sessionId': Schema.string(), 'targetDomain': Schema.string()},
  );

  static final liveEditSetActiveSelectionTool = _tool(
    name: LiveEditMcpToolNames.setActiveSelection,
    fallbackDescription:
        'Promote one candidate as the active live edit selection.',
    properties: {
      'sessionId': Schema.string(),
      'nodeId': Schema.string(),
      'index': Schema.int(),
      'targetDomain': Schema.string(),
    },
  );

  static final liveEditGetPropertyPanelTool = _tool(
    name: LiveEditMcpToolNames.getPropertyPanel,
    fallbackDescription: 'Get the current live edit property panel payload.',
    properties: {'sessionId': Schema.string(), 'targetDomain': Schema.string()},
  );

  static final liveEditSetEditModeTool = _tool(
    name: LiveEditMcpToolNames.setEditMode,
    fallbackDescription: 'Set the live edit overlay mode.',
    properties: {
      'sessionId': Schema.string(),
      'mode': Schema.string(),
      'targetDomain': Schema.string(),
    },
    required: const <String>['mode'],
  );

  static final liveEditGetPreviewStateTool = _tool(
    name: LiveEditMcpToolNames.getPreviewState,
    fallbackDescription: 'Get the current live edit preview state.',
    properties: {'sessionId': Schema.string(), 'targetDomain': Schema.string()},
  );

  static final liveEditUpdateDraftTool = _tool(
    name: LiveEditMcpToolNames.updateDraft,
    fallbackDescription: 'Update one live edit draft change.',
    properties: {
      'sessionId': Schema.string(),
      'change': Schema.object(additionalProperties: true),
      'targetDomain': Schema.string(),
    },
    required: const <String>['change'],
  );

  static final liveEditGetDraftTool = _tool(
    name: LiveEditMcpToolNames.getDraft,
    fallbackDescription: 'Get the current live edit draft.',
    properties: {'sessionId': Schema.string()},
  );

  static final liveEditDiscardDraftTool = _tool(
    name: LiveEditMcpToolNames.discardDraft,
    fallbackDescription: 'Discard the current live edit draft.',
    properties: {'sessionId': Schema.string()},
  );

  static final liveEditEndSessionTool = _tool(
    name: LiveEditMcpToolNames.endSession,
    fallbackDescription: 'End the current live edit session.',
    properties: {'sessionId': Schema.string()},
  );

  static final liveEditListAgentBackendsTool = _tool(
    name: LiveEditMcpToolNames.listAgentBackends,
    fallbackDescription: 'List available live edit agent backends.',
  );

  static final liveEditGetAgentBackendTool = _tool(
    name: LiveEditMcpToolNames.getAgentBackend,
    fallbackDescription: 'Get the active or requested live edit backend.',
    properties: {'sessionId': Schema.string(), 'backendId': Schema.string()},
  );

  static final liveEditSetAgentBackendTool = _tool(
    name: LiveEditMcpToolNames.setAgentBackend,
    fallbackDescription: 'Set the live edit backend for one session.',
    properties: {
      'sessionId': Schema.string(),
      'backendId': Schema.string(),
      'inferenceConfig': _inferenceConfigSchema(),
    },
    required: const <String>['sessionId', 'backendId'],
  );

  static final liveEditResolveDraftTool = _tool(
    name: LiveEditMcpToolNames.resolveDraft,
    fallbackDescription: 'Resolve the current live edit draft into a proposal.',
    properties: {
      'sessionId': Schema.string(),
      'backendId': Schema.string(),
      'inferenceConfig': _inferenceConfigSchema(),
      'workingDirectory': Schema.string(),
      'intentText': Schema.string(),
      'targetDomain': Schema.string(),
    },
  );

  static final liveEditApplyDraftTool = _tool(
    name: LiveEditMcpToolNames.applyDraft,
    fallbackDescription:
        'Run a single live-edit transaction for resolve, compact plan review, and optional apply.',
    properties: {
      'sessionId': Schema.string(),
      'backendId': Schema.string(),
      'inferenceConfig': _inferenceConfigSchema(),
      'workingDirectory': Schema.string(),
      'intentText': Schema.string(),
      'proposalId': Schema.string(),
      'approve': Schema.bool(),
    },
  );

  static final liveEditAcceptResolutionTool = _tool(
    name: LiveEditMcpToolNames.acceptResolution,
    fallbackDescription: 'Apply a live edit proposal and validate it.',
    properties: {
      'proposalId': Schema.string(),
      'sessionId': Schema.string(),
      'workingDirectory': Schema.string(),
    },
    required: const <String>['proposalId'],
  );

  static final liveEditRejectResolutionTool = _tool(
    name: LiveEditMcpToolNames.rejectResolution,
    fallbackDescription: 'Reject a live edit proposal.',
    properties: {'proposalId': Schema.string()},
    required: const <String>['proposalId'],
  );

  final BaseMCPToolkitServer server;

  final CoreCommandExecutor executor;

  Future<CallToolResult> liveEditAcceptResolution(
    final CallToolRequest request,
  ) => _executeNamed(LiveEditMcpToolNames.acceptResolution, request);

  Future<CallToolResult> liveEditApplyDraft(final CallToolRequest request) =>
      _executeNamed(LiveEditMcpToolNames.applyDraft, request);

  Future<CallToolResult> liveEditDiscardDraft(final CallToolRequest request) =>
      _executeNamed(LiveEditMcpToolNames.discardDraft, request);

  Future<CallToolResult> liveEditEndSession(final CallToolRequest request) =>
      _executeNamed(LiveEditMcpToolNames.endSession, request);

  Future<CallToolResult> liveEditGetAgentBackend(
    final CallToolRequest request,
  ) => _executeNamed(LiveEditMcpToolNames.getAgentBackend, request);

  Future<CallToolResult> liveEditGetCapabilities(
    final CallToolRequest request,
  ) => _executeNamed(LiveEditMcpToolNames.getCapabilities, request);

  Future<CallToolResult> liveEditGetDraft(final CallToolRequest request) =>
      _executeNamed(LiveEditMcpToolNames.getDraft, request);

  Future<CallToolResult> liveEditGetPreviewState(
    final CallToolRequest request,
  ) => _executeNamed(LiveEditMcpToolNames.getPreviewState, request);

  Future<CallToolResult> liveEditGetPropertyPanel(
    final CallToolRequest request,
  ) => _executeNamed(LiveEditMcpToolNames.getPropertyPanel, request);

  Future<CallToolResult> liveEditGetSelection(final CallToolRequest request) =>
      _executeNamed(LiveEditMcpToolNames.getSelection, request);

  Future<CallToolResult> liveEditGetSelectionCandidates(
    final CallToolRequest request,
  ) => _executeNamed(LiveEditMcpToolNames.getSelectionCandidates, request);

  Future<CallToolResult> liveEditGetTree(final CallToolRequest request) =>
      _executeNamed(LiveEditMcpToolNames.getTree, request);

  Future<CallToolResult> liveEditListAgentBackends(
    final CallToolRequest request,
  ) => _executeNamed(LiveEditMcpToolNames.listAgentBackends, request);

  Future<CallToolResult> liveEditPrepareSession(
    final CallToolRequest request,
  ) => _executeNamed(LiveEditMcpToolNames.prepareSession, request);

  Future<CallToolResult> liveEditRejectResolution(
    final CallToolRequest request,
  ) => _executeNamed(LiveEditMcpToolNames.rejectResolution, request);

  Future<CallToolResult> liveEditResolveDraft(final CallToolRequest request) =>
      _executeNamed(LiveEditMcpToolNames.resolveDraft, request);

  Future<CallToolResult> liveEditSelectAtPoint(final CallToolRequest request) =>
      _executeNamed(LiveEditMcpToolNames.selectAtPoint, request);

  Future<CallToolResult> liveEditSetActiveSelection(
    final CallToolRequest request,
  ) => _executeNamed(LiveEditMcpToolNames.setActiveSelection, request);

  Future<CallToolResult> liveEditSetAgentBackend(
    final CallToolRequest request,
  ) => _executeNamed(LiveEditMcpToolNames.setAgentBackend, request);

  Future<CallToolResult> liveEditSetEditMode(final CallToolRequest request) =>
      _executeNamed(LiveEditMcpToolNames.setEditMode, request);

  Future<CallToolResult> liveEditSetOverlay(final CallToolRequest request) =>
      _executeNamed(LiveEditMcpToolNames.setOverlay, request);

  Future<CallToolResult> liveEditStartSession(final CallToolRequest request) =>
      _executeNamed(LiveEditMcpToolNames.startSession, request);

  Future<CallToolResult> liveEditUpdateDraft(final CallToolRequest request) =>
      _executeNamed(LiveEditMcpToolNames.updateDraft, request);

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

  static String _description(final String name, final String fallback) =>
      _catalog.specFor(name)?.description ?? fallback;

  static Schema _inferenceConfigSchema() => Schema.object(
    properties: <String, Schema>{
      'model': Schema.string(),
      'reasoningEffort': Schema.string(),
    },
    additionalProperties: false,
  );

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
}
