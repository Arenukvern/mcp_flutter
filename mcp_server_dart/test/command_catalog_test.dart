import 'package:flutter_inspector_mcp_server/flutter_mcp_core.dart';
import 'package:flutter_live_edit_toolkit/flutter_live_edit_toolkit.dart';
import 'package:test/test.dart';

void main() {
  group('CommandCatalog', () {
    final catalog = CommandCatalog.instance;

    test('contains expected core commands', () {
      final names = catalog.commands.map((final c) => c.name).toSet();

      expect(names.contains('status'), isTrue);
      expect(names.contains('get_vm'), isTrue);
      expect(names.contains('hot_reload_flutter'), isTrue);
      expect(names.contains('session_start'), isTrue);
      expect(names.contains('session_exec'), isTrue);
      expect(names.contains('runClientTool'), isTrue);
      expect(names.contains('discover_debug_apps'), isTrue);
      expect(names.contains('inspect_widget_at_point'), isTrue);
      expect(names.contains('capture_ui_snapshot'), isTrue);
      expect(names.contains(LiveEditMcpToolNames.startSession), isTrue);
      expect(names.contains(LiveEditMcpToolNames.updateDraft), isTrue);
      expect(names.contains(LiveEditMcpToolNames.resolveDraft), isTrue);
      expect(names.contains(LiveEditMcpToolNames.applyDraft), isTrue);
      expect(names.contains(LiveEditMcpToolNames.acceptResolution), isTrue);
    });

    test('marks high-signal and low-signal MCP exposure explicitly', () {
      expect(catalog.specFor('discover_debug_apps')!.mcpExposed, isTrue);
      expect(catalog.specFor('inspect_widget_at_point')!.mcpExposed, isTrue);
      expect(catalog.specFor('capture_ui_snapshot')!.mcpExposed, isTrue);
      expect(
        catalog.specFor(LiveEditMcpToolNames.startSession)!.mcpExposed,
        isTrue,
      );
      expect(
        catalog.specFor(LiveEditMcpToolNames.resolveDraft)!.mcpExposed,
        isTrue,
      );
      expect(catalog.specFor('get_active_ports')!.mcpExposed, isFalse);
      expect(catalog.specFor('dynamicRegistryStats')!.mcpExposed, isFalse);
    });

    test('every command has input and output schemas', () {
      for (final command in catalog.commands) {
        expect(command.inputSchema['type'], equals('object'));
        expect(command.outputSchema, isA<Map<String, Object?>>());
        expect(command.description.isNotEmpty, isTrue);
      }
    });

    test('buildCommand supports canonical argument keys', () {
      final command = catalog.buildCommand('hot_reload_flutter', {
        'force': true,
      });

      expect(command, isA<HotReloadFlutterCommand>());
      expect((command as HotReloadFlutterCommand).force, isTrue);
    });

    test('capabilities expose feature and provider model', () {
      final capabilities = catalog.capabilities(
        configuration: const CoreRuntimeConfiguration(
          vmHost: 'localhost',
          vmPort: 8181,
          resourcesSupported: true,
          imagesSupported: true,
          dumpsSupported: false,
          dynamicRegistrySupported: true,
          saveImagesToFiles: false,
        ),
      );

      expect(capabilities.protocolVersion, equals(kFlutterMcpProtocolVersion));
      expect(capabilities.schemaVersion, equals('command-catalog/v1'));
      expect(capabilities.providers['summaryProviders'], isNotNull);
      expect(capabilities.features['serve'], isTrue);
      expect(capabilities.features['liveEdit'], isTrue);
      expect(capabilities.commands, isNotEmpty);
    });

    test('capabilities reflect liveEdit flag', () {
      final on = catalog.capabilities(
        configuration: const CoreRuntimeConfiguration(
          vmHost: 'localhost',
          vmPort: 8181,
          resourcesSupported: true,
          imagesSupported: true,
          dumpsSupported: false,
          dynamicRegistrySupported: true,
          saveImagesToFiles: false,
        ),
      );
      expect(on.features['liveEdit'], isTrue);

      final off = catalog.capabilities(
        configuration: const CoreRuntimeConfiguration(
          vmHost: 'localhost',
          vmPort: 8181,
          resourcesSupported: true,
          imagesSupported: true,
          dumpsSupported: false,
          liveEditSupported: false,
          dynamicRegistrySupported: true,
          saveImagesToFiles: false,
        ),
      );
      expect(off.features['liveEdit'], isFalse);
    });

    test('rejects unknown keys when command schema is strict by default', () {
      expect(
        () => catalog.buildCommand('status', {'unexpected': true}),
        throwsA(
          isA<ArgumentError>().having(
            (final error) => error.message,
            'message',
            contains('Unknown argument key'),
          ),
        ),
      );
    });

    test('rejects string-encoded booleans where bool is required', () {
      expect(
        () => catalog.buildCommand('hot_reload_flutter', {'force': 'true'}),
        throwsA(
          isA<ArgumentError>().having(
            (final error) => error.message,
            'message',
            contains('expected boolean'),
          ),
        ),
      );
    });

    test('accepts correctly typed payloads', () {
      final command = catalog.buildCommand('get_app_errors', {'count': 5});
      expect(command, isA<GetAppErrorsCommand>());
      expect((command as GetAppErrorsCommand).count, equals(5));
    });

    test('live edit catalog names match flutter_live_edit_core contract', () {
      final liveEditInCatalog = catalog.commands
          .map((final c) => c.name)
          .where((final n) => n.startsWith('live_edit_'))
          .toSet();
      expect(liveEditInCatalog, LiveEditMcpToolNames.allSorted.toSet());
    });

    test('builds live edit draft commands from structured payloads', () {
      final command = catalog.buildCommand(LiveEditMcpToolNames.updateDraft, {
        'sessionId': 'live-session',
        'change': {
          'nodeId': 'node-1',
          'propertyId': 'width',
          'targetValue': 140,
          'previewMode': 'ghost',
          'confidence': 0.9,
        },
      });

      expect(command, isA<LiveEditUpdateDraftCommand>());
      final update = command as LiveEditUpdateDraftCommand;
      expect(update.sessionId, 'live-session');
      expect(update.change.nodeId, 'node-1');
      expect(update.change.propertyId, 'width');
      expect(update.change.targetValue, 140);
      expect(update.change.previewMode, LiveEditPreviewMode.ghost);
    });

    test('live edit select-at-point keeps deepest policy when omitted', () {
      final command = catalog.buildCommand(LiveEditMcpToolNames.selectAtPoint, {
        'sessionId': 'live-session',
        'x': 120,
        'y': 240,
      });

      expect(command, isA<LiveEditSelectAtPointCommand>());
      final select = command as LiveEditSelectAtPointCommand;
      expect(select.selectionPolicy, LiveEditSelectionPolicy.deepest);
    });

    test(
      'builds live edit inference config payloads and normalizes middle',
      () {
        final prepare = catalog.buildCommand(
          LiveEditMcpToolNames.prepareSession,
          {
            'sessionId': 'live-session',
            'backendId': 'codex_exec',
            'inferenceConfig': {
              'model': 'GPT-5.3-Codex',
              'reasoningEffort': 'middle',
            },
          },
        );

        expect(prepare, isA<LiveEditPrepareSessionCommand>());
        final config =
            (prepare as LiveEditPrepareSessionCommand).inferenceConfig;
        expect(config?.model, 'gpt-5.3-codex');
        expect(config?.reasoningEffort, 'medium');
      },
    );

    test('parses codexConfig as backward compat for inferenceConfig', () {
      final prepare = catalog.buildCommand(
        LiveEditMcpToolNames.prepareSession,
        {
          'sessionId': 'live-session',
          'backendId': 'codex_exec',
          'codexConfig': {'model': 'GPT-5.4', 'reasoningEffort': 'high'},
        },
      );
      final config = (prepare as LiveEditPrepareSessionCommand).inferenceConfig;
      expect(config?.model, 'gpt-5.4');
      expect(config?.reasoningEffort, 'high');
    });

    test('exposes inferenceConfig in live edit command schemas', () {
      final prepareSchema =
          catalog
                  .specFor(LiveEditMcpToolNames.prepareSession)!
                  .inputSchema['properties']!
              as Map<String, Object?>;
      expect(prepareSchema.containsKey('inferenceConfig'), isTrue);

      final resolveSchema =
          catalog
                  .specFor(LiveEditMcpToolNames.resolveDraft)!
                  .inputSchema['properties']!
              as Map<String, Object?>;
      expect(resolveSchema.containsKey('inferenceConfig'), isTrue);

      final applySchema =
          catalog
                  .specFor(LiveEditMcpToolNames.applyDraft)!
                  .inputSchema['properties']!
              as Map<String, Object?>;
      expect(applySchema.containsKey('inferenceConfig'), isTrue);
    });

    test('parses screenshot permission policy fields', () {
      final command = catalog.buildCommand('get_screenshots', {
        'mode': 'auto',
        'permissionPolicy': 'auto_request_once',
      });

      expect(command, isA<GetScreenshotsCommand>());
      expect(
        (command as GetScreenshotsCommand).permissionPolicy,
        equals(PermissionPolicy.autoRequestOnce),
      );
    });

    test('adds optional connection schema for VM and wrapper commands', () {
      final getVmSchema =
          catalog.specFor('get_vm')!.inputSchema['properties']!
              as Map<String, Object?>;
      expect(getVmSchema.containsKey('connection'), isTrue);

      final watchSchema =
          catalog.specFor('watch')!.inputSchema['properties']!
              as Map<String, Object?>;
      expect(watchSchema.containsKey('connection'), isTrue);

      final sessionExecSchema =
          catalog.specFor('session_exec')!.inputSchema['properties']!
              as Map<String, Object?>;
      expect(sessionExecSchema.containsKey('connection'), isTrue);

      final statusSchema =
          catalog.specFor('status')!.inputSchema['properties']!
              as Map<String, Object?>;
      expect(statusSchema.containsKey('connection'), isFalse);

      final connectSchema =
          catalog.specFor('connect')!.inputSchema['properties']!
              as Map<String, Object?>;
      expect(connectSchema.containsKey('connection'), isFalse);
    });
  });
}
