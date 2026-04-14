import 'package:flutter_live_edit_toolkit/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiveEditDraftChange v2 deserialization', () {
    test('parses minimal valid v2 JSON', () {
      final json = <String, Object?>{
        'nodeId': 'node-1',
        'propertyId': 'color',
        'targetValue': '#ff0000',
        'previewMode': 'exact',
        'targetContext': <String, Object?>{
          'targetDomain': 'appScene',
          'surfaceId': 'node-1',
        },
      };
      final change = LiveEditDraftChange.fromJson(json);
      expect(change.nodeId, 'node-1');
      expect(change.propertyId, 'color');
      expect(change.targetContext, isNotNull);
      expect(change.targetContext!.targetDomain, 'appScene');
    });

    test('targetContext is null when absent', () {
      final json = <String, Object?>{
        'nodeId': 'node-2',
        'propertyId': 'text',
        'targetValue': 'hello',
        'previewMode': 'exact',
      };
      final change = LiveEditDraftChange.fromJson(json);
      expect(change.targetContext, isNull);
    });

    test('round-trips through toJson/fromJson', () {
      final original = LiveEditDraftChange(
        nodeId: 'abc',
        propertyId: 'opacity',
        targetValue: 0.5,
        previewMode: LiveEditPreviewMode.exact,
        targetContext: DraftTargetContext(
          targetDomain: 'appScene',
          surfaceId: 'abc',
        ),
      );
      final roundTripped = LiveEditDraftChange.fromJson(original.toJson());
      expect(roundTripped.nodeId, original.nodeId);
      expect(roundTripped.propertyId, original.propertyId);
      expect(roundTripped.targetValue, original.targetValue);
      expect(
        roundTripped.targetContext?.targetDomain,
        original.targetContext?.targetDomain,
      );
    });
  });

  group('LiveEditResolutionRequest v2 deserialization', () {
    test('parses minimal valid v2 JSON', () {
      final json = <String, Object?>{
        'sessionId': 'sess-1',
        'bubbleId': 'bubble-1',
        'workingDirectory': '/tmp/project',
        'backendId': 'codex',
      };
      final req = LiveEditResolutionRequest.fromJson(json);
      expect(req.sessionId, 'sess-1');
      expect(req.bubbleId, 'bubble-1');
      expect(req.backendId, 'codex');
    });

    test('effectiveInstructionText reads instructionText only', () {
      const req = LiveEditResolutionRequest(
        sessionId: 's',
        bubbleId: 'b',
        workingDirectory: '/tmp',
        instructionText: 'change color to red',
      );
      expect(req.effectiveInstructionText, 'change color to red');
    });

    test('effectivePrimarySelection reads primarySelection only', () {
      const selection = LiveEditSelection(
        sessionId: 's',
        nodeId: 'node-1',
        widgetType: 'Text',
        rawNode: <String, Object?>{},
      );
      const req = LiveEditResolutionRequest(
        sessionId: 's',
        bubbleId: 'b',
        workingDirectory: '/tmp',
        primarySelection: selection,
      );
      expect(req.effectivePrimarySelection?.nodeId, 'node-1');
    });

    test('toJson does not emit v1 aliases', () {
      const req = LiveEditResolutionRequest(
        sessionId: 's',
        bubbleId: 'b',
        workingDirectory: '/tmp',
        instructionText: 'make it red',
      );
      final json = req.toJson();
      expect(json.containsKey('intentText'), isFalse);
      expect(json.containsKey('selection'), isFalse);
      expect(json.containsKey('evidence'), isFalse);
      expect(json.containsKey('meta'), isFalse);
      expect(json['instructionText'], 'make it red');
    });
  });

  group('SelectionKey v2 deserialization', () {
    test('parses string value directly', () {
      final key = SelectionKey.fromJson('my-key');
      expect(key, 'my-key');
    });

    test('non-string coerces to string representation', () {
      final key = SelectionKey.fromJson(42);
      expect(key, '42');
    });
  });

  group('InteractionSelectionSet', () {
    test('empty set has no members', () {
      expect(InteractionSelectionSet.empty.isEmpty, isTrue);
      expect(InteractionSelectionSet.empty.memberKeys, isEmpty);
    });

    test('normalized with members produces primary key', () {
      final set = InteractionSelectionSet(
        memberKeys: const ['b', 'a'],
        origin: InteractionSelectionOrigin.tap,
      );
      expect(set.primaryKey, isNotNull);
      expect(set.memberKeys, contains(set.primaryKey));
    });

    test('origin is preserved', () {
      final set = InteractionSelectionSet(
        memberKeys: const ['x'],
        origin: InteractionSelectionOrigin.marquee,
      );
      expect(set.origin, InteractionSelectionOrigin.marquee);
    });
  });
}
