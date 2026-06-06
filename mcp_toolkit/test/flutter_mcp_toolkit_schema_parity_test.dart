import 'package:collection/collection.dart';
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

/// App inspection tools from [getFlutterMcpToolkitEntries] vs shared catalog schemas.
///
/// VM extension / `fmt_client_tool` names (`app_errors`, `view_details`,
/// `view_screenshots`) differ from CLI `exec` / `fmt_*` names (`get_*`) — see
/// `flutter_test_app/INTENTCALL_PLATFORM.md`.
void main() {
  const schemaEquality = DeepCollectionEquality();

  Map<String, Object?> appInputSchema(final String toolName) =>
      getFlutterMcpToolkitEntries(
        binding: MCPToolkitBinding.instance,
      ).byName(toolName).toRegistration().descriptor.inputSchema;

  AgentCallEntry entryByName(final String toolName) =>
      getFlutterMcpToolkitEntries(
        binding: MCPToolkitBinding.instance,
      ).byName(toolName);

  group('flutter_mcp_toolkit vs fmt_* catalog (shared core schemas)', () {
    test('app_errors', () {
      final schema = appInputSchema('app_errors');
      expect(
        schemaEquality.equals(schema, getAppErrorsInputSchema()),
        isTrue,
        reason: 'must match server_capability_core / fmt_get_app_errors',
      );
      expect(schema['additionalProperties'], isFalse);
      expect(schema.containsKey('required'), isFalse);
      final props = schema['properties']! as Map<String, Object?>;
      expect((props['count']! as Map<String, Object?>)['type'], 'integer');
      expect(props.containsKey('connection'), isTrue);
    });

    test('view_details', () {
      final schema = appInputSchema('view_details');
      expect(
        schemaEquality.equals(schema, getViewDetailsInputSchema()),
        isTrue,
        reason: 'must match server_capability_core / fmt_get_view_details',
      );
      expect(schema['additionalProperties'], isFalse);
      expect(schema.containsKey('required'), isFalse);
      final props = schema['properties']! as Map<String, Object?>;
      expect(props.containsKey('connection'), isTrue);
    });

    test('view_screenshots', () {
      final schema = appInputSchema('view_screenshots');
      expect(
        schemaEquality.equals(schema, getScreenshotsInputSchema()),
        isTrue,
        reason: 'must match server_capability_core / fmt_get_screenshots',
      );
      expect(schema['additionalProperties'], isFalse);
      expect(schema.containsKey('required'), isFalse);
      final props = schema['properties']! as Map<String, Object?>;
      expect((props['compress']! as Map<String, Object?>)['type'], 'boolean');
      expect((props['mode']! as Map<String, Object?>)['type'], 'string');
      expect(
        (props['permissionPolicy']! as Map<String, Object?>)['type'],
        'string',
      );
      expect(props.containsKey('connection'), isTrue);
    });

    test('inspect_widget_at_point', () {
      final schema = appInputSchema('inspect_widget_at_point');
      expect(
        schemaEquality.equals(schema, inspectWidgetAtPointInputSchema()),
        isTrue,
        reason:
            'must match server_capability_core / fmt_inspect_widget_at_point',
      );
      expect(schema['additionalProperties'], isFalse);
      expect(schema['required'], ['x', 'y']);
      final props = schema['properties']! as Map<String, Object?>;
      expect(props.containsKey('connection'), isTrue);
      expect((props['x']! as Map<String, Object?>)['type'], 'integer');
      expect((props['y']! as Map<String, Object?>)['type'], 'integer');
      expect(props.containsKey('viewId'), isTrue);
    });

    test('select_widget_at_point', () {
      final schema = appInputSchema('select_widget_at_point');
      expect(
        schemaEquality.equals(schema, selectWidgetAtPointInputSchema()),
        isTrue,
        reason: 'must match shared selectWidgetAtPointInputSchema',
      );
      expect(schema['additionalProperties'], isFalse);
      expect(schema['required'], ['x', 'y']);
      final props = schema['properties']! as Map<String, Object?>;
      expect(props.containsKey('connection'), isTrue);
      expect((props['x']! as Map<String, Object?>)['type'], 'integer');
      expect((props['y']! as Map<String, Object?>)['type'], 'integer');
      expect(props.containsKey('viewId'), isTrue);
      expect(props.containsKey('sessionId'), isTrue);
      expect(props.containsKey('selectionPolicy'), isTrue);
      expect(props.containsKey('targetDomain'), isTrue);
    });

    test('registerDynamics shape is strict for inspect_widget_at_point', () {
      final descriptor = entryByName(
        'inspect_widget_at_point',
      ).toRegistration().descriptor;
      expect(descriptor.name, 'inspect_widget_at_point');
      expect(descriptor.inputSchema['additionalProperties'], isFalse);
      expect(descriptor.inputSchema['required'], ['x', 'y']);

      final registerDynamicsTool = {
        'name': descriptor.effectiveMethodName,
        'description': descriptor.description,
        'inputSchema': descriptor.inputSchema,
      };
      expect(registerDynamicsTool['name'], 'inspect_widget_at_point');
      expect(
        (registerDynamicsTool['inputSchema']! as Map)['additionalProperties'],
        isFalse,
      );
    });

    test('registerDynamics shape is strict for select_widget_at_point', () {
      final descriptor = entryByName(
        'select_widget_at_point',
      ).toRegistration().descriptor;
      expect(descriptor.name, 'select_widget_at_point');
      expect(descriptor.inputSchema['additionalProperties'], isFalse);
      expect(descriptor.inputSchema['required'], ['x', 'y']);

      final registerDynamicsTool = {
        'name': descriptor.effectiveMethodName,
        'description': descriptor.description,
        'inputSchema': descriptor.inputSchema,
      };
      expect(registerDynamicsTool['name'], 'select_widget_at_point');
      expect(
        (registerDynamicsTool['inputSchema']! as Map)['additionalProperties'],
        isFalse,
      );
    });
  });
}
