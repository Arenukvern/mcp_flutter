import 'dart:io';

import 'package:flutter_live_edit_agent/flutter_live_edit_agent.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';
import 'package:test/test.dart';
import 'package:xsoulspace_inference_core/xsoulspace_inference_core.dart';

void main() {
  group('LiveEditAgentService', () {
    test('lists registered backends', () {
      final service = LiveEditAgentService(
        registry: LiveEditAgentRegistry(
          clients: <String, InferenceClient>{'fake': _FakeInferenceClient()},
          defaultBackendId: 'fake',
        ),
      );

      final backends = service.listBackends();
      expect(backends.single.id, 'fake');
      expect(backends.single.available, isTrue);
    });

    test('resolves structured proposal and applies files', () async {
      final tempDir = await Directory.systemTemp.createTemp('live_edit_agent');
      addTearDown(() => tempDir.delete(recursive: true));

      final service = LiveEditAgentService(
        registry: LiveEditAgentRegistry(
          clients: <String, InferenceClient>{'fake': _FakeInferenceClient()},
          defaultBackendId: 'fake',
        ),
      );

      final proposal = await service.resolve(
        LiveEditResolutionRequest(
          sessionId: 'session-1',
          workingDirectory: tempDir.path,
          draftChanges: const <LiveEditDraftChange>[
            LiveEditDraftChange(
              nodeId: 'node-1',
              propertyId: 'width',
              targetValue: 140,
              previewMode: LiveEditPreviewMode.ghost,
            ),
          ],
        ),
      );

      final result = await service.applyProposal(
        proposal.proposalId,
        workingDirectory: tempDir.path,
      );
      final writtenFile = File('${tempDir.path}/lib/main.dart');

      expect(result.status, LiveEditResolutionStatus.applied);
      expect(writtenFile.existsSync(), isTrue);
      expect(writtenFile.readAsStringSync(), contains('width: 140'));
    });

    test('persists proposal state across service instances', () async {
      final tempDir = await Directory.systemTemp.createTemp('live_edit_agent');
      addTearDown(() => tempDir.delete(recursive: true));
      final storagePath = '${tempDir.path}/proposal-cache';

      final resolver = LiveEditAgentService(
        registry: LiveEditAgentRegistry(
          clients: <String, InferenceClient>{'fake': _FakeInferenceClient()},
          defaultBackendId: 'fake',
        ),
        storagePath: storagePath,
      );

      final proposal = await resolver.resolve(
        LiveEditResolutionRequest(
          sessionId: 'session-persisted',
          workingDirectory: tempDir.path,
          draftChanges: const <LiveEditDraftChange>[
            LiveEditDraftChange(
              nodeId: 'node-1',
              propertyId: 'width',
              targetValue: 140,
              previewMode: LiveEditPreviewMode.ghost,
            ),
          ],
        ),
      );

      final applier = LiveEditAgentService(
        registry: LiveEditAgentRegistry(
          clients: <String, InferenceClient>{'fake': _FakeInferenceClient()},
          defaultBackendId: 'fake',
        ),
        storagePath: storagePath,
      );

      final persistedProposal = applier.getProposal(proposal.proposalId);
      final persistedRequest = applier.requestForProposal(proposal.proposalId);
      final result = await applier.applyProposal(
        proposal.proposalId,
        workingDirectory: tempDir.path,
      );

      expect(persistedProposal.summary, proposal.summary);
      expect(persistedRequest?.sessionId, 'session-persisted');
      expect(result.status, LiveEditResolutionStatus.applied);
      expect(
        applier.proposalStatus(proposal.proposalId),
        LiveEditResolutionStatus.applied,
      );
    });

    test('builds condensed execution plan from proposal state', () async {
      final tempDir = await Directory.systemTemp.createTemp('live_edit_agent');
      addTearDown(() => tempDir.delete(recursive: true));

      final service = LiveEditAgentService(
        registry: LiveEditAgentRegistry(
          clients: <String, InferenceClient>{'fake': _FakeInferenceClient()},
          defaultBackendId: 'fake',
        ),
      );

      final proposal = await service.resolve(
        LiveEditResolutionRequest(
          sessionId: 'session-plan',
          workingDirectory: tempDir.path,
          draftChanges: const <LiveEditDraftChange>[
            LiveEditDraftChange(
              nodeId: 'node-1',
              propertyId: 'width',
              targetValue: 140,
              confidence: 0.75,
            ),
          ],
          selection: const LiveEditSelection(
            sessionId: 'session-plan',
            nodeId: 'node-1',
            widgetType: 'Container',
            source: LiveEditSourceLocation(
              file: '/tmp/lib/main.dart',
              line: 42,
            ),
            propertyGroups: <LiveEditPropertyDescriptor>[
              LiveEditPropertyDescriptor(
                id: 'width',
                label: 'Width',
                group: LiveEditPropertyGroup.layout,
                kind: LiveEditPropertyKind.number,
              ),
            ],
            rawNode: <String, Object?>{},
          ),
        ),
      );

      final plan = service.buildExecutionPlan(proposal.proposalId);

      expect(plan.proposalId, proposal.proposalId);
      expect(plan.selectedNode, contains('Container'));
      expect(plan.requestedChanges.single, contains('Width'));
      expect(plan.agentInstruction, contains('width=140'));
    });

    test(
      'compacts large runtime payloads before prompting the backend',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'live_edit_agent',
        );
        addTearDown(() => tempDir.delete(recursive: true));

        final client = _CapturingInferenceClient();
        final service = LiveEditAgentService(
          registry: LiveEditAgentRegistry(
            clients: <String, InferenceClient>{'fake': client},
            defaultBackendId: 'fake',
          ),
        );

        final verboseNode = _buildVerboseNode();
        await service.resolve(
          LiveEditResolutionRequest(
            sessionId: 'session-compact',
            workingDirectory: tempDir.path,
            draftChanges: const <LiveEditDraftChange>[
              LiveEditDraftChange(
                nodeId: 'node-1',
                propertyId: 'crossAxisAlignment',
                targetValue: 'start',
                previewMode: LiveEditPreviewMode.exact,
              ),
            ],
            selection: LiveEditSelection(
              sessionId: 'session-compact',
              nodeId: 'node-1',
              widgetType: 'Column',
              renderObjectType: 'RenderFlex',
              source: LiveEditSourceLocation(
                file: 'file://${tempDir.path}/lib/main.dart',
                line: 42,
                column: 7,
              ),
              propertyGroups: const <LiveEditPropertyDescriptor>[
                LiveEditPropertyDescriptor(
                  id: 'crossAxisAlignment',
                  label: 'Cross Axis',
                  group: LiveEditPropertyGroup.layout,
                  kind: LiveEditPropertyKind.enumValue,
                  value: 'center',
                  options: <String>['start', 'center', 'end'],
                  editable: true,
                  previewMode: LiveEditPreviewMode.exact,
                  persistable: true,
                ),
              ],
              layoutContext: const <String, Object?>{
                'constraints': 'BoxConstraints(w=320.0, 0.0<=h<=Infinity)',
              },
              parentChain: <Map<String, Object?>>[
                <String, Object?>{'node': verboseNode},
              ],
              detailsTree: verboseNode,
              propertiesTree: verboseNode,
              rawNode: verboseNode,
            ),
            evidence: <String, Object?>{
              'tree': verboseNode,
              'uiSnapshot': <String, Object?>{
                'screenshots': <Object?>[
                  <String, Object?>{'pngBase64': 'x' * 20000},
                ],
              },
            },
          ),
        );

        final request = client.lastRequest;
        expect(request, isNotNull);
        expect(request!.prompt.length, lessThan(15000));
        expect(
          request.metadata['promptBytes'],
          equals(request.prompt.codeUnits.length),
        );
        expect(request.prompt, contains('"workspacePath": "lib/main.dart"'));
        expect(request.prompt, contains('"childrenTruncated"'));
        expect(request.prompt, contains('<omitted large payload>'));
      },
    );

    test('surfaces backend failure details', () async {
      final tempDir = await Directory.systemTemp.createTemp('live_edit_agent');
      addTearDown(() => tempDir.delete(recursive: true));

      final service = LiveEditAgentService(
        registry: LiveEditAgentRegistry(
          clients: <String, InferenceClient>{'fake': _FailingInferenceClient()},
          defaultBackendId: 'fake',
        ),
      );

      await expectLater(
        () => service.resolve(
          LiveEditResolutionRequest(
            sessionId: 'session-fail',
            workingDirectory: tempDir.path,
            draftChanges: const <LiveEditDraftChange>[
              LiveEditDraftChange(
                nodeId: 'node-1',
                propertyId: 'width',
                targetValue: 140,
              ),
            ],
          ),
        ),
        throwsA(
          isA<LiveEditAgentException>()
              .having((final error) => error.code, 'code', 'codex_exec_failed')
              .having(
                (final error) => error.details,
                'details',
                containsPair('stderr', contains('token limit')),
              ),
        ),
      );
    });
  });
}

