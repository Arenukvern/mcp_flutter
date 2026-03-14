import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';
import 'package:flutter_live_edit_core/src/live_edit_schemas.dart';
import 'package:test/test.dart';

void main() {
  test('selection serializes and deserializes', () {
    const selection = LiveEditSelection(
      sessionId: 'session-1',
      nodeId: 'node-1',
      widgetType: 'Container',
      renderObjectType: 'RenderConstrainedBox',
      bounds: LiveEditBounds(
        left: 10,
        top: 20,
        right: 110,
        bottom: 120,
        width: 100,
        height: 100,
      ),
      source: LiveEditSourceLocation(
        file: '/tmp/app.dart',
        line: 42,
        column: 7,
      ),
      propertyGroups: <LiveEditPropertyDescriptor>[
        LiveEditPropertyDescriptor(
          id: 'width',
          label: 'Width',
          group: LiveEditPropertyGroup.layout,
          kind: LiveEditPropertyKind.number,
          value: 100,
          editable: true,
          previewMode: LiveEditPreviewMode.ghost,
          persistable: true,
          requiresAgentForPersistence: true,
          safeToAutoGroupInApply: true,
        ),
      ],
      layoutContext: <String, Object?>{'parent': 'Column'},
      rawNode: <String, Object?>{'widgetType': 'Container'},
    );

    final decoded = LiveEditSelection.fromJson(selection.toJson());

    expect(decoded.sessionId, selection.sessionId);
    expect(decoded.nodeId, selection.nodeId);
    expect(decoded.propertyGroups.single.id, 'width');
    expect(decoded.bounds?.width, 100);
    expect(decoded.propertyGroups.single.requiresAgentForPersistence, isTrue);
  });

  test('resolution proposal serializes and deserializes', () {
    const proposal = LiveEditResolutionProposal(
      proposalId: 'proposal-1',
      backendId: 'codex_exec',
      summary: 'Adjust width',
      patch: '--- a/lib/main.dart',
      changedFiles: <String>['lib/main.dart'],
      filePatches: <LiveEditFilePatch>[
        LiveEditFilePatch(
          path: 'lib/main.dart',
          content: 'new content',
          patch: '@@ -1 +1 @@',
        ),
      ],
      expectedRuntimeEffects: <String>['Wider container'],
      validationSteps: <String>['Hot reload and compare width'],
      warnings: <String>['Review theme usage'],
      riskFlags: <String>['layout'],
    );

    final decoded = LiveEditResolutionProposal.fromJson(proposal.toJson());

    expect(decoded.proposalId, proposal.proposalId);
    expect(decoded.filePatches.single.path, 'lib/main.dart');
    expect(decoded.expectedRuntimeEffects.single, 'Wider container');
  });

  test('inference config normalizes middle to medium and round-trips', () {
    final config = LiveEditInferenceConfig.fromJson(<String, Object?>{
      'model': 'GPT-5.4',
      'reasoningEffort': 'middle',
    });

    expect(config.model, 'gpt-5.4');
    expect(config.reasoningEffort, 'medium');
    expect(config.toJson(), <String, Object?>{
      'model': 'gpt-5.4',
      'reasoningEffort': 'medium',
    });
  });

  test('runtime refresh result serializes and deserializes', () {
    const refresh = LiveEditRuntimeRefreshResult(
      action: LiveEditRuntimeAction.hotRestart,
      validation: <String, Object?>{'validated': true},
      hotReload: <String, Object?>{'ok': false},
      hotRestart: <String, Object?>{'ok': true},
      validationRecovery: <String, Object?>{'attempted': true},
    );

    final decoded = LiveEditRuntimeRefreshResult.fromJson(refresh.toJson());

    expect(decoded.action, LiveEditRuntimeAction.hotRestart);
    expect(decoded.validation['validated'], isTrue);
    expect(decoded.hotRestart['ok'], isTrue);
  });

  test(
    'resolution request accepts inferenceConfig and codexConfig (backward compat)',
    () {
      final fromInference = LiveEditResolutionRequest.fromJson(
        <String, Object?>{
          'sessionId': 's1',
          'workingDirectory': '/wd',
          'draftChanges': <Object?>[],
          'inferenceConfig': <String, Object?>{'model': 'gpt-5.4'},
        },
      );
      expect(fromInference.inferenceConfig?.model, 'gpt-5.4');

      final fromCodex = LiveEditResolutionRequest.fromJson(<String, Object?>{
        'sessionId': 's1',
        'workingDirectory': '/wd',
        'draftChanges': <Object?>[],
        'codexConfig': <String, Object?>{'model': 'gpt-5.3-codex'},
      });
      expect(fromCodex.inferenceConfig?.model, 'gpt-5.3-codex');

      const req = LiveEditResolutionRequest(
        sessionId: 's1',
        workingDirectory: '/wd',
        draftChanges: [],
        inferenceConfig: LiveEditInferenceConfig(model: 'x'),
      );
      expect(req.toJson().containsKey('inferenceConfig'), isTrue);
      expect(req.toJson()['codexConfig'], isNull);
    },
  );

  test('execution plan serializes and deserializes', () {
    const plan = LiveEditExecutionPlan(
      proposalId: 'proposal-1',
      title: 'Apply live edit',
      summary: 'Center the selected column.',
      selectedNode: 'Column',
      requestedChanges: <String>['Set mainAxisAlignment to center'],
      affectedFiles: <String>['lib/stateful_widget_example.dart'],
      confidence: 0.9,
      riskNotes: <String>['Touches widget layout'],
      agentInstruction: 'Center the selected Column in source.',
    );

    final decoded = LiveEditExecutionPlan.fromJson(plan.toJson());

    expect(decoded.proposalId, plan.proposalId);
    expect(decoded.requestedChanges.single, 'Set mainAxisAlignment to center');
    expect(decoded.agentInstruction, contains('Column'));
  });

  test('direct apply result retains runtime refresh metadata', () {
    const result = LiveEditDirectApplyResult(
      executionId: 'proposal-1',
      backendId: 'codex_exec',
      summary: 'Applied.',
      changedFiles: <String>['lib/main.dart'],
      warnings: <String>[],
      validationSteps: <String>['Reload and verify'],
      runtimeRefresh: LiveEditRuntimeRefreshResult(
        action: LiveEditRuntimeAction.hotReload,
        validation: <String, Object?>{'validated': true},
      ),
    );

    final decoded = LiveEditDirectApplyResult.fromJson(result.toJson());

    expect(decoded.runtimeRefresh?.action, LiveEditRuntimeAction.hotReload);
    expect(decoded.runtimeRefresh?.validation['validated'], isTrue);
  });

  test(
    'direct apply schema is closed and keeps model-owned fields minimal',
    () {
      final required =
          LiveEditSchemas.directApplyExecution['required'] as List<Object?>;
      final properties =
          LiveEditSchemas.directApplyExecution['properties']!
              as Map<String, Object?>;

      expect(required, <Object?>[
        'summary',
        'changedFiles',
        'warnings',
        'validationSteps',
      ]);
      expect(
        LiveEditSchemas.directApplyExecution['additionalProperties'],
        isFalse,
      );
      expect(properties.containsKey('executionId'), isFalse);
      expect(properties.containsKey('backendId'), isFalse);
      expect(properties.containsKey('meta'), isFalse);
    },
  );
}
