import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_live_edit_agent/flutter_live_edit_agent.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';
import 'package:flutter_live_edit_toolkit/flutter_live_edit_toolkit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:test_app/main.dart' as app;

const _runCodexIntegration = bool.fromEnvironment(
  'RUN_LIVE_EDIT_CODEX_INTEGRATION',
);
const _allowCodexApply = bool.fromEnvironment(
  'LIVE_EDIT_CODEX_APPROVE_INTEGRATION',
);
const _codexBackendId = String.fromEnvironment(
  'LIVE_EDIT_CODEX_BACKEND',
  defaultValue: 'codex_exec',
);
const _codexIntent = String.fromEnvironment(
  'LIVE_EDIT_CODEX_INTENT',
  defaultValue:
      'Persist the inline live-edit text change for the dedicated test fixture with minimal source edits.',
);
const _codexWorkingDirectoryDefine = String.fromEnvironment(
  'LIVE_EDIT_CODEX_WORKING_DIRECTORY',
);

Finder _semanticsId(final String id) => find.byWidgetPredicate(
  (final widget) => widget is Semantics && widget.properties.identifier == id,
  description: 'Semantics identifier $id',
);

String _panelPropertyId(final String raw) => raw
    .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '')
    .toLowerCase();

LiveEditApplyDraftDelegate _buildCodexDelegate() {
  final service = LiveEditAgentService();
  final workingDirectory = _codexWorkingDirectoryDefine.isNotEmpty
      ? _codexWorkingDirectoryDefine
      : Directory.current.path;

  return (final request) async {
    if (!request.approve) {
      final proposal = await service.resolve(
        LiveEditResolutionRequest(
          sessionId: request.sessionId,
          backendId: request.backendId ?? _codexBackendId,
          workingDirectory: request.workingDirectory ?? workingDirectory,
          intentText: request.intentText,
          draftChanges: request.draftChanges,
          selection: request.selection,
          meta: const <String, Object?>{
            'integrationTest': true,
            'driver': 'flutter_integration_test',
          },
        ),
      );
      final executionPlan = service.buildExecutionPlan(proposal.proposalId);
      return <String, Object?>{
        'proposalId': proposal.proposalId,
        'executionPlan': executionPlan.toJson(),
        'proposal': proposal.toJson(),
      };
    }

    if (!_allowCodexApply) {
      return <String, Object?>{
        'ok': false,
        'message':
            'Codex integration apply is disabled. Set LIVE_EDIT_CODEX_APPROVE_INTEGRATION=true to allow file writes.',
      };
    }

    final proposalId = request.proposalId?.trim();
    if (proposalId == null || proposalId.isEmpty) {
      return <String, Object?>{
        'ok': false,
        'message': 'Missing proposalId for Codex integration apply.',
      };
    }

    final result = await service.applyProposal(
      proposalId,
      workingDirectory: request.workingDirectory ?? workingDirectory,
    );
    return <String, Object?>{
      'proposalId': result.proposalId,
      'result': result.toJson(),
    };
  };
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    app.debugLiveEditOrchestratorOverride = null;
  });

  tearDown(() {
    app.debugLiveEditOrchestratorOverride?.dispose();
    app.debugLiveEditOrchestratorOverride = null;
  });

  testWidgets(
    'inline editing resolves through the real Codex backend',
    skip: !_runCodexIntegration,
    (final tester) async {
      await binding.setSurfaceSize(const Size(8000, 2000));
      addTearDown(() => binding.setSurfaceSize(null));

      final orchestrator = LiveEditOrchestrator(
        applyDraftDelegate: _buildCodexDelegate(),
        backendId: _codexBackendId,
        workingDirectory: _codexWorkingDirectoryDefine.isNotEmpty
            ? _codexWorkingDirectoryDefine
            : Directory.current.path,
        intentText: _codexIntent,
      );
      app.debugLiveEditOrchestratorOverride = orchestrator;

      await app.main();
      await tester.pumpAndSettle(const Duration(seconds: 30));

      expect(find.text('MCP Toolkit Demo'), findsOneWidget);
      expect(find.text('Live Edit Test Target'), findsOneWidget);

      await tester.tap(find.widgetWithText(ActionChip, 'Live Edit'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.text('Live Edit: ON'), findsOneWidget);
      expect(find.text('Tap a widget to select'), findsOneWidget);

      await tester.tap(find.text('Live Edit Test Target'), warnIfMissed: false);
      await tester.pumpAndSettle();
      if (orchestrator.activeSelection == null) {
        orchestrator.selectNode(
          tester.getCenter(find.text('Live Edit Test Target')),
        );
        await tester.pumpAndSettle();
      }

      expect(_semanticsId('live_edit_selection_bubble'), findsOneWidget);
      expect(orchestrator.activeSelection, isNotNull);

      for (
        var index = 0;
        index < orchestrator.activeSelectionCandidates.length;
        index += 1
      ) {
        final selection = orchestrator.activeSelection;
        final hasEditableTextProperty =
            selection?.propertyGroups.any(
              (final property) =>
                  property.editable &&
                  property.kind == LiveEditPropertyKind.string,
            ) ??
            false;
        if (hasEditableTextProperty) {
          break;
        }
        orchestrator.selectCandidateAt(index);
        await tester.pumpAndSettle();
      }

      final textProperty = orchestrator.activeSelection!.propertyGroups
          .firstWhere(
            (final property) =>
                property.editable &&
                property.kind == LiveEditPropertyKind.string,
          );
      final propertyId = _panelPropertyId(textProperty.id);
      final propertyCard = _semanticsId('live_edit_property_$propertyId');
      expect(propertyCard, findsOneWidget);
      await tester.tap(propertyCard);
      await tester.pumpAndSettle();

      final propertyInput = find.descendant(
        of: _semanticsId('live_edit_property_input_$propertyId'),
        matching: find.byType(TextField),
      );
      expect(propertyInput, findsOneWidget);
      await tester.enterText(
        propertyInput,
        'Live Edit Test Target updated through Codex integration',
      );
      await tester.pumpAndSettle();

      expect(find.text('Draft changes: 1'), findsWidgets);
      expect(orchestrator.activeDraftChanges, isNotEmpty);

      await tester.tap(_semanticsId('live_edit_apply_button'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle(const Duration(minutes: 2));

      expect(orchestrator.applyPhase, LiveEditApplyPhase.awaitingApproval);
      expect(_semanticsId('live_edit_ai_bubble'), findsOneWidget);
      expect(find.text('Approve & Apply'), findsWidgets);
      expect(orchestrator.pendingExecutionPlan, isNotNull);
      expect(
        orchestrator.pendingExecutionPlan!.requestedChanges
            .join(' ')
            .toLowerCase(),
        contains(textProperty.id.toLowerCase()),
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(orchestrator.historyForActiveSelection, isNotEmpty);
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
