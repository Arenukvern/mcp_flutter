import 'package:flutter_live_edit_toolkit/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiveEditSchemas protocol v2', () {
    test('requires normalized transaction fields', () {
      const schema = LiveEditSchemas.protocolV2Transaction;
      final required = (schema['required'] as List<Object?>).map(
        (final key) => '$key',
      );

      expect(required, contains('intent'));
      expect(required, contains('targets'));
      expect(required, contains('patch'));
      expect(required, contains('validation'));
      expect(required, contains('apply'));
      expect(required, contains('rollback'));
      expect(required, contains('graph'));
    });

    test('target addressing includes screen/widget/animation/state', () {
      const schema = LiveEditSchemas.protocolV2Transaction;
      final properties = schema['properties']! as Map<String, Object?>;
      final targets = properties['targets']! as Map<String, Object?>;
      final items = targets['items']! as Map<String, Object?>;
      final targetProperties = items['properties']! as Map<String, Object?>;
      final kind = targetProperties['kind']! as Map<String, Object?>;
      final enumValues = (kind['enum']! as List<Object?>)
          .map((final item) => '$item')
          .toSet();

      expect(
        enumValues,
        containsAll(<String>{'screen', 'widget', 'animation', 'state'}),
      );
    });
  });

  group('LiveEditTransactionV2 fixture', () {
    test('round-trips fixture payload', () {
      final payload = <String, Object?>{
        'protocolVersion': 'live_edit_protocol/v2',
        'compatibilityMode': 'native_v2',
        'transactionId': 'tx-1',
        'sessionId': 'session-1',
        'baseRevision': 7,
        'workingRevision': 8,
        'intent': <String, Object?>{
          'intentId': 'intent-1',
          'summary': 'Change CTA color to red',
          'author': 'agent',
          'issuedAtMs': 1710000000,
          'tags': <String>['ui', 'color'],
        },
        'targets': <Map<String, Object?>>[
          <String, Object?>{
            'kind': 'widget',
            'key': 'inspector:cta-button',
            'widgetId': 'cta-button',
            'propertyPath': <String>['style', 'color'],
          },
          <String, Object?>{
            'kind': 'animation',
            'key': 'fade-in',
            'animationId': 'fade-in',
            'propertyPath': <String>['durationMs'],
          },
        ],
        'patch': <Map<String, Object?>>[
          <String, Object?>{
            'operationId': 'op-1',
            'op': 'set',
            'path': '/widgets/cta/style/color',
            'value': '#ff0000',
          },
        ],
        'validation': <Map<String, Object?>>[
          <String, Object?>{
            'stepId': 'step-hot-reload',
            'description': 'Hot reload succeeds',
            'required': true,
            'status': 'passed',
          },
        ],
        'apply': <String, Object?>{
          'status': 'applied',
          'runtimeAction': 'hot_reload',
        },
        'rollback': <String, Object?>{
          'policy': 'on_conflict',
          'triggered': false,
        },
        'graph': <String, Object?>{
          'nodes': <Map<String, Object?>>[
            <String, Object?>{
              'nodeId': 'intent',
              'kind': 'intent',
              'status': 'completed',
            },
            <String, Object?>{
              'nodeId': 'target',
              'kind': 'target',
              'status': 'completed',
              'dependsOn': <String>['intent'],
            },
          ],
        },
      };

      final transaction = LiveEditTransactionV2.fromJson(payload);
      final roundTripped = LiveEditTransactionV2.fromJson(transaction.toJson());

      expect(roundTripped.protocolVersion, LiveEditProtocolVersion.v2);
      expect(roundTripped.transactionId, 'tx-1');
      expect(roundTripped.intent.summary, 'Change CTA color to red');
      expect(roundTripped.targets, hasLength(2));
      expect(roundTripped.patch.single.op, LiveEditPatchOpV2.set);
      expect(
        roundTripped.validation.single.status,
        LiveEditValidationStatusV2.passed,
      );
      expect(roundTripped.apply.status, LiveEditApplyStatusV2.applied);
      expect(roundTripped.rollback.policy, LiveEditRollbackPolicyV2.onConflict);
      expect(roundTripped.graph.nodes, hasLength(2));
    });
  });

  group('LiveEditProtocolV2Resolver', () {
    test('detects stale base revision conflict', () {
      const incoming = LiveEditTransactionV2(
        transactionId: 'tx-stale',
        sessionId: 'session-1',
        baseRevision: 2,
        workingRevision: 2,
        intent: LiveEditIntentV2(
          intentId: 'intent-stale',
          summary: 'Legacy edit',
        ),
      );

      final conflict = LiveEditProtocolV2Resolver.detectConflict(
        incoming: incoming,
        inFlight: const <LiveEditTransactionV2>[],
        currentRevision: 3,
      );

      expect(conflict, isNotNull);
      expect(conflict!.kind, LiveEditConflictKindV2.staleBaseRevision);
    });

    test('detects overlapping target conflict for concurrent edits', () {
      const active = LiveEditTransactionV2(
        transactionId: 'tx-active',
        sessionId: 'session-1',
        baseRevision: 10,
        workingRevision: 10,
        intent: LiveEditIntentV2(intentId: 'intent-a', summary: 'A'),
        targets: <LiveEditTargetAddressV2>[
          LiveEditTargetAddressV2(
            kind: LiveEditTargetKindV2.widget,
            key: 'inspector:node-1',
            propertyPath: <String>['style', 'color'],
          ),
        ],
      );
      const incoming = LiveEditTransactionV2(
        transactionId: 'tx-incoming',
        sessionId: 'session-1',
        baseRevision: 10,
        workingRevision: 10,
        intent: LiveEditIntentV2(intentId: 'intent-b', summary: 'B'),
        targets: <LiveEditTargetAddressV2>[
          LiveEditTargetAddressV2(
            kind: LiveEditTargetKindV2.widget,
            key: 'inspector:node-1',
            propertyPath: <String>['style', 'color'],
          ),
        ],
      );

      final conflict = LiveEditProtocolV2Resolver.detectConflict(
        incoming: incoming,
        inFlight: <LiveEditTransactionV2>[active],
        currentRevision: 10,
      );

      expect(conflict, isNotNull);
      expect(conflict!.kind, LiveEditConflictKindV2.overlappingTarget);
      expect(conflict.conflictingTransactionId, 'tx-active');
    });

    test('rollback policy returns expected decision', () {
      const conflict = LiveEditConflictV2(
        kind: LiveEditConflictKindV2.overlappingTarget,
        message: 'collision',
      );

      expect(
        LiveEditProtocolV2Resolver.shouldRollback(
          policy: LiveEditRollbackPolicyV2.onConflict,
          conflict: conflict,
          hasValidationFailure: false,
        ),
        isTrue,
      );
      expect(
        LiveEditProtocolV2Resolver.shouldRollback(
          policy: LiveEditRollbackPolicyV2.onValidationFailure,
          conflict: null,
          hasValidationFailure: true,
        ),
        isTrue,
      );
      expect(
        LiveEditProtocolV2Resolver.shouldRollback(
          policy: LiveEditRollbackPolicyV2.manual,
          conflict: conflict,
          hasValidationFailure: true,
        ),
        isFalse,
      );
    });
  });

  group('LiveEditProtocolV2Compatibility', () {
    test(
      'adapts legacy point->bubble request to compatibility transaction',
      () {
        const selection = LiveEditSelection(
          sessionId: 'session-legacy',
          selectionKey: 'inspector:node-cta',
          nodeId: 'node-cta',
          widgetType: 'ElevatedButton',
          rawNode: <String, Object?>{'screenId': 'screen-home'},
        );
        const request = LiveEditResolutionRequest(
          sessionId: 'session-legacy',
          workingDirectory: '/tmp/workspace',
          bubbleId: 'bubble-123',
          instructionText: 'Make CTA red',
          primarySelection: selection,
        );

        final transaction =
            LiveEditProtocolV2Compatibility.fromLegacyResolutionRequest(
              request,
              baseRevision: 44,
            );

        expect(
          transaction.compatibilityMode,
          LiveEditProtocolCompatibilityMode.pointBubbleV1,
        );
        expect(transaction.transactionId, 'bubble-123');
        expect(transaction.targets.single.kind, LiveEditTargetKindV2.widget);
        expect(transaction.metadata['legacyApplyMode'], 'single_bubble');
      },
    );
  });

  group('LiveEditTransportEventV2', () {
    test('parses event fixture', () {
      final event = LiveEditTransportEventV2.fromJson(const <String, Object?>{
        'eventId': 'evt-1',
        'sessionId': 'session-1',
        'transactionId': 'tx-1',
        'sequence': 12,
        'timestampMs': 1710000001,
        'type': 'projection_updated',
        'payload': <String, Object?>{'timelineSize': 3},
      });

      expect(event.type, LiveEditTransportEventTypeV2.projectionUpdated);
      expect(event.sequence, 12);
      expect(event.payload['timelineSize'], 3);
    });
  });
}
