import 'package:collection/collection.dart';
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

/// Locks shared [interaction_tool_descriptions] to app dynamic registrations.
void main() {
  test('wait_for description matches core constant', () {
    final entry = getInteractionToolkitEntries().byName('wait_for');
    expect(entry.toRegistration().descriptor.description, waitForToolDescription);
  });

  test('semantic_snapshot description matches core constant', () {
    final entry = getInteractionToolkitEntries().byName('semantic_snapshot');
    expect(
      entry.toRegistration().descriptor.description,
      semanticSnapshotToolDescription,
    );
  });

  test('wait_for predicate schema documents changed and time.observe', () {
    final predicate =
        waitForInputSchema()['properties']! as Map<String, Object?>;
    final desc = (predicate['predicate']! as Map)['description']! as String;
    expect(desc, equals(waitForPredicateKindsDescription));
    expect(desc, contains('changed'));
    expect(desc, contains('observe'));
    expect(desc, contains('noError'));
    expect(desc, contains('node'));
  });
}