import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';
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
          canPreviewExactly: false,
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
}
