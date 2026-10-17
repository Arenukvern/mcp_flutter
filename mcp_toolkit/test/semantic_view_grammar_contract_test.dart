import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/src/services/semantic_snapshot_service.dart';
import 'package:universal_automation_semantics/universal_automation_semantics.dart';

/// The ADR 0052 adoption contract: this package's `SemanticSnapshotFilter`
/// and the automation family's `SemanticView` are ONE wire grammar. The
/// shared selection keys (`identifierPrefix`/`subtreeOf`/`maxNodes`)
/// round-trip through both parsers; `fields` stays toolkit-side (the
/// snapshot node keys here are Flutter-shaped) until the vmService tier
/// unifies on the family's [SemanticField].
void main() {
  group('one wire grammar across repos', () {
    test('filter JSON parses as a family SemanticView, keys preserved',
        () {
      final filter = SemanticSnapshotFilter(
        identifierPrefix: 'nav.',
        subtreeOf: 'panel',
        maxNodes: 40,
      );
      final view = SemanticView.fromJson(filter.toJson());
      expect(view.identifierPrefix, 'nav.');
      expect(view.subtreeOf, 'panel');
      expect(view.maxNodes, 40);
    });

    test('toView() carries the same selection as the filter itself', () {
      final filter = SemanticSnapshotFilter.fromJson({
        'identifierPrefix': 'item-',
        'subtreeOf': 's_3',
        'maxNodes': 12,
      });
      final view = filter.toView();
      expect(view.identifierPrefix, 'item-');
      expect(view.subtreeOf, 's_3');
      expect(view.maxNodes, 12);
    });

    test('family view JSON (shared keys) parses back into the filter', () {
      const view = SemanticView(
        subtreeOf: 's_1',
        identifierPrefix: 'nav.',
        maxNodes: 5,
        panes: {'header': SemanticView(maxNodes: 2)},
      );
      final json = view.toJson()..remove('panes'); // panes: toolkit v1 gap
      final filter = SemanticSnapshotFilter.fromJson(json);
      expect(filter.subtreeOf, 's_1');
      expect(filter.identifierPrefix, 'nav.');
      expect(filter.maxNodes, 5);
    });

    test('blank selectors count as unasked in BOTH grammars', () {
      final view = SemanticView.fromJson({
        'identifierPrefix': '',
        'subtreeOf': '  ',
      });
      expect(view.isEmpty, isTrue);
      final filter = SemanticSnapshotFilter.fromJson({
        'identifierPrefix': '',
        'subtreeOf': '  ',
      });
      expect(filter.isEmpty, isTrue);
    });

    test('the family parser fails closed on unknown field names', () {
      // The toolkit's structured unknown_field error is its own tool
      // behavior; the family grammar refuses at parse time. Both are
      // loud — the difference is WHERE the refusal lands.
      expect(
        () => SemanticView.fromJson({'fields': ['aura']}),
        throwsFormatException,
      );
    });
  });
}
