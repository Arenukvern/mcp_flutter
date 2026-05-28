import 'package:collection/collection.dart';
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';
import 'package:flutter_mcp_toolkit_server/flutter_mcp_core.dart';
import 'package:test/test.dart';

void main() {
  const schemaEquality = DeepCollectionEquality();

  group('CommandCatalog', () {
    final catalog = CommandCatalog.instance;

    test('contains expected core commands', () {
      final names = catalog.commands.map((final c) => c.name).toSet();

      expect(names.contains('status'), isTrue);
      expect(names.contains('get_vm'), isTrue);
      expect(names.contains('hot_reload_flutter'), isTrue);
      expect(names.contains('session_start'), isTrue);
      expect(names.contains('session_exec'), isTrue);
      expect(names.contains('fmt_client_tool'), isTrue);
      expect(names.contains('discover_debug_apps'), isTrue);
      expect(names.contains('inspect_widget_at_point'), isTrue);
      expect(names.contains('capture_ui_snapshot'), isTrue);
    });

    test('marks high-signal and low-signal MCP exposure explicitly', () {
      expect(catalog.specFor('discover_debug_apps')!.mcpExposed, isTrue);
      expect(catalog.specFor('inspect_widget_at_point')!.mcpExposed, isTrue);
      expect(catalog.specFor('capture_ui_snapshot')!.mcpExposed, isTrue);
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

    test('buildCommand resolves fmt_ prefix to bare exec names', () {
      final bare = catalog.buildCommand('get_recent_logs', {});
      final prefixed = catalog.buildCommand('fmt_get_recent_logs', {});
      expect(bare.runtimeType, prefixed.runtimeType);
    });

    test('buildCommand resolves bare names to fmt_ catalog entries', () {
      expect(
        catalog.buildCommand('client_tool', {'toolName': 'x', 'arguments': {}}),
        isA<RunClientToolCommand>(),
      );
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
      expect(capabilities.commands, isNotEmpty);
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

    test('rejects tap_widget without ref via shared interaction schema', () {
      expect(
        () => catalog.buildCommand('tap_widget', <String, Object?>{}),
        throwsA(
          isA<ArgumentError>().having(
            (final error) => error.message,
            'message',
            contains('ref'),
          ),
        ),
      );
    });

    test('rejects fill_form without fields via shared interaction schema', () {
      expect(
        () => catalog.buildCommand('fill_form', <String, Object?>{}),
        throwsA(
          isA<ArgumentError>().having(
            (final error) => error.message,
            'message',
            contains('fields'),
          ),
        ),
      );
    });

    test('rejects fill_form empty field item via shared schema', () {
      expect(
        () => catalog.buildCommand('fill_form', <String, Object?>{
          'fields': <Map<String, Object?>>[{}],
        }),
        throwsA(
          isA<ArgumentError>().having(
            (final error) => error.message,
            'message',
            contains('ref'),
          ),
        ),
      );
    });

    test('rejects fill_form field item missing ref via shared schema', () {
      expect(
        () => catalog.buildCommand('fill_form', <String, Object?>{
          'fields': <Map<String, Object?>>[
            {'text': 'x'},
          ],
        }),
        throwsA(
          isA<ArgumentError>().having(
            (final error) => error.message,
            'message',
            contains('ref'),
          ),
        ),
      );
    });

    test('rejects fill_form unknown keys via shared interaction schema', () {
      expect(
        () => catalog.buildCommand('fill_form', <String, Object?>{
          'fields': <Map<String, Object?>>[
            {'ref': 's_0', 'text': 'alice'},
          ],
          'unexpected': true,
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'rejects evaluate_dart_expression without expression via shared schema',
      () {
        expect(
          () => catalog.buildCommand('evaluate_dart_expression', {}),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('accepts evaluate_dart_expression with expression', () {
      final command = catalog.buildCommand('evaluate_dart_expression', {
        'expression': 'true',
      });
      expect(command, isA<EvaluateDartExpressionCommand>());
    });

    test('accepts hot_reload_and_capture with empty args', () {
      final command = catalog.buildCommand('hot_reload_and_capture', {});
      expect(command, isA<HotReloadAndCaptureCommand>());
    });

    test('rejects semantic_snapshot with unknown keys', () {
      expect(
        () => catalog.buildCommand('semantic_snapshot', {
          'unexpected': true,
        }),
        throwsA(
          isA<ArgumentError>().having(
            (final error) => error.message,
            'message',
            anyOf(contains('Unknown argument key'), contains('Unknown property')),
          ),
        ),
      );
    });

    test('accepts semantic_snapshot with empty args', () {
      final command = catalog.buildCommand('semantic_snapshot', {});
      expect(command, isA<SemanticSnapshotCommand>());
    });

    test('hot_reload_flutter catalog schema matches shared core schema', () {
      expect(
        schemaEquality.equals(
          catalog.specFor('hot_reload_flutter')!.inputSchema,
          hotReloadFlutterInputSchema(),
        ),
        isTrue,
      );
    });

    test('hot_restart_flutter catalog schema matches shared core schema', () {
      expect(
        schemaEquality.equals(
          catalog.specFor('hot_restart_flutter')!.inputSchema,
          hotRestartFlutterInputSchema(),
        ),
        isTrue,
      );
    });

    test('get_screenshots catalog schema matches shared core schema', () {
      expect(
        schemaEquality.equals(
          catalog.specFor('get_screenshots')!.inputSchema,
          getScreenshotsInputSchema(),
        ),
        isTrue,
      );
    });

    test('capture_ui_snapshot catalog schema matches shared core schema', () {
      expect(
        schemaEquality.equals(
          catalog.specFor('capture_ui_snapshot')!.inputSchema,
          captureUiSnapshotInputSchema(),
        ),
        isTrue,
      );
    });

    test('get_view_details catalog schema matches shared core schema', () {
      expect(
        schemaEquality.equals(
          catalog.specFor('get_view_details')!.inputSchema,
          getViewDetailsInputSchema(),
        ),
        isTrue,
      );
    });

    test('inspect_widget_at_point catalog schema matches shared core schema', () {
      expect(
        schemaEquality.equals(
          catalog.specFor('inspect_widget_at_point')!.inputSchema,
          inspectWidgetAtPointInputSchema(),
        ),
        isTrue,
      );
    });

    test('get_app_errors catalog schema matches shared core schema', () {
      expect(
        schemaEquality.equals(
          catalog.specFor('get_app_errors')!.inputSchema,
          getAppErrorsInputSchema(),
        ),
        isTrue,
      );
    });

    test('focus_window catalog schema matches shared core schema', () {
      expect(
        schemaEquality.equals(
          catalog.specFor('focus_window')!.inputSchema,
          focusWindowInputSchema(),
        ),
        isTrue,
      );
    });

    test('rejects inspect_widget_at_point without x and y via shared schema', () {
      expect(
        () => catalog.buildCommand('inspect_widget_at_point', {}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('inspect_widget_at_point accepts origin coordinates', () {
      final command = catalog.buildCommand('inspect_widget_at_point', {
        'x': 0,
        'y': 0,
      });
      expect(command, isA<InspectWidgetAtPointCommand>());
      expect((command as InspectWidgetAtPointCommand).x, 0);
      expect((command as InspectWidgetAtPointCommand).y, 0);
    });

    test('rejects get_view_details unknown keys via shared schema', () {
      expect(
        () => catalog.buildCommand('get_view_details', {'unexpected': true}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects get_app_errors unknown keys via shared schema', () {
      expect(
        () => catalog.buildCommand('get_app_errors', {'unexpected': true}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects focus_window unknown keys via shared schema', () {
      expect(
        () => catalog.buildCommand('focus_window', {'unexpected': true}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects get_screenshots unknown keys via shared schema', () {
      expect(
        () => catalog.buildCommand('get_screenshots', {
          'unexpected': true,
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects capture_ui_snapshot unknown keys via shared schema', () {
      expect(
        () => catalog.buildCommand('capture_ui_snapshot', {
          'unexpected': true,
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects hot_reload_flutter unknown keys', () {
      expect(
        () => catalog.buildCommand('hot_reload_flutter', {
          'unexpected': true,
        }),
        throwsA(isA<ArgumentError>()),
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

    test('explain_errors parses allowExternalSummary alias', () {
      final command = catalog.buildCommand('explain_errors', {
        'allow-external-summary': true,
        'summaryProvider': 'openai',
      });
      expect(command, isA<ExplainErrorsCommand>());
      final explain = command as ExplainErrorsCommand;
      expect(explain.allowExternalSummary, isTrue);
      expect(explain.summaryProvider, equals('openai'));
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

    test('wait_for command is registered with predicate + timeout schema', () {
      final spec = catalog.specFor('wait_for');
      expect(spec, isNotNull);
      expect(spec!.mcpExposed, isTrue);

      final props = spec.inputSchema['properties']! as Map<String, Object?>;
      expect(props.containsKey('predicate'), isTrue);
      expect(props.containsKey('timeoutMs'), isTrue);
      final timeoutMs = props['timeoutMs']! as Map<String, Object?>;
      expect(timeoutMs['minimum'], 1);
      expect(timeoutMs['maximum'], 30000);

      final cmd = catalog.buildCommand('wait_for', {
        'predicate': {'kind': 'time', 'ms': 100},
        'timeoutMs': 1000,
      });
      expect(cmd, isA<WaitForCommand>());
      final wc = cmd as WaitForCommand;
      expect(wc.predicate['kind'], 'time');
      expect(wc.timeoutMs, 1000);
    });

    test('rejects wait_for timeoutMs above shared schema maximum', () {
      expect(
        () => catalog.buildCommand('wait_for', {
          'predicate': <String, Object?>{'kind': 'time', 'ms': 1},
          'timeoutMs': 30001,
        }),
        throwsA(
          isA<ArgumentError>().having(
            (final error) => error.message,
            'message',
            contains('30000'),
          ),
        ),
      );
    });

    test('rejects wait_for timeoutMs below shared schema minimum', () {
      expect(
        () => catalog.buildCommand('wait_for', {
          'predicate': <String, Object?>{'kind': 'time', 'ms': 1},
          'timeoutMs': 0,
        }),
        throwsA(
          isA<ArgumentError>().having(
            (final error) => error.message,
            'message',
            contains('timeoutMs'),
          ),
        ),
      );
    });

    test('press_key, handle_dialog, navigate commands are registered', () {
      for (final name in ['press_key', 'handle_dialog', 'navigate']) {
        final spec = catalog.specFor(name);
        expect(spec, isNotNull, reason: '$name spec missing');
        expect(spec!.mcpExposed, isTrue, reason: '$name not mcpExposed');
      }

      final pk =
          catalog.buildCommand('press_key', {'key': 'Enter', 'shift': true})
              as PressKeyCommand;
      expect(pk.key, 'Enter');
      expect(pk.shift, isTrue);

      final hd =
          catalog.buildCommand('handle_dialog', {'action': 'dismiss'})
              as HandleDialogCommand;
      expect(hd.action, 'dismiss');

      final nv =
          catalog.buildCommand('navigate', {
                'action': 'push',
                'route': '/settings',
              })
              as NavigateCommand;
      expect(nv.action, 'push');
      expect(nv.route, '/settings');
    });

    test('fill_form, hover commands are registered', () {
      for (final name in ['fill_form', 'hover']) {
        final spec = catalog.specFor(name);
        expect(spec, isNotNull, reason: '$name spec missing');
        expect(spec!.mcpExposed, isTrue, reason: '$name not mcpExposed');
      }

      final ff =
          catalog.buildCommand('fill_form', {
                'fields': <Map<String, Object?>>[
                  {'ref': 's_0', 'text': 'alice'},
                  {'ref': 's_1', 'text': 'bob'},
                ],
              })
              as FillFormCommand;
      expect(ff.fields, hasLength(2));
      expect(ff.fields.first['ref'], 's_0');
      expect(ff.fields.first['text'], 'alice');

      final hv = catalog.buildCommand('hover', {'ref': 's_3'}) as HoverCommand;
      expect(hv.ref, 's_3');
    });
  });
}