Map<String, Object?> _buildVerboseNode() {
  const payload = 'VERBOSE_PAYLOAD_';
  return <String, Object?>{
    'description': 'Column',
    'widgetRuntimeType': 'Column',
    'creationLocation': <String, Object?>{
      'file': 'file:///workspace/lib/main.dart',
      'line': 42,
      'column': 7,
    },
    'properties': List<Map<String, Object?>>.generate(
      12,
      (final index) => <String, Object?>{
        'name': 'property$index',
        'description': payload * 80,
      },
      growable: false,
    ),
    'children': List<Map<String, Object?>>.generate(
      10,
      (final index) => <String, Object?>{
        'description': 'Child$index',
        'widgetRuntimeType': 'Container',
        'properties': <Map<String, Object?>>[
          <String, Object?>{'name': 'color', 'description': payload * 80},
        ],
      },
      growable: false,
    ),
  };
}

final class _CapturingInferenceClient extends _FakeInferenceClient {
  InferenceRequest? lastRequest;

  @override
  Future<InferenceResult<InferenceResponse>> infer(
    final InferenceRequest request,
  ) async {
    lastRequest = request;
    return super.infer(request);
  }
}

final class _FailingInferenceClient implements InferenceClient {
  @override
  String get id => 'fake';

  @override
  bool get isAvailable => true;

