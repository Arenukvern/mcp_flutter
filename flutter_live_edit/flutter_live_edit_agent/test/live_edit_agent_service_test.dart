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
  });
}

final class _FakeInferenceClient implements InferenceClient {
  @override
  String get id => 'fake';

  @override
  bool get isAvailable => true;

  @override
  Future<InferenceResult<InferenceResponse>> infer(
    final InferenceRequest request,
  ) async {
    return InferenceResult<InferenceResponse>.ok(
      InferenceResponse(
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
}
