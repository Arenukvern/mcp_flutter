import 'dart:convert';

import 'package:flutter_inspector_mcp_server/flutter_mcp_core.dart';
import 'package:flutter_inspector_mcp_server/src/capabilities/dynamic_registry/dynamic_registry_tools.dart';
import 'package:flutter_inspector_mcp_server/src/mcp_toolkit_server/core/core.dart';
import 'package:flutter_inspector_mcp_server/src/mcp_toolkit_server/handlers/resource_handler.dart';
import 'package:flutter_inspector_mcp_server/src/mcp_toolkit_server/handlers/vm_tools_handler.dart';
import 'package:test/test.dart';

void main() {
  group('connection override', () {
    test('parses nested connection object and executes connect', () async {
      final executor = _RecordingExecutor();

      final result = await applyConnectionOverrideFromArguments(
        arguments: {
          'connection': {
            'targetId': 'ws://127.0.0.1:8183/qwerty/ws',
            'forceReconnect': true,
          },
        },
        executor: executor,
      );

      expect(result, isNull);
      expect(executor.lastCommand, isA<ConnectCommand>());
      final command = executor.lastCommand! as ConnectCommand;
      expect(command.targetId, equals('ws://127.0.0.1:8183/qwerty/ws'));
      expect(command.forceReconnect, isTrue);
      expect(command.mode, equals(CoreConnectionMode.auto));
    });

    test('parses connection override from resource URI query', () async {
      final executor = _RecordingExecutor();

      final result = await applyConnectionOverrideFromResourceUri(
        resourceUri:
            'visual://localhost/view/details?targetId=ws%3A%2F%2F127.0.0.1%3A8183%2Fqwerty%2Fws&forceReconnect=true',
        executor: executor,
      );

      expect(result, isNull);
      expect(executor.lastCommand, isA<ConnectCommand>());
      final command = executor.lastCommand! as ConnectCommand;
      expect(command.targetId, equals('ws://127.0.0.1:8183/qwerty/ws'));
      expect(command.forceReconnect, isTrue);
    });

    test('invalid query port returns connect_failed', () async {
      final executor = _RecordingExecutor();

      final result = await applyConnectionOverrideFromResourceUri(
        resourceUri: 'visual://localhost/view/details?port=abc',
        executor: executor,
      );

      expect(result, isNotNull);
      expect(result!.error?.code, equals(CoreErrorCode.connectFailed));
    });

    test('rejects unknown fields in nested connection object', () async {
      final executor = _RecordingExecutor();

      final result = await applyConnectionOverrideFromArguments(
        arguments: {
          'connection': {
            'targetId': 'ws://127.0.0.1:8183/qwerty/ws',
            'unexpected': true,
          },
        },
        executor: executor,
      );

      expect(result, isNotNull);
      expect(result!.error?.code, equals(CoreErrorCode.invalidCommand));
      expect(result.error?.message.contains('unknown field'), isTrue);
      expect(executor.lastCommand, isNull);
    });

    test('core resolver removes connection and returns preconnect command', () {
      final resolved = resolveCommandArgumentsForExecution(
        commandName: 'get_vm',
        arguments: {
          'connection': {'targetId': 'ws://127.0.0.1:8183/qwerty/ws'},
          'count': 4,
        },
      );

      expect(resolved.error, isNull);
      expect(resolved.sanitizedArgs.containsKey('connection'), isFalse);
      expect(resolved.sanitizedArgs['count'], equals(4));
      expect(resolved.preconnectCommand, isNotNull);
      expect(
        resolved.preconnectCommand!.targetId,
        equals('ws://127.0.0.1:8183/qwerty/ws'),
      );
    });

    test('selection-required error is rendered as structured JSON', () {
      final text = formatCoreErrorForMcp(
        CoreResult.failure(
          code: CoreErrorCode.connectionSelectionRequired,
          message: 'Multiple debug targets detected',
          details: const {
            'reason': 'multiple_targets',
            'availableTargets': [
              {'targetId': 'ws://127.0.0.1:8181/abcd/ws'},
            ],
            'example': {
              'connection': {'targetId': 'ws://127.0.0.1:8181/abcd/ws'},
            },
          },
        ),
        prefix: 'Failed to connect',
      );

      final decoded = jsonDecode(text) as Map<String, Object?>;
      expect(
        decoded['code'],
        equals(CoreErrorCode.connectionSelectionRequired),
      );
      expect(decoded['details'], isA<Map<String, Object?>>());
    });
  });

  group('connection tool schema', () {
    test('vm and resource tool schemas require nested connection object', () {
      final vmSchema = VMToolsHandler.getVmTool.inputSchema;
      expect(vmSchema.additionalProperties, isFalse);
      expect(vmSchema.properties?.containsKey('connection'), isTrue);
      expect(vmSchema.properties?.containsKey('host'), isFalse);
      expect(vmSchema.properties?.containsKey('port'), isFalse);
      expect(vmSchema.properties?.containsKey('uri'), isFalse);

      final appErrorsSchema = ResourceHandler.getAppErrorsTool.inputSchema;
      expect(appErrorsSchema.additionalProperties, isFalse);
      expect(appErrorsSchema.properties?.containsKey('connection'), isTrue);
      expect(appErrorsSchema.properties?.containsKey('host'), isFalse);
      expect(appErrorsSchema.properties?.containsKey('port'), isFalse);
    });

    test('dynamic registry schemas include optional connection', () {
      final listSchema =
          DynamicRegistryTools.listClientToolsAndResources.inputSchema;
      expect(listSchema.additionalProperties, isFalse);
      expect(listSchema.properties?.containsKey('connection'), isTrue);

      final runToolSchema = DynamicRegistryTools.runClientTool.inputSchema;
      expect(runToolSchema.additionalProperties, isFalse);
      expect(runToolSchema.properties?.containsKey('connection'), isTrue);
      expect(runToolSchema.properties?.containsKey('toolName'), isTrue);

      final runResourceSchema =
          DynamicRegistryTools.runClientResource.inputSchema;
      expect(runResourceSchema.additionalProperties, isFalse);
      expect(runResourceSchema.properties?.containsKey('connection'), isTrue);
      expect(runResourceSchema.properties?.containsKey('resourceUri'), isTrue);
    });
  });
}

final class _RecordingExecutor implements CoreCommandExecutor {
  CoreCommand? lastCommand;

  @override
  Future<CoreResult> execute(final CoreCommand command) async {
    lastCommand = command;
    return CoreResult.success(data: const {'ok': true});
  }
}