  @override
  Future<InferenceResult<InferenceResponse>> infer(
    final InferenceRequest request,
  ) async => InferenceResult<InferenceResponse>.fail(
    code: 'codex_exec_failed',
    message: 'codex exec failed with exit code 1',
    details: <String, Object?>{
      'exit_code': 1,
      'stderr': 'Request exceeded token limit',
    },
    meta: <String, Object?>{'attempt_count': 1},
  );
}

class _FakeInferenceClient implements InferenceClient {
  @override
  String get id => 'fake';

  @override
  bool get isAvailable => true;

  @override
  Future<InferenceResult<InferenceResponse>> infer(
    final InferenceRequest request,
  ) async => InferenceResult<InferenceResponse>.ok(
    const InferenceResponse(
      output: <String, dynamic>{
        'proposalId': 'proposal-1',
        'backendId': 'fake',
        'summary': 'Update width to 140.',
        'patch': '--- a/lib/main.dart\n+++ b/lib/main.dart',
        'changedFiles': <String>['lib/main.dart'],
        'filePatches': <Map<String, dynamic>>[
          <String, dynamic>{
            'path': 'lib/main.dart',
            'content': 'Container(width: 140)',
            'patch': '@@ -1 +1 @@',
          },
        ],
        'expectedRuntimeEffects': <String>[
          'The selected widget becomes wider.',
        ],
        'validationSteps': <String>['Hot reload and verify width.'],
        'warnings': <String>[],
        'riskFlags': <String>[],
        'meta': <String, dynamic>{'provider': 'fake'},
      },
    ),
  );
}
