import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/flutter_mcp_core.dart';
import 'package:flutter_live_edit_toolkit/src/ai/agent/live_edit_agent_service.dart';
import 'package:flutter_live_edit_toolkit/src/models/live_edit_models.dart';
import 'package:test/test.dart';
import 'package:xsoulspace_inference_core/xsoulspace_inference_core.dart';

void main() {
  group('live edit executor commands', () {
    late DefaultCoreCommandExecutor executor;
    late LiveEditAgentService liveEditAgentService;

    setUp(() {
      void logger(
        final LoggingLevel level,
        final String message, {
        final String logger = 'test',
      }) {}

      final context = ConnectionContext(
        defaultHost: 'localhost',
        defaultPort: 8181,
        logger: logger,
        discoverPorts: () async => <int>[8181],
      );

      liveEditAgentService = LiveEditAgentService(
        registry: LiveEditAgentRegistry(
          clients: <String, InferenceClient>{
            'codex_exec': const _FakeInferenceClient(id: 'codex_exec'),
            'cursor_agent': const _FakeInferenceClient(id: 'cursor_agent'),
          },
          defaultBackendId: 'codex_exec',
        ),
      );

      executor = DefaultCoreCommandExecutor(
        connectionContext: context,
        portScanner: CorePortScanner(logger: logger),
        imageFileSaver: CoreImageFileSaver(logger: logger),
        configuration: const CoreRuntimeConfiguration(
          vmHost: 'localhost',
          vmPort: 8181,
          resourcesSupported: true,
          imagesSupported: true,
          dumpsSupported: false,
          dynamicRegistrySupported: false,
          saveImagesToFiles: false,
        ),
        liveEditAgentService: liveEditAgentService,
      );
    });

    test('lists and resolves session backend selection', () async {
      final listResult = await executor.execute(
        const LiveEditListAgentBackendsCommand(),
      );

      expect(listResult.ok, isTrue);
      final listData = listResult.data! as Map<String, Object?>;
      final backends = listData['backends']! as List<Object?>;
      expect(backends, hasLength(2));
      expect(
        backends.map(
          (final backend) => (backend! as Map<String, Object?>)['id'],
        ),
        containsAll(<String>['codex_exec', 'cursor_agent']),
      );

      final setResult = await executor.execute(
        const LiveEditSetAgentBackendCommand(
          sessionId: 'session-1',
          backendId: 'cursor_agent',
        ),
      );
      expect(setResult.ok, isTrue);

      final getResult = await executor.execute(
        const LiveEditGetAgentBackendCommand(sessionId: 'session-1'),
      );
      expect(getResult.ok, isTrue);
      final getData = getResult.data! as Map<String, Object?>;
      final backend = getData['backend']! as Map<String, Object?>;
      expect(backend['id'], 'cursor_agent');
      expect(getData['sessionId'], 'session-1');
    });

    test('rejecting an unknown proposal returns not found', () async {
      final result = await executor.execute(
        const LiveEditRejectResolutionCommand(proposalId: 'missing'),
      );

      expect(result.ok, isFalse);
      expect(
        result.error?.code,
        equals(CoreErrorCode.liveEditProposalNotFound),
      );
    });

    test(
      'apply draft reports hot reload failure without VM connection',
      () async {
        final tmp = Directory.systemTemp.createTempSync('mcp_le_test');
        addTearDown(() {
          if (tmp.existsSync()) {
            tmp.deleteSync(recursive: true);
          }
        });
        final dartFile = File('${tmp.path}/main.dart')
          ..writeAsStringSync('void main() {}\n');

        final proposal = await liveEditAgentService.resolve(
          LiveEditResolutionRequest(
            sessionId: 'session-1',
            workingDirectory: tmp.path,
            instructionText: 'Set width to 140',
            primarySelection: LiveEditSelection(
              sessionId: 'session-1',
              nodeId: 'node-1',
              widgetType: 'Container',
              source: LiveEditSourceLocation(file: dartFile.path, line: 42),
              rawNode: <String, Object?>{},
            ),
          ),
        );

        final result = await executor.execute(
          LiveEditApplyDraftCommand(
            proposalId: proposal.proposalId,
            workingDirectory: tmp.path,
          ),
        );

        expect(result.ok, isFalse);
        expect(result.error?.code, CoreErrorCode.liveEditValidationFailed);
        expect(
          result.error?.message,
          contains('runtime validation did not match the draft'),
        );
      },
    );
  });
}

final class _FakeInferenceClient implements InferenceClient {
  const _FakeInferenceClient({required this.id});

  @override
  final String id;

  @override
  bool get isAvailable => true;

  @override
  Set<InferenceTask> get supportedTasks => {InferenceTask.structuredText};

  @override
  Future<bool> refreshAvailability() async => true;

  @override
  void resetAvailabilityCache() {}

  @override
  Future<InferenceResult<InferenceResponse>> infer(
    final InferenceRequest request,
  ) async => InferenceResult<InferenceResponse>.ok(
    const InferenceResponse(
      output: <String, dynamic>{
        'proposalId': 'proposal-1',
        'backendId': 'fake',
        'summary': 'No-op',
        'patch': '',
        'changedFiles': <String>[],
        'filePatches': <Map<String, dynamic>>[],
        'expectedRuntimeEffects': <String>[],
        'validationSteps': <String>[],
        'warnings': <String>[],
        'riskFlags': <String>[],
      },
    ),
  );
}
