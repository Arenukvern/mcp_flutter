import 'package:collection/collection.dart';
import 'package:flutter_mcp_toolkit_capability_core/src/tools/form_tools.dart';
import 'package:flutter_mcp_toolkit_capability_core/src/tools/flutter_inspector_tools.dart';
import 'package:flutter_mcp_toolkit_capability_core/src/tools/inspection_tools.dart';
import 'package:flutter_mcp_toolkit_capability_core/src/tools/interaction_tools.dart';
import 'package:flutter_mcp_toolkit_capability_core/src/tools/log_tools.dart';
import 'package:flutter_mcp_toolkit_capability_core/src/tools/navigation_tools.dart';
import 'package:flutter_mcp_toolkit_capability_core/src/tools/semantic_tools.dart';
import 'package:flutter_mcp_toolkit_capability_core/src/tools/wait_tools.dart';
import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';
import 'package:flutter_mcp_toolkit_capability_kernel/testing.dart';
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';
import 'package:test/test.dart';

import '../_test_helpers.dart';

void main() {
  const schemaEquality = DeepCollectionEquality();

  group('client resource read schemas', () {
    test('clientResourceReadInputSchema is strict uri-only', () {
      final schema = clientResourceReadInputSchema();
      expect(schema['additionalProperties'], isFalse);
      expect(schema['required'], ['uri']);
      expect((schema['properties']! as Map).keys, ['uri']);
    });

    test('clientResourceTemplateReadInputSchema adds optional count', () {
      final schema = clientResourceTemplateReadInputSchema();
      expect(schema['additionalProperties'], isFalse);
      expect(schema['required'], ['uri']);
      final props = schema['properties']! as Map<String, Object?>;
      expect(props.keys, containsAll(['uri', 'count']));
      expect((props['count']! as Map<String, Object?>)['type'], 'integer');
    });
  });

  group('interactionCatalogInputSchemaFor', () {
    test('core interaction catalog has nineteen tools', () {
      expect(coreInteractionCatalogCommandNames, hasLength(19));
      expect(coreInteractionCatalogCommandNames.toSet(), hasLength(19));
      expect(coreInteractionCatalogCommandNames, contains('reveal_search'));
    });

    test('tier A exec catalog is nineteen core plus four inspection', () {
      expect(tierAExecCatalogCommandNames, hasLength(23));
      expect(tierAExecCatalogCommandNames.toSet(), hasLength(23));
      expect(
        tierAExecCatalogCommandNames,
        containsAll(inspectionTierAExecCommandNames),
      );
      expect(
        tierAExecCatalogCommandNames,
        containsAll(coreInteractionCatalogCommandNames),
      );
    });

    test('router covers twenty-five command names including capture tools', () {
      expect(interactionCatalogInputSchemaForCommandNames, hasLength(25));
      expect(
        interactionCatalogInputSchemaForCommandNames.toSet(),
        hasLength(25),
      );
      expect(
        interactionCatalogInputSchemaForCommandNames,
        containsAll(captureTierAExecCommandNames),
      );

      for (final name in interactionCatalogInputSchemaForCommandNames) {
        final schema = interactionCatalogInputSchemaFor(name);
        expect(schema, isNotNull, reason: name);
        expect(schema!['type'], 'object');
        expect(schema['additionalProperties'], isFalse);
      }
    });

    test('returns null for commands outside the shared schema router', () {
      expect(interactionCatalogInputSchemaFor('not_a_catalog_tool'), isNull);
    });
  });

  FakeCapabilityContext catalogContext() {
    final ctx = FakeCapabilityContext(
      capabilityId: 'core',
      services: <Type, HostService>{CommandRunner: FakeCommandRunner()},
    );
    registerInteractionTools(ctx);
    registerSemanticTools(ctx);
    registerWaitTools(ctx);
    registerNavigationTools(ctx);
    registerLogTools(ctx);
    registerFormTools(ctx);
    registerInspectionTools(ctx);
    return ctx;
  }

  group('fmt_* catalog uses shared interaction_input_schemas', () {
    test('tap_widget', () {
      final ctx = catalogContext();
      expect(
        schemaEquality.equals(
          tapWidgetInputSchema(),
          ctx.registrationFor('tap_widget')!.inputSchema,
        ),
        isTrue,
      );
    });

    test('fill_form', () {
      final ctx = catalogContext();
      expect(
        schemaEquality.equals(
          fillFormInputSchema(),
          ctx.registrationFor('fill_form')!.inputSchema,
        ),
        isTrue,
      );
    });

    test('semantic_snapshot', () {
      final ctx = catalogContext();
      expect(
        schemaEquality.equals(
          semanticSnapshotInputSchema(),
          ctx.registrationFor('semantic_snapshot')!.inputSchema,
        ),
        isTrue,
      );
    });

    test('reveal_search', () {
      final ctx = catalogContext();
      expect(
        schemaEquality.equals(
          revealSearchInputSchema(),
          ctx.registrationFor('reveal_search')!.inputSchema,
        ),
        isTrue,
      );
    });

    test('wait_for', () {
      final ctx = catalogContext();
      expect(
        schemaEquality.equals(
          waitForInputSchema(),
          ctx.registrationFor('wait_for')!.inputSchema,
        ),
        isTrue,
      );
    });

    test('get_recent_logs', () {
      final ctx = catalogContext();
      expect(
        schemaEquality.equals(
          getRecentLogsInputSchema(),
          ctx.registrationFor('get_recent_logs')!.inputSchema,
        ),
        isTrue,
      );
    });

    test('handle_dialog', () {
      final ctx = catalogContext();
      expect(
        schemaEquality.equals(
          handleDialogInputSchema(),
          ctx.registrationFor('handle_dialog')!.inputSchema,
        ),
        isTrue,
      );
    });

    test('navigate', () {
      final ctx = catalogContext();
      expect(
        schemaEquality.equals(
          navigateInputSchema(),
          ctx.registrationFor('navigate')!.inputSchema,
        ),
        isTrue,
      );
    });

    test('evaluate_dart_expression', () {
      final ctx = catalogContext();
      expect(
        schemaEquality.equals(
          evaluateDartExpressionInputSchema(),
          ctx.registrationFor('evaluate_dart_expression')!.inputSchema,
        ),
        isTrue,
      );
    });

    test('hot_reload_and_capture', () {
      final ctx = catalogContext();
      expect(
        schemaEquality.equals(
          hotReloadAndCaptureInputSchema(),
          ctx.registrationFor('hot_reload_and_capture')!.inputSchema,
        ),
        isTrue,
      );
    });

    test('get_screenshots', () {
      final ctx = catalogContext();
      expect(
        schemaEquality.equals(
          getScreenshotsInputSchema(),
          ctx.registrationFor('get_screenshots')!.inputSchema,
        ),
        isTrue,
      );
    });

    test('capture_ui_snapshot', () {
      final ctx = catalogContext();
      expect(
        schemaEquality.equals(
          captureUiSnapshotInputSchema(),
          ctx.registrationFor('capture_ui_snapshot')!.inputSchema,
        ),
        isTrue,
      );
    });

    test('get_view_details', () {
      final ctx = catalogContext();
      expect(
        schemaEquality.equals(
          getViewDetailsInputSchema(),
          ctx.registrationFor('get_view_details')!.inputSchema,
        ),
        isTrue,
      );
    });

    test('inspect_widget_at_point', () {
      final ctx = catalogContext();
      expect(
        schemaEquality.equals(
          inspectWidgetAtPointInputSchema(),
          ctx.registrationFor('inspect_widget_at_point')!.inputSchema,
        ),
        isTrue,
      );
    });

    test('get_app_errors', () {
      final ctx = catalogContext();
      expect(
        schemaEquality.equals(
          getAppErrorsInputSchema(),
          ctx.registrationFor('get_app_errors')!.inputSchema,
        ),
        isTrue,
      );
    });

    test('focus_window', () {
      final ctx = catalogContext();
      expect(
        schemaEquality.equals(
          focusWindowInputSchema(),
          ctx.registrationFor('focus_window')!.inputSchema,
        ),
        isTrue,
      );
    });

    test('hot_reload_flutter', () {
      final ctx = FakeCapabilityContext(
        capabilityId: 'core',
        services: <Type, HostService>{CommandRunner: FakeCommandRunner()},
      );
      registerFlutterInspectorTools(ctx);
      expect(
        schemaEquality.equals(
          hotReloadFlutterInputSchema(),
          ctx.registrationFor('hot_reload_flutter')!.inputSchema,
        ),
        isTrue,
      );
    });

    test('hot_restart_flutter', () {
      final ctx = FakeCapabilityContext(
        capabilityId: 'core',
        services: <Type, HostService>{CommandRunner: FakeCommandRunner()},
      );
      registerFlutterInspectorTools(ctx);
      expect(
        schemaEquality.equals(
          hotRestartFlutterInputSchema(),
          ctx.registrationFor('hot_restart_flutter')!.inputSchema,
        ),
        isTrue,
      );
    });

    for (final tool in <(String, Map<String, Object?> Function())>[
      ('enter_text', enterTextInputSchema),
      ('reveal_search', revealSearchInputSchema),
      ('scroll', scrollInputSchema),
      ('long_press', longPressInputSchema),
      ('swipe', swipeInputSchema),
      ('drag', dragInputSchema),
      ('hover', hoverInputSchema),
      ('press_key', pressKeyInputSchema),
    ]) {
      test(tool.$1, () {
        final ctx = catalogContext();
        expect(
          schemaEquality.equals(
            tool.$2(),
            ctx.registrationFor(tool.$1)!.inputSchema,
          ),
          isTrue,
        );
      });
    }
  });
}
