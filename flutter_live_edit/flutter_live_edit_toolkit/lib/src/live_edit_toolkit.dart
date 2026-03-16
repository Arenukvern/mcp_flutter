import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

import 'commands/commands.dart';
import 'live_edit_runtime.dart';

Map<String, Object?> _noContext() => <String, Object?>{
  'error': 'No live edit context',
};

Set<MCPCallEntry> getFlutterLiveEditEntries() => <MCPCallEntry>{
  MCPCallEntry.tool(
    definition: MCPToolDefinition(
      name: LiveEditRuntimeToolNames.startSession,
      description: 'Start or reuse a live edit session in the running app.',
      inputSchema: ObjectSchema(
        properties: <String, Schema>{
          'sessionId': StringSchema(
            description: 'Optional explicit session identifier',
          ),
          'targetDomain': StringSchema(),
        },
      ),
    ),
    handler: (final request) {
      final ctx = LiveEditRuntime.currentContext;
      if (ctx == null) {
        return MCPCallResult(
          message: 'Live edit session started.',
          parameters: _noContext(),
        );
      }
      final result = StartSessionCommand(
        requestedSessionId: request['sessionId'],
        targetDomain: LiveEditTargetDomain.fromWire(request['targetDomain']),
      ).execute(ctx);
      return MCPCallResult(
        message: 'Live edit session started.',
        parameters: result,
      );
    },
  ),
  MCPCallEntry.tool(
    definition: MCPToolDefinition(
      name: LiveEditRuntimeToolNames.setOverlay,
      description: 'Enable or disable the live edit overlay in the app.',
      inputSchema: ObjectSchema(
        required: const <String>['enabled'],
        properties: <String, Schema>{
          'sessionId': StringSchema(),
          'enabled': BooleanSchema(),
        },
      ),
    ),
    handler: (final request) {
      final ctx = LiveEditRuntime.currentContext;
      if (ctx == null) {
        return MCPCallResult(
          message: 'Live edit overlay updated.',
          parameters: _noContext(),
        );
      }
      final result = SetOverlayCommand(
        sessionId: request['sessionId'],
        enabled: _parseBool(request['enabled']),
      ).execute(ctx);
      return MCPCallResult(
        message: 'Live edit overlay updated.',
        parameters: result,
      );
    },
  ),
  MCPCallEntry.tool(
    definition: MCPToolDefinition(
      name: LiveEditRuntimeToolNames.getTree,
      description: 'Get the current widget summary tree for the session.',
      inputSchema: ObjectSchema(
        properties: <String, Schema>{
          'sessionId': StringSchema(),
          'targetDomain': StringSchema(),
        },
      ),
    ),
    handler: (final request) {
      final ctx = LiveEditRuntime.currentContext;
      if (ctx == null) {
        return MCPCallResult(
          message: 'Live edit tree captured.',
          parameters: _noContext(),
        );
      }
      final result = GetTreeCommand(
        sessionId: request['sessionId'],
        targetDomain: request['targetDomain'] == null
            ? null
            : LiveEditTargetDomain.fromWire(request['targetDomain']),
      ).execute(ctx);
      return MCPCallResult(
        message: 'Live edit tree captured.',
        parameters: result,
      );
    },
  ),
  MCPCallEntry.tool(
    definition: MCPToolDefinition(
      name: LiveEditRuntimeToolNames.selectAtPoint,
      description:
          'Select a live edit widget at global logical coordinates using an optional selection policy.',
      inputSchema: ObjectSchema(
        required: const <String>['x', 'y'],
        properties: <String, Schema>{
          'sessionId': StringSchema(),
          'x': IntegerSchema(),
          'y': IntegerSchema(),
          'viewId': IntegerSchema(),
          'selectionPolicy': StringSchema(),
          'targetDomain': StringSchema(),
        },
      ),
    ),
    handler: (final request) {
      final ctx = LiveEditRuntime.currentContext;
      if (ctx == null) {
        return MCPCallResult(
          message: 'Live edit selection updated.',
          parameters: _noContext(),
        );
      }
      final result = SelectAtPointCommand(
        sessionId: request['sessionId'],
        x: _parseInt(request['x']),
        y: _parseInt(request['y']),
        viewId: _parseNullableInt(request['viewId']),
        selectionPolicy: LiveEditSelectionPolicy.fromWire(
          request['selectionPolicy'],
        ),
        targetDomain: request['targetDomain'] == null
            ? null
            : LiveEditTargetDomain.fromWire(request['targetDomain']),
      ).execute(ctx);
      return MCPCallResult(
        message: 'Live edit selection updated.',
        parameters: result,
      );
    },
  ),
  MCPCallEntry.tool(
    definition: MCPToolDefinition(
      name: LiveEditRuntimeToolNames.getSelection,
      description: 'Get the currently selected live edit node.',
      inputSchema: ObjectSchema(
        properties: <String, Schema>{
          'sessionId': StringSchema(),
          'targetDomain': StringSchema(),
        },
      ),
    ),
    handler: (final request) {
      final ctx = LiveEditRuntime.currentContext;
      if (ctx == null) {
        return MCPCallResult(
          message: 'Live edit selection state returned.',
          parameters: _noContext(),
        );
      }
      final result = GetSelectionCommand(
        sessionId: request['sessionId'],
        targetDomain: request['targetDomain'] == null
            ? null
            : LiveEditTargetDomain.fromWire(request['targetDomain']),
      ).execute(ctx);
      return MCPCallResult(
        message: 'Live edit selection state returned.',
        parameters: result,
      );
    },
  ),
  MCPCallEntry.tool(
    definition: MCPToolDefinition(
      name: LiveEditRuntimeToolNames.updateDraft,
      description: 'Update one draft change for the selected live edit node.',
      inputSchema: ObjectSchema(
        required: const <String>['changeJson'],
        properties: <String, Schema>{
          'sessionId': StringSchema(),
          'changeJson': StringSchema(
            description: 'JSON-encoded LiveEditDraftChange payload',
          ),
        },
      ),
    ),
    handler: (final request) {
      final change = LiveEditDraftChange.fromJson(
        decodeLiveEditJsonObject(request['changeJson'] ?? '{}'),
      );
      final ctx = LiveEditRuntime.currentContext;
      if (ctx == null) {
        return MCPCallResult(
          message: 'Live edit draft updated.',
          parameters: _noContext(),
        );
      }
      final result = UpdateDraftCommand(
        sessionId: request['sessionId'],
        change: change,
      ).execute(ctx);
      return MCPCallResult(
        message: 'Live edit draft updated.',
        parameters: result,
      );
    },
  ),
  MCPCallEntry.tool(
    definition: MCPToolDefinition(
      name: LiveEditRuntimeToolNames.getDraft,
      description: 'Get the current draft changes for the session.',
      inputSchema: ObjectSchema(
        properties: <String, Schema>{
          'sessionId': StringSchema(),
          'targetDomain': StringSchema(),
        },
      ),
    ),
    handler: (final request) {
      final ctx = LiveEditRuntime.currentContext;
      if (ctx == null) {
        return MCPCallResult(
          message: 'Live edit draft returned.',
          parameters: _noContext(),
        );
      }
      final result = GetDraftCommand(
        sessionId: request['sessionId'],
        targetDomain: request['targetDomain'] == null
            ? null
            : LiveEditTargetDomain.fromWire(request['targetDomain']),
      ).execute(ctx);
      return MCPCallResult(
        message: 'Live edit draft returned.',
        parameters: result,
      );
    },
  ),
  MCPCallEntry.tool(
    definition: MCPToolDefinition(
      name: LiveEditRuntimeToolNames.discardDraft,
      description: 'Discard all current draft changes for the session.',
      inputSchema: ObjectSchema(
        properties: <String, Schema>{'sessionId': StringSchema()},
      ),
    ),
    handler: (final request) {
      final ctx = LiveEditRuntime.currentContext;
      if (ctx == null) {
        return MCPCallResult(
          message: 'Live edit draft discarded.',
          parameters: _noContext(),
        );
      }
      final result = DiscardDraftCommand(
        sessionId: request['sessionId'],
      ).execute(ctx);
      return MCPCallResult(
        message: 'Live edit draft discarded.',
        parameters: result,
      );
    },
  ),
  MCPCallEntry.tool(
    definition: MCPToolDefinition(
      name: LiveEditRuntimeToolNames.endSession,
      description: 'End the current live edit session.',
      inputSchema: ObjectSchema(
        properties: <String, Schema>{'sessionId': StringSchema()},
      ),
    ),
    handler: (final request) {
      final ctx = LiveEditRuntime.currentContext;
      if (ctx == null) {
        return MCPCallResult(
          message: 'Live edit session ended.',
          parameters: _noContext(),
        );
      }
      final result = EndSessionCommand(
        sessionId: request['sessionId'],
      ).execute(ctx);
      return MCPCallResult(
        message: 'Live edit session ended.',
        parameters: result,
      );
    },
  ),
};

extension FlutterLiveEditBindingExtension on MCPToolkitBinding {
  void initializeFlutterLiveEditToolkit() =>
      addEntries(entries: getFlutterLiveEditEntries());
}

bool _parseBool(final Object? value) {
  if (value is bool) {
    return value;
  }
  final normalized = '$value'.trim().toLowerCase();
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

int _parseInt(final Object? value) => _parseNullableInt(value) ?? 0;

int? _parseNullableInt(final Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  return int.tryParse('$value');
}
