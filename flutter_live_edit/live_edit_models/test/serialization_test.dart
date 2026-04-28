import 'dart:convert';

import 'package:live_edit_models/live_edit_models.dart';
import 'package:test/test.dart';

/// Serialize to JSON string then parse back — ensures toJson/fromJson
/// actually round-trips through the wire format.
T roundTrip<T>(T value, T Function(Map<String, Object?>) fromJson) {
  final json = (value as dynamic).toJson() as Map<String, Object?>;
  final jsonString = jsonEncode(json);
  final parsed = jsonDecode(jsonString) as Map<String, Object?>;
  return fromJson(parsed);
}

void main() {
  group('round-trip JSON serialization', () {
    test('LiveEditBounds round-trips', () {
      const original = LiveEditBounds(
        left: 10,
        top: 20,
        right: 110,
        bottom: 120,
        width: 100,
        height: 100,
      );
      final json = original.toJson();
      final decoded = LiveEditBounds.fromJson(json);
      expect(decoded, original);
    });

    test('LiveEditAgentBackend round-trips', () {
      const original = LiveEditAgentBackend(
        id: 'backend-1',
        label: 'Backend One',
        description: 'A test backend',
        available: true,
        isDefault: false,
        meta: {'key': 'value'},
      );
      final json = original.toJson();
      final decoded = LiveEditAgentBackend.fromJson(json);
      expect(decoded, original);
    });

    test('LiveEditCodexModelOption round-trips', () {
      const original = LiveEditCodexModelOption(
        id: 'gpt-5.4',
        label: 'GPT-5.4',
      );
      final json = original.toJson();
      final decoded = LiveEditCodexModelOption.fromJson(json);
      expect(decoded, original);
    });

    test('LiveEditDraftChange round-trips', () {
      const original = LiveEditDraftChange(
        nodeId: 'node-1',
        propertyId: 'color',
        targetValue: '#FF0000',
        previewMode: LiveEditPreviewMode.exact,
        confidence: 0.9,
      );
      final json = original.toJson();
      final decoded = LiveEditDraftChange.fromJson(json);
      expect(decoded, original);
    });

    test('LiveEditFilePatch round-trips', () {
      const original = LiveEditFilePatch(
        path: 'lib/main.dart',
        content: 'void main() {}',
        patch: '@@ -1,1 +1,1 @@',
      );
      final json = original.toJson();
      final decoded = LiveEditFilePatch.fromJson(json);
      expect(decoded, original);
    });

    test('LiveEditRuntimeRefreshResult round-trips', () {
      const original = LiveEditRuntimeRefreshResult(
        action: LiveEditRuntimeAction.hotReload,
      );
      final json = original.toJson();
      final decoded = LiveEditRuntimeRefreshResult.fromJson(json);
      expect(decoded, original);
    });

    test('LiveEditResolutionProposal round-trips', () {
      const original = LiveEditResolutionProposal(
        proposalId: 'prop-1',
        backendId: 'backend-1',
        summary: 'Change button color',
        patch: '@@ -1 +1 @@',
        changedFiles: ['lib/main.dart'],
        filePatches: [
          LiveEditFilePatch(
            path: 'lib/main.dart',
            content: 'void main() {}',
            patch: '@@ -1,1 +1,1 @@',
          ),
        ],
        expectedRuntimeEffects: ['color change'],
        validationSteps: ['check colors'],
        warnings: [],
        riskFlags: [],
      );
      final decoded = roundTrip(original, LiveEditResolutionProposal.fromJson);
      expect(decoded.proposalId, original.proposalId);
      expect(decoded.backendId, original.backendId);
      expect(decoded.summary, original.summary);
      expect(decoded.patch, original.patch);
      expect(decoded.changedFiles, original.changedFiles);
      expect(decoded.filePatches.length, original.filePatches.length);
      expect(decoded.filePatches.first.path, original.filePatches.first.path);
    });

    test('LiveEditSourceTarget round-trips', () {
      const original = LiveEditSourceTarget(
        nodeId: 'node-1',
        widgetType: 'Container',
        absolutePath: '/path/to/file.dart',
        workspacePath: 'lib/file.dart',
        line: 42,
        column: 10,
      );
      final json = original.toJson();
      final decoded = LiveEditSourceTarget.fromJson(json);
      expect(decoded, original);
    });

    test('LiveEditDirectApplyResult round-trips', () {
      const original = LiveEditDirectApplyResult(
        executionId: 'exec-1',
        backendId: 'backend-1',
        summary: 'Applied changes',
        changedFiles: ['lib/main.dart'],
        warnings: [],
        validationSteps: ['dart analyze'],
      );
      final json = original.toJson();
      final decoded = LiveEditDirectApplyResult.fromJson(json);
      expect(decoded, original);
    });

    test('LiveEditResolutionResult round-trips', () {
      const original = LiveEditResolutionResult(
        proposalId: 'prop-1',
        status: LiveEditResolutionStatus.accepted,
        changedFiles: ['lib/main.dart'],
        warnings: [],
      );
      final json = original.toJson();
      final decoded = LiveEditResolutionResult.fromJson(json);
      expect(decoded, original);
    });

    test('LiveEditSelection round-trips', () {
      const original = LiveEditSelection(
        sessionId: 'session-1',
        nodeId: 'node-1',
        selectionKey: 'inspector:node-1',
        widgetType: 'Container',
        rawNode: {'nodeId': 'node-1'},
        propertiesForWire: [],
        source: null,
        bounds: LiveEditBounds(
          left: 0,
          top: 0,
          right: 100,
          bottom: 100,
          width: 100,
          height: 100,
        ),
      );
      final decoded = roundTrip(original, LiveEditSelection.fromJson);
      expect(decoded.nodeId, original.nodeId);
      expect(decoded.widgetType, original.widgetType);
      expect(decoded.sessionId, original.sessionId);
      expect(decoded.selectionKey, original.selectionKey);
    });

    test('RouteSnapshot round-trips', () {
      const original = RouteSnapshot(
        routeId: 'route-1',
        name: 'Home',
        screenId: 'screen-1',
        presentationKind: 'route',
        isActive: true,
      );
      final json = original.toJson();
      final decoded = RouteSnapshot.fromJson(json);
      expect(decoded.routeId, original.routeId);
      expect(decoded.name, original.name);
      expect(decoded.screenId, original.screenId);
      expect(decoded.presentationKind, original.presentationKind);
      expect(decoded.isActive, original.isActive);
    });

    test('InteractionSelectionSet round-trips', () {
      final original = InteractionSelectionSet(
        primaryKey: 'inspector:node-1',
        memberKeys: ['inspector:node-1', 'inspector:node-2'],
        origin: InteractionSelectionOrigin.tap,
        focusKind: InteractionFocusKind.node,
      );
      final json = original.toJson();
      final decoded = InteractionSelectionSet.fromJson(json);
      expect(decoded.primaryKey, original.primaryKey);
      expect(decoded.memberKeys, original.memberKeys);
      expect(decoded.origin, original.origin);
      expect(decoded.focusKind, original.focusKind);
    });

    test('AgentContextBudget round-trips', () {
      const original = AgentContextBudget(
        maxScreens: 5,
        maxNodesPerScreen: 20,
        maxSelectedNodes: 10,
        maxTransitions: 12,
        maxSourceTargets: 8,
        maxEvidenceItems: 6,
      );
      final json = original.toJson();
      final decoded = AgentContextBudget.fromJson(json);
      expect(decoded.maxScreens, original.maxScreens);
      expect(decoded.maxNodesPerScreen, original.maxNodesPerScreen);
      expect(decoded.maxSelectedNodes, original.maxSelectedNodes);
      expect(decoded.maxTransitions, original.maxTransitions);
      expect(decoded.maxSourceTargets, original.maxSourceTargets);
      expect(decoded.maxEvidenceItems, original.maxEvidenceItems);
    });
  });
}
