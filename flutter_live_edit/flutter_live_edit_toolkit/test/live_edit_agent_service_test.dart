import 'dart:io';

import 'package:flutter_live_edit_toolkit/src/ai/agent/live_edit_agent_service.dart';
import 'package:flutter_live_edit_toolkit/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xsoulspace_inference_codex_exec/xsoulspace_inference_codex_exec.dart';
import 'package:xsoulspace_inference_core/xsoulspace_inference_core.dart';
import 'package:xsoulspace_inference_cursor_agent/xsoulspace_inference_cursor_agent.dart';

void main() {
  group('LiveEditAgentService', () {
    test('default registry exposes codex and cursor backends', () {
      final registry = LiveEditAgentRegistry.withDefaults();

      final backends = registry.listBackends();
      final ids = backends.map((final backend) => backend.id).toSet();

      expect(ids, containsAll(<String>{'codex_exec', 'cursor_agent'}));
      expect(
        backends.firstWhere((final backend) => backend.id == 'codex_exec').meta,
        containsPair('displayLabel', 'Codex'),
      );
      expect(
        backends
            .firstWhere((final backend) => backend.id == 'cursor_agent')
            .meta,
        containsPair('displayLabel', 'Cursor'),
      );
      expect(
        backends
            .firstWhere((final backend) => backend.id == 'codex_exec')
            .meta['defaultInferenceConfig'],
        <String, Object?>{
          'model': 'gpt-5.3-codex',
          'reasoningEffort': 'medium',
        },
      );
    });

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

    test('resolve uses the selected backend client', () async {
      final tempDir = await Directory.systemTemp.createTemp('live_edit_agent');
      addTearDown(() => tempDir.delete(recursive: true));
      final codexClient = _CapturingInferenceClient();
      final cursorClient = _CapturingInferenceClient();
      final service = LiveEditAgentService(
        registry: LiveEditAgentRegistry(
          clients: <String, InferenceClient>{
            'codex_exec': codexClient,
            'cursor_agent': cursorClient,
          },
          defaultBackendId: 'codex_exec',
        ),
      );

      final proposal = await service.resolve(
        LiveEditResolutionRequest(
          sessionId: 'session-cursor',
          backendId: 'cursor_agent',
          workingDirectory: tempDir.path,
          instructionText: 'Set width to 200',
        ),
      );

      expect(proposal.backendId, 'cursor_agent');
      expect(codexClient.lastRequest, isNull);
      expect(cursorClient.lastRequest, isNotNull);
    });

    test(
      'cursor_agent receives inferenceModel in metadata when config has model',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'live_edit_agent',
        );
        addTearDown(() => tempDir.delete(recursive: true));
        final cursorClient = _CapturingInferenceClient();
        final service = LiveEditAgentService(
          registry: LiveEditAgentRegistry(
            clients: <String, InferenceClient>{'cursor_agent': cursorClient},
            defaultBackendId: 'cursor_agent',
          ),
        );

        await service.resolve(
          LiveEditResolutionRequest(
            sessionId: 'session-cursor',
            backendId: 'cursor_agent',
            workingDirectory: tempDir.path,
            instructionText: 'Set width to 200',
            inferenceConfig: const LiveEditInferenceConfig(
              model: 'claude-3-5-sonnet',
            ),
          ),
        );

        expect(cursorClient.lastRequest, isNotNull);
        expect(
          cursorClient.lastRequest!.metadata['inferenceModel'],
          'claude-3-5-sonnet',
        );
      },
    );

    test('lists unavailable backends without selecting them by default', () {
      final service = LiveEditAgentService(
        registry: LiveEditAgentRegistry(
          clients: <String, InferenceClient>{
            'codex_exec': _CapturingInferenceClient(),
            'cursor_agent': _UnavailableInferenceClient(),
          },
          defaultBackendId: 'codex_exec',
        ),
      );

      final backends = service.listBackends();
      expect(
        backends
            .firstWhere((final backend) => backend.id == 'cursor_agent')
            .available,
        isFalse,
      );
      expect(service.getBackend().id, 'codex_exec');
    });

    test(
      'stores session inference config and reuses it for later resolves',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'live_edit_agent',
        );
        addTearDown(() => tempDir.delete(recursive: true));
        final codexClient = _CapturingInferenceClient();
        final service = LiveEditAgentService(
          registry: LiveEditAgentRegistry(
            clients: <String, InferenceClient>{'codex_exec': codexClient},
            defaultBackendId: 'codex_exec',
          ),
        );

        service.setSessionBackend(
          sessionId: 'session-codex',
          backendId: 'codex_exec',
          inferenceConfig: const LiveEditInferenceConfig(
            model: 'GPT-5.4',
            reasoningEffort: 'middle',
          ),
        );

        await service.resolve(
          LiveEditResolutionRequest(
            sessionId: 'session-codex',
            workingDirectory: tempDir.path,
            instructionText: 'Set width to 200',
          ),
        );

        expect(codexClient.lastRequest, isNotNull);
        expect(codexClient.lastRequest!.metadata['inferenceModel'], 'gpt-5.4');
        expect(
          codexClient.lastRequest!.metadata['inferenceReasoningEffort'],
          'medium',
        );
        expect(codexClient.lastRequest!.metadata['codexExecModel'], 'gpt-5.4');
        expect(
          codexClient.lastRequest!.metadata['codexExecReasoningEffort'],
          'medium',
        );
      },
    );

    test('per-request inference config overrides session default', () async {
      final tempDir = await Directory.systemTemp.createTemp('live_edit_agent');
      addTearDown(() => tempDir.delete(recursive: true));
      final codexClient = _CapturingInferenceClient();
      final service = LiveEditAgentService(
        registry: LiveEditAgentRegistry(
          clients: <String, InferenceClient>{'codex_exec': codexClient},
          defaultBackendId: 'codex_exec',
        ),
      );

      service.setSessionBackend(
        sessionId: 'session-codex',
        backendId: 'codex_exec',
        inferenceConfig: const LiveEditInferenceConfig(
          model: 'gpt-5.3-codex',
          reasoningEffort: 'low',
        ),
      );

      await service.resolve(
        LiveEditResolutionRequest(
          sessionId: 'session-codex',
          workingDirectory: tempDir.path,
          instructionText: 'Set width to 200',
          inferenceConfig: const LiveEditInferenceConfig(
            model: 'gpt-5.4',
            reasoningEffort: 'high',
          ),
        ),
      );

      expect(codexClient.lastRequest, isNotNull);
      expect(codexClient.lastRequest!.metadata['inferenceModel'], 'gpt-5.4');
      expect(
        codexClient.lastRequest!.metadata['inferenceReasoningEffort'],
        'high',
      );
      expect(codexClient.lastRequest!.metadata['codexExecModel'], 'gpt-5.4');
      expect(
        codexClient.lastRequest!.metadata['codexExecReasoningEffort'],
        'high',
      );
    });

    test('accepts inference config for cursor backend', () {
      final service = LiveEditAgentService(
        registry: LiveEditAgentRegistry(
          clients: <String, InferenceClient>{
            'cursor_agent': _FakeInferenceClient(),
          },
          defaultBackendId: 'cursor_agent',
        ),
      );

      service.setSessionBackend(
        sessionId: 'session-cursor',
        backendId: 'cursor_agent',
        inferenceConfig: const LiveEditInferenceConfig(model: 'gpt-5.4'),
      );
      final backend = service.getBackend(
        sessionId: 'session-cursor',
        backendId: 'cursor_agent',
      );
      expect(backend.meta['effectiveInferenceConfig'], isA<Map>());
      expect(
        (backend.meta['effectiveInferenceConfig']! as Map)['model'],
        'gpt-5.4',
      );
    });

    test(
      'cursor backend with defaultModel exposes effectiveInferenceConfig',
      () {
        final registry = LiveEditAgentRegistry(
          clients: <String, InferenceClient>{
            'cursor_agent': CursorAgentInferenceClient(
              binaryName: '/tmp/cursor-agent',
              defaultModel: 'auto',
            ),
          },
          defaultBackendId: 'cursor_agent',
        );
        registry.setSessionBackend(
          sessionId: 'session-cursor',
          backendId: 'cursor_agent',
        );

        final backend = registry.getBackend(sessionId: 'session-cursor');
        expect(backend.meta['defaultInferenceConfig'], isA<Map>());
        expect(
          (backend.meta['defaultInferenceConfig']! as Map)['model'],
          'auto',
        );
        expect(backend.meta['effectiveInferenceConfig'], isA<Map>());
        expect(
          (backend.meta['effectiveInferenceConfig']! as Map)['model'],
          'auto',
        );
      },
    );

    test('default registry exposes auto model for cursor backend', () {
      final registry = LiveEditAgentRegistry.withDefaults();
      registry.setSessionBackend(
        sessionId: 'session-cursor-default',
        backendId: 'cursor_agent',
      );

      final backend = registry.getBackend(sessionId: 'session-cursor-default');
      expect((backend.meta['defaultInferenceConfig']! as Map)['model'], 'auto');
      expect(
        (backend.meta['effectiveInferenceConfig']! as Map)['model'],
        'auto',
      );
    });

    test('codex backend metadata exposes supported and effective config', () {
      final registry = LiveEditAgentRegistry(
        clients: <String, InferenceClient>{
          'codex_exec': CodexExecInferenceClient(
            binaryName: '/tmp/codex',
            defaultModel: 'gpt-5.4',
            defaultReasoningEffort: 'low',
          ),
        },
        defaultBackendId: 'codex_exec',
      );
      registry.setSessionBackend(
        sessionId: 'session-codex',
        backendId: 'codex_exec',
        inferenceConfig: const LiveEditInferenceConfig(
          model: 'gpt-5.3-codex-spark',
          reasoningEffort: 'medium',
        ),
      );

      final backend = registry.getBackend(sessionId: 'session-codex');
      final meta = backend.meta;

      expect(meta['supportedModels'], isA<List<Object?>>());
      expect(meta['supportedReasoningEfforts'], contains('medium'));
      expect(meta['defaultInferenceConfig'], isA<Map<String, Object?>>());
      expect(meta['effectiveInferenceConfig'], <String, Object?>{
        'model': 'gpt-5.3-codex-spark',
        'reasoningEffort': 'medium',
      });
    });

    test('executes direct apply and returns changed files', () async {
      final tempDir = await Directory.systemTemp.createTemp('live_edit_agent');
      addTearDown(() => tempDir.delete(recursive: true));

      final service = LiveEditAgentService(
        registry: LiveEditAgentRegistry(
          clients: <String, InferenceClient>{'fake': _FakeInferenceClient()},
          defaultBackendId: 'fake',
        ),
      );

      final result = await service.executeDirectApply(
        LiveEditResolutionRequest(
          sessionId: 'session-1',
          workingDirectory: tempDir.path,
          instructionText: 'Set width to 140',
        ),
      );
      expect(result.executionId, 'proposal-1');
      expect(result.backendId, 'fake');
      expect(result.changedFiles, contains('lib/main.dart'));
    });

    test('normalizes partial backend output for direct apply', () async {
      final tempDir = await Directory.systemTemp.createTemp('live_edit_agent');
      addTearDown(() => tempDir.delete(recursive: true));

      final service = LiveEditAgentService(
        registry: LiveEditAgentRegistry(
          clients: <String, InferenceClient>{
            'cursor_agent': _PartialInferenceClient(),
          },
          defaultBackendId: 'cursor_agent',
        ),
      );

      final result = await service.executeDirectApply(
        LiveEditResolutionRequest(
          sessionId: 'session-1',
          backendId: 'cursor_agent',
          workingDirectory: tempDir.path,
          instructionText: 'Set width to 140',
        ),
      );

      expect(result.executionId, isNotEmpty);
      expect(result.backendId, 'cursor_agent');
      expect(result.summary, 'Adjust width safely.');
      expect(result.warnings, isEmpty);
      expect(result.validationSteps, isEmpty);
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
          instructionText: 'Set width to 140',
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
      final sourceDir = Directory('${tempDir.path}/lib')..createSync();
      final sourceFile = File('${sourceDir.path}/main.dart')
        ..writeAsStringSync('Widget build() => const SizedBox(width: 120);');

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
          instructionText: 'Set width to 140',
          primarySelection: LiveEditSelection(
            sessionId: 'session-plan',
            nodeId: 'node-1',
            widgetType: 'Container',
            source: LiveEditSourceLocation(file: sourceFile.path, line: 42),
            rawNode: <String, Object?>{},
          ),
        ),
      );

      final plan = service.buildExecutionPlan(proposal.proposalId);

      expect(plan.proposalId, proposal.proposalId);
      expect(plan.selectedNode, contains('Container'));
      expect(plan.requestedChanges.single, contains('Set width to 140'));
      expect(plan.agentInstruction, contains('Set width to 140'));
    });

    test('builds execution plan for prompt-only live edit requests', () async {
      final tempDir = await Directory.systemTemp.createTemp('live_edit_agent');
      addTearDown(() => tempDir.delete(recursive: true));
      final sourceDir = Directory('${tempDir.path}/lib')..createSync();
      final sourceFile = File('${sourceDir.path}/main.dart')
        ..writeAsStringSync("const Text('Before');");
      final client = _CapturingInferenceClient();

      final service = LiveEditAgentService(
        registry: LiveEditAgentRegistry(
          clients: <String, InferenceClient>{'fake': client},
          defaultBackendId: 'fake',
        ),
      );

      final proposal = await service.resolve(
        LiveEditResolutionRequest(
          sessionId: 'session-prompt-only',
          workingDirectory: tempDir.path,
          instructionText: 'Rewrite the selected heading.',
          primarySelection: LiveEditSelection(
            sessionId: 'session-prompt-only',
            nodeId: 'node-1',
            widgetType: 'Text',
            source: LiveEditSourceLocation(file: sourceFile.path, line: 1),
            rawNode: const <String, Object?>{},
          ),
        ),
      );

      final plan = service.buildExecutionPlan(proposal.proposalId);
      final request = client.lastRequest;

      expect(plan.requestedChanges, ['Rewrite the selected heading.']);
      expect(plan.agentInstruction, contains('Rewrite the selected heading.'));
      expect(request, isNotNull);
      expect(request!.metadata['intentTextPresent'], isTrue);
      expect(request.metadata['requestMode'], 'prompt-only');
      expect(
        request.prompt,
        contains('Implement the requested UI change immediately'),
      );
    });

    test('fails fast when resolve request has no prompt', () async {
      final tempDir = await Directory.systemTemp.createTemp('live_edit_agent');
      addTearDown(() => tempDir.delete(recursive: true));

      final service = LiveEditAgentService(
        registry: LiveEditAgentRegistry(
          clients: <String, InferenceClient>{'fake': _FakeInferenceClient()},
          defaultBackendId: 'fake',
        ),
      );

      await expectLater(
        () => service.resolve(
          LiveEditResolutionRequest(
            sessionId: 'session-empty',
            workingDirectory: tempDir.path,
          ),
        ),
        throwsA(
          isA<LiveEditAgentException>()
              .having(
                (final error) => error.code,
                'code',
                'source_context_unavailable',
              )
              .having(
                (final error) => error.message,
                'message',
                contains('a prompt'),
              ),
        ),
      );
    });

    test(
      'builds execution plan with staged edits and ai intent together',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'live_edit_agent',
        );
        addTearDown(() => tempDir.delete(recursive: true));
        final sourceDir = Directory('${tempDir.path}/lib')..createSync();
        final sourceFile = File('${sourceDir.path}/main.dart')
          ..writeAsStringSync("const Text('Before');");

        final service = LiveEditAgentService(
          registry: LiveEditAgentRegistry(
            clients: <String, InferenceClient>{'fake': _FakeInferenceClient()},
            defaultBackendId: 'fake',
          ),
        );

        final proposal = await service.resolve(
          LiveEditResolutionRequest(
            sessionId: 'session-combined',
            workingDirectory: tempDir.path,
            instructionText: 'Rewrite the selected heading to sound more direct.',
            primarySelection: LiveEditSelection(
              sessionId: 'session-combined',
              nodeId: 'node-1',
              widgetType: 'Text',
              source: LiveEditSourceLocation(file: sourceFile.path, line: 1),
              rawNode: const <String, Object?>{},
            ),
          ),
        );

        final plan = service.buildExecutionPlan(proposal.proposalId);

        expect(plan.requestedChanges, hasLength(1));
        expect(
          plan.requestedChanges.single,
          contains('Rewrite the selected heading to sound more direct.'),
        );
        expect(
          plan.agentInstruction,
          contains('Rewrite the selected heading to sound more direct.'),
        );
      },
    );

    test(
      'compacts large runtime payloads before prompting the backend',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'live_edit_agent',
        );
        addTearDown(() => tempDir.delete(recursive: true));
        final sourceDir = Directory('${tempDir.path}/lib')..createSync();
        final sourceFile = File('${sourceDir.path}/main.dart')
          ..writeAsStringSync('Column(children: const <Widget>[]);');

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
            instructionText: 'Set crossAxisAlignment to start',
            primarySelection: LiveEditSelection(
              sessionId: 'session-compact',
              nodeId: 'node-1',
              widgetType: 'Column',
              renderObjectType: 'RenderFlex',
              source: LiveEditSourceLocation(
                file: sourceFile.path,
                line: 42,
                column: 7,
              ),
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
        expect(request.prompt, contains('[truncated'));
      },
    );

    test('forwards streaming events when backend supports them', () async {
      final tempDir = await Directory.systemTemp.createTemp('live_edit_agent');
      addTearDown(() => tempDir.delete(recursive: true));
      final sourceDir = Directory('${tempDir.path}/lib')..createSync();
      final sourceFile = File('${sourceDir.path}/main.dart')
        ..writeAsStringSync("const Text('Before');");
      final streamedEvents = <InferenceStructuredTextStreamEvent>[];
      final service = LiveEditAgentService(
        registry: LiveEditAgentRegistry(
          clients: <String, InferenceClient>{
            'fake': _StreamingInferenceClient(),
          },
          defaultBackendId: 'fake',
        ),
      );

      final proposal = await service.resolve(
        LiveEditResolutionRequest(
          sessionId: 'session-stream',
          workingDirectory: tempDir.path,
          instructionText: 'Rewrite the selected heading.',
          primarySelection: LiveEditSelection(
            sessionId: 'session-stream',
            nodeId: 'node-1',
            widgetType: 'Text',
            source: LiveEditSourceLocation(file: sourceFile.path, line: 1),
            rawNode: const <String, Object?>{},
          ),
        ),
        onStreamEvent: streamedEvents.add,
      );
      await Future<void>.delayed(Duration.zero);

      expect(proposal.proposalId, 'proposal-1');
      expect(streamedEvents, isNotEmpty);
      expect(
        streamedEvents.first.type,
        InferenceStructuredTextStreamEventType.lifecycle,
      );
      expect(
        streamedEvents.any(
          (final event) =>
              event.type == InferenceStructuredTextStreamEventType.completion &&
              event.completion?.result.success == true,
        ),
        isTrue,
      );
    });

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
            instructionText: 'Set width to 140',
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

    test('fails fast when source context is outside the workspace', () async {
      final tempDir = await Directory.systemTemp.createTemp('live_edit_agent');
      addTearDown(() => tempDir.delete(recursive: true));

      final service = LiveEditAgentService(
        registry: LiveEditAgentRegistry(
          clients: <String, InferenceClient>{'fake': _FakeInferenceClient()},
          defaultBackendId: 'fake',
        ),
      );

      await expectLater(
        () => service.resolve(
          LiveEditResolutionRequest(
            sessionId: 'session-missing-source',
            workingDirectory: tempDir.path,
            instructionText: 'Update text',
            primarySelection: const LiveEditSelection(
              sessionId: 'session-missing-source',
              nodeId: 'node-1',
              widgetType: 'Text',
              source: LiveEditSourceLocation(
                file: '/tmp/outside_workspace.dart',
                line: 12,
              ),
              rawNode: <String, Object?>{},
            ),
          ),
        ),
        throwsA(
          isA<LiveEditAgentException>()
              .having(
                (final error) => error.code,
                'code',
                'source_context_unavailable',
              )
              .having(
                (final error) => error.message,
                'message',
                contains('outside the live edit workspace'),
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
  Set<InferenceTask> get supportedTasks => {InferenceTask.structuredText};

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

  @override
  Future<bool> refreshAvailability() async => true;

  @override
  void resetAvailabilityCache() {}
}

class _FakeInferenceClient implements InferenceClient {
  @override
  String get id => 'fake';

  @override
  bool get isAvailable => true;

  @override
  Set<InferenceTask> get supportedTasks => {InferenceTask.structuredText};

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

  @override
  Future<bool> refreshAvailability() async => true;

  @override
  void resetAvailabilityCache() {}
}

final class _PartialInferenceClient implements InferenceClient {
  @override
  String get id => 'partial';

  @override
  bool get isAvailable => true;

  @override
  Set<InferenceTask> get supportedTasks => {InferenceTask.structuredText};

  @override
  Future<InferenceResult<InferenceResponse>> infer(
    final InferenceRequest request,
  ) async => InferenceResult<InferenceResponse>.ok(
    const InferenceResponse(
      output: <String, dynamic>{
        'summary': 'Adjust width safely.',
        'changedFiles': <String>['lib/main.dart'],
        'warnings': <String>[],
        'validationSteps': <String>[],
      },
    ),
  );

  @override
  Future<bool> refreshAvailability() async => true;

  @override
  void resetAvailabilityCache() {}
}

final class _FakeStreamingSession
    implements InferenceStructuredTextStreamSession {
  @override
  Stream<InferenceStructuredTextStreamEvent> get events =>
      Stream<InferenceStructuredTextStreamEvent>.fromIterable(
        <InferenceStructuredTextStreamEvent>[
          InferenceStructuredTextStreamEvent(
            type: InferenceStructuredTextStreamEventType.lifecycle,
            timestamp: DateTime.utc(2026, 3, 13, 12),
            lifecycleState: InferenceStructuredTextLifecycleState.started,
            message: 'Starting codex exec stream.',
            attempt: 1,
          ),
          InferenceStructuredTextStreamEvent(
            type: InferenceStructuredTextStreamEventType.progress,
            timestamp: DateTime.utc(2026, 3, 13, 12, 0, 1),
            message: 'Running codex exec.',
            attempt: 1,
          ),
          InferenceStructuredTextStreamEvent(
            type: InferenceStructuredTextStreamEventType.completion,
            timestamp: DateTime.utc(2026, 3, 13, 12, 0, 2),
            attempt: 1,
            completion: InferenceStructuredTextCompletion(
              result: InferenceResult<InferenceResponse>.ok(
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
              ),
              attemptCount: 1,
            ),
          ),
        ],
      );

  @override
  Future<InferenceResult<InferenceResponse>> get result async =>
      InferenceResult<InferenceResponse>.ok(
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

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}

final class _StreamingInferenceClient
    implements StructuredTextStreamingInferenceClient {
  @override
  String get id => 'fake_stream';

  @override
  bool get isAvailable => true;

  @override
  Set<InferenceTask> get supportedTasks => {InferenceTask.structuredText};

  @override
  Future<InferenceResult<InferenceResponse>> infer(
    final InferenceRequest request,
  ) async => _FakeInferenceClient().infer(request);

  @override
  Future<bool> refreshAvailability() async => true;

  @override
  void resetAvailabilityCache() {}

  @override
  Future<InferenceStructuredTextStreamSession> streamStructuredText(
    final InferenceRequest request,
  ) async => _FakeStreamingSession();
}

final class _UnavailableInferenceClient extends _FakeInferenceClient {
  @override
  bool get isAvailable => false;
}
