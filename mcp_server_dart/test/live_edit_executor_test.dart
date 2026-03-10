import 'package:dart_mcp/server.dart';
import 'package:flutter_live_edit_agent/flutter_live_edit_agent.dart';
import 'package:flutter_inspector_mcp_server/flutter_mcp_core.dart';
import 'package:test/test.dart';
import 'package:xsoulspace_inference_core/xsoulspace_inference_core.dart';

void main() {
  group('live edit executor commands', () {
    late DefaultCoreCommandExecutor executor;

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
        liveEditAgentService: LiveEditAgentService(
          registry: LiveEditAgentRegistry(
            clients: <String, InferenceClient>{'fake': _FakeInferenceClient()},
            defaultBackendId: 'fake',
          ),
        ),
      );
    });

    test('lists and resolves session backend selection', () async {
      final listResult = await executor.execute(
        const LiveEditListAgentBackendsCommand(),
      );

      expect(listResult.ok, isTrue);
      final listData = listResult.data! as Map<String, Object?>;
      final backends = listData['backends']! as List<Object?>;
      expect(backends, hasLength(1));
      expect((backends.single as Map<String, Object?>)['id'], 'fake');

      final setResult = await executor.execute(
        const LiveEditSetAgentBackendCommand(
          sessionId: 'session-1',
          backendId: 'fake',
        ),
      );
      expect(setResult.ok, isTrue);

      final getResult = await executor.execute(
        const LiveEditGetAgentBackendCommand(sessionId: 'session-1'),
      );
      expect(getResult.ok, isTrue);
      final getData = getResult.data! as Map<String, Object?>;
      final backend = getData['backend']! as Map<String, Object?>;
      expect(backend['id'], 'fake');
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
}
