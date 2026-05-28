import 'package:collection/collection.dart';
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

import 'package:mcp_toolkit/src/toolkits/interaction_toolkit.dart';

/// App dynamic tools vs `fmt_*` catalog parity.
///
/// Thirteen tools from [getInteractionToolkitEntries] in
/// `interaction_toolkit.dart` (`registerDynamics`) are asserted here against
/// shared maps in `interaction_input_schemas.dart` (`flutter_mcp_toolkit_core`).
/// Host `fmt_*` registrations live in `packages/server_capability_core/lib/src/tools/*_tools.dart`.
///
/// **Five server-only catalog tools** (CLI `exec` + `fmt_*`, no app dynamic twin):
/// - `fill_form` — `interaction_tools.dart`
/// - `hot_reload_flutter`, `hot_restart_flutter` — `flutter_inspector_tools.dart`
/// - `evaluate_dart_expression`, `hot_reload_and_capture` — `interaction_tools.dart`
///
/// Full schema router parity (18 core, 22 tier A exec, 24 in
/// `interactionCatalogInputSchemaFor`) is in
/// `packages/server_capability_core/test/tools/interaction_input_schemas_test.dart`.
void main() {
  const schemaEquality = DeepCollectionEquality();

  Map<String, Object?> appInputSchema(final String toolName) =>
      getInteractionToolkitEntries().byName(toolName).toRegistration().descriptor.inputSchema;

  group('interaction_toolkit vs fmt_* catalog (shared core schemas)', () {
    test('tap_widget', () {
      final schema = appInputSchema('tap_widget');
      expect(
        schemaEquality.equals(schema, tapWidgetInputSchema()),
        isTrue,
        reason: 'must match server_capability_core / fmt_tap_widget',
      );
      expect(schema['additionalProperties'], isFalse);
      expect(schema['required'], ['ref']);
      final props = schema['properties'] as Map<String, Object?>;
      expect(props.containsKey('connection'), isTrue);
      expect(props.containsKey('ref'), isTrue);
      expect(props.containsKey('snapshotId'), isTrue);
    });

    test('semantic_snapshot', () {
      final schema = appInputSchema('semantic_snapshot');
      expect(
        schemaEquality.equals(schema, semanticSnapshotInputSchema()),
        isTrue,
        reason: 'must match server_capability_core / fmt_semantic_snapshot',
      );
      expect(schema['additionalProperties'], isFalse);
      expect(schema.containsKey('required'), isFalse);
      final props = schema['properties'] as Map<String, Object?>;
      expect(props.containsKey('connection'), isTrue);
    });

    test('wait_for', () {
      final schema = appInputSchema('wait_for');
      expect(
        schemaEquality.equals(schema, waitForInputSchema()),
        isTrue,
        reason: 'must match server_capability_core / fmt_wait_for',
      );
      expect(schema['additionalProperties'], isFalse);
      expect(schema['required'], ['predicate']);
      final props = schema['properties'] as Map<String, Object?>;
      final predicate = props['predicate'] as Map<String, Object?>;
      expect(predicate['additionalProperties'], isTrue);
      expect(props.containsKey('connection'), isTrue);
      expect(props.containsKey('timeoutMs'), isTrue);
    });

    test('get_recent_logs', () {
      final schema = appInputSchema('get_recent_logs');
      expect(
        schemaEquality.equals(schema, getRecentLogsInputSchema()),
        isTrue,
        reason: 'must match server_capability_core / fmt_get_recent_logs',
      );
      expect(schema['additionalProperties'], isFalse);
      expect(schema.containsKey('required'), isFalse);
      final props = schema['properties'] as Map<String, Object?>;
      expect((props['count']! as Map<String, Object?>)['type'], 'integer');
      expect(props.containsKey('connection'), isTrue);
    });

    test('handle_dialog', () {
      final schema = appInputSchema('handle_dialog');
      expect(
        schemaEquality.equals(schema, handleDialogInputSchema()),
        isTrue,
        reason: 'must match server_capability_core / fmt_handle_dialog',
      );
      expect(schema['additionalProperties'], isFalse);
      expect(schema['required'], ['action']);
      final props = schema['properties'] as Map<String, Object?>;
      expect(props.containsKey('connection'), isTrue);
    });

    test('navigate', () {
      final schema = appInputSchema('navigate');
      expect(
        schemaEquality.equals(schema, navigateInputSchema()),
        isTrue,
        reason: 'must match server_capability_core / fmt_navigate',
      );
      expect(schema['additionalProperties'], isFalse);
      expect(schema['required'], ['action']);
      final props = schema['properties'] as Map<String, Object?>;
      final arguments = props['arguments'] as Map<String, Object?>;
      expect(arguments['additionalProperties'], isTrue);
      expect(props.containsKey('connection'), isTrue);
    });

    for (final tool in <(String, Map<String, Object?> Function())>[
      ('enter_text', enterTextInputSchema),
      ('scroll', scrollInputSchema),
      ('long_press', longPressInputSchema),
      ('swipe', swipeInputSchema),
      ('drag', dragInputSchema),
      ('hover', hoverInputSchema),
      ('press_key', pressKeyInputSchema),
    ]) {
      test(tool.$1, () {
        final schema = appInputSchema(tool.$1);
        expect(
          schemaEquality.equals(schema, tool.$2()),
          isTrue,
          reason: 'must match server_capability_core / fmt_${tool.$1}',
        );
        expect(schema['additionalProperties'], isFalse);
      });
    }
  });
}
