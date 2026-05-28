import 'package:collection/collection.dart';
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

import 'package:mcp_toolkit/src/toolkits/flutter_mcp_toolkit.dart';

/// App inspection dynamic tools vs shared `interaction_input_schemas` parity.
///
/// Four tools from [getFlutterMcpToolkitEntries] (`registerDynamics` via
/// `ext.mcp.toolkit.*`) are asserted against factories in
/// `interaction_input_schemas.dart`. Host catalog names differ for three:
/// `app_errors` ↔ `get_app_errors`, `view_details` ↔ `get_view_details`,
/// `view_screenshots` ↔ `get_screenshots`.
///
/// Host `fmt_*` registrations live in
/// `packages/server_capability_core/lib/src/tools/inspection_tools.dart`.
/// Full router parity is in
/// `packages/server_capability_core/test/tools/interaction_input_schemas_test.dart`.
void main() {
  const schemaEquality = DeepCollectionEquality();

  Map<String, Object?> appInputSchema(final String toolName) =>
      getFlutterMcpToolkitEntries(binding: MCPToolkitBinding.instance)
          .byName(toolName)
          .toRegistration()
          .descriptor
          .inputSchema;

  group('flutter_mcp_toolkit inspection vs shared core schemas', () {
    test('app_errors', () {
      final schema = appInputSchema('app_errors');
      expect(
        schemaEquality.equals(schema, getAppErrorsInputSchema()),
        isTrue,
        reason: 'must match server_capability_core / fmt_get_app_errors',
      );
      expect(schema['additionalProperties'], isFalse);
      expect(schema.containsKey('required'), isFalse);
      final props = schema['properties'] as Map<String, Object?>;
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
      final props = schema['properties'] as Map<String, Object?>;
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
      final props = schema['properties'] as Map<String, Object?>;
      expect(props.containsKey('compress'), isTrue);
      expect(props.containsKey('mode'), isTrue);
      expect(props.containsKey('permissionPolicy'), isTrue);
      expect(props.containsKey('connection'), isTrue);
    });

    test('inspect_widget_at_point', () {
      final schema = appInputSchema('inspect_widget_at_point');
      expect(
        schemaEquality.equals(schema, inspectWidgetAtPointInputSchema()),
        isTrue,
        reason: 'must match server_capability_core / fmt_inspect_widget_at_point',
      );
      expect(schema['additionalProperties'], isFalse);
      expect(schema['required'], ['x', 'y']);
      final props = schema['properties'] as Map<String, Object?>;
      expect((props['x']! as Map<String, Object?>)['type'], 'integer');
      expect((props['y']! as Map<String, Object?>)['type'], 'integer');
      expect(props.containsKey('viewId'), isTrue);
      expect(props.containsKey('connection'), isTrue);
    });
  });
}
