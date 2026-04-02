import 'package:flutter_live_edit_toolkit/src/models/models.dart';
import 'package:flutter_live_edit_toolkit/src/services/live_edit_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiveEditSessionService selection summaries', () {
    test('selection summary prefers rawNode values over layoutContext', () {
      final service = LiveEditSessionService();
      final selection = LiveEditSelection(
        sessionId: 'session-1',
        selectionKey: ' key-1 ',
        nodeId: ' node-1 ',
        widgetType: ' Container ',
        rawNode: <String, Object?>{
          'routeId': ' route-from-raw ',
          'screenId': ' screen-from-raw ',
          'surfaceId': ' surface-from-raw ',
        },
        layoutContext: <String, Object?>{
          'routeId': 'route-from-layout',
          'screenId': 'screen-from-layout',
          'surfaceId': 'surface-from-layout',
        },
        source: const LiveEditSourceLocation(
          file: 'lib/main.dart',
          sourceHint: 'app',
        ),
        propertiesForWire: const <Object?>[
          <String, Object?>{'id': 'color'},
        ],
      );

      final summary = service.debugSelectionSummaryForTesting(selection);

      expect(summary.selectionKey, 'key-1');
      expect(summary.nodeId, 'node-1');
      expect(summary.widgetType, 'Container');
      expect(summary.routeId, 'route-from-raw');
      expect(summary.screenId, 'screen-from-raw');
      expect(summary.surfaceId, 'surface-from-raw');
      expect(summary.ownedByLocalProject, isTrue);
      expect(summary.hasProjectSourceHint, isTrue);
      expect(summary.actionable, isTrue);
    });

    test(
      'selection summary falls back to layoutContext when rawNode is empty',
      () {
        final service = LiveEditSessionService();
        final selection = LiveEditSelection(
          sessionId: 'session-2',
          selectionKey: '',
          nodeId: 'node-2',
          widgetType: 'Text',
          rawNode: const <String, Object?>{'routeId': '   ', 'screenId': null},
          layoutContext: const <String, Object?>{
            'routeId': 'route-from-layout',
            'screenId': 'screen-from-layout',
            'surfaceId': 'surface-from-layout',
          },
        );

        final summary = service.debugSelectionSummaryForTesting(selection);

        expect(summary.selectionKey, 'node-2');
        expect(summary.routeId, 'route-from-layout');
        expect(summary.screenId, 'screen-from-layout');
        expect(summary.surfaceId, 'surface-from-layout');
        expect(summary.ownedByLocalProject, isFalse);
        expect(summary.hasProjectSourceHint, isFalse);
        expect(summary.actionable, isFalse);
      },
    );

    test('candidate summary uses typed candidate fields', () {
      final service = LiveEditSessionService();
      final candidate = LiveEditSelectionCandidate(
        selectionKey: '',
        nodeId: ' node-candidate ',
        widgetType: ' GestureDetector ',
        source: const LiveEditSourceLocation(file: 'lib/view.dart'),
        createdByLocalProject: true,
      );

      final summary = service.debugSelectionCandidateSummaryForTesting(
        candidate,
      );

      expect(summary.selectionKey, 'node-candidate');
      expect(summary.nodeId, 'node-candidate');
      expect(summary.widgetType, 'GestureDetector');
      expect(summary.routeId, isNull);
      expect(summary.screenId, isNull);
      expect(summary.surfaceId, isNull);
      expect(summary.ownedByLocalProject, isTrue);
      expect(summary.hasProjectSourceHint, isTrue);
      expect(summary.actionable, isTrue);
    });
  });

  group('LiveEditSessionService session bootstrap parsing', () {
    test('parses non-empty string session id', () {
      final service = LiveEditSessionService();

      final sessionId = service.debugParseRequiredSessionIdForTesting(
        ' session-123 ',
      );

      expect(sessionId, 'session-123');
    });

    test('throws when session id is not a string', () {
      final service = LiveEditSessionService();

      expect(
        () => service.debugParseRequiredSessionIdForTesting(42),
        throwsA(isA<StateError>()),
      );
    });

    test('throws when session id is empty after trim', () {
      final service = LiveEditSessionService();

      expect(
        () => service.debugParseRequiredSessionIdForTesting('   '),
        throwsA(isA<StateError>()),
      );
    });
  });
}
