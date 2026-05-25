// packages/server_capability_core/test/tools/semantic_tools_test.dart
import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_capability_core/src/tools/semantic_tools.dart';
import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';
import 'package:flutter_mcp_toolkit_capability_kernel/testing.dart';
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';
import 'package:test/test.dart';

import '../_test_helpers.dart';

FakeCapabilityContext _makeCtx({FakeCommandRunner? runner}) {
  final r = runner ?? FakeCommandRunner();
  return FakeCapabilityContext(
    capabilityId: 'core',
    services: <Type, HostService>{CommandRunner: r},
  );
}

FakeCapabilityContext _registeredCtx({FakeCommandRunner? runner}) {
  final ctx = _makeCtx(runner: runner);
  registerSemanticTools(ctx);
  return ctx;
}

void _expectEnvelopeKeys(final Map<String, Object?> json) {
  expect(json.containsKey('code'), isTrue, reason: 'envelope must have code');
  expect(
    json.containsKey('message'),
    isTrue,
    reason: 'envelope must have message',
  );
  expect(
    json.containsKey('details'),
    isTrue,
    reason: 'envelope must have details',
  );
  expect(
    json.containsKey('descriptor'),
    isTrue,
    reason: 'envelope must have descriptor',
  );
  expect(
    json.containsKey('recovery'),
    isTrue,
    reason: 'envelope must have recovery',
  );
}

void main() {
  // =========================================================================
  // semantic_snapshot
  // =========================================================================
  group('semantic tools — semantic_snapshot', () {
    test('registers semantic_snapshot', () {
      final ctx = _registeredCtx();
      expect(ctx.registeredToolNames, contains('semantic_snapshot'));
    });

    test(
      'semantic_snapshot schema: additionalProperties false, no required',
      () {
        final ctx = _registeredCtx();
        final schema = ctx.registrationFor('semantic_snapshot')!.inputSchema;
        expect(schema['type'], 'object');
        expect(schema['additionalProperties'], isFalse);
        expect(schema.containsKey('required'), isFalse);
        final props = schema['properties'] as Map<String, Object?>;
        expect(props.containsKey('connection'), isTrue);
      },
    );

    test(
      'semantic_snapshot handler delegates to CommandRunner.execute',
      () async {
        final snapshotData = <String, Object?>{'nodes': [], 'snapshotId': 1};
        final runner = FakeCommandRunner()
          ..nextExecuteResult = CoreResult.success(data: snapshotData);
        final ctx = _registeredCtx(runner: runner);
        final reg = ctx.registrationFor('semantic_snapshot')!;
        final result = await reg.handler(const <String, Object?>{});
        expect(result.ok, isTrue);
        expect(runner.executedCommands, hasLength(1));
        expect(runner.executedCommands.first, isA<SemanticSnapshotCommand>());
        final json = agentResultPayload(result);
        expect(json['snapshotId'], 1);
      },
    );

    test(
      'semantic_snapshot handler calls applyConnectionOverride before execute',
      () async {
        final runner = FakeCommandRunner()
          ..nextExecuteResult = CoreResult.success(data: {});
        final ctx = _registeredCtx(runner: runner);
        final reg = ctx.registrationFor('semantic_snapshot')!;
        await reg.handler(const <String, Object?>{});
        expect(runner.callLog.first, 'applyConnectionOverride');
        expect(runner.callLog[1], 'execute');
      },
    );

    test(
      'semantic_snapshot handler short-circuits on override failure',
      () async {
        final runner = FakeCommandRunner()
          ..nextOverrideResult = CoreResult.failure(
            code: CoreErrorCode.connectFailed,
            message: 'no connection',
          );
        final ctx = _registeredCtx(runner: runner);
        final reg = ctx.registrationFor('semantic_snapshot')!;
        final result = await reg.handler(const <String, Object?>{});
        expect(result.ok, isFalse);
        expect(runner.executedCommands, isEmpty);
      },
    );

    test(
      'semantic_snapshot handler returns 5-key error envelope on execute failure',
      () async {
        final runner = FakeCommandRunner()
          ..nextExecuteResult = CoreResult.failure(
            code: CoreErrorCode.interactionFailed,
            message: 'snapshot failed',
          );
        final ctx = _registeredCtx(runner: runner);
        final reg = ctx.registrationFor('semantic_snapshot')!;
        final result = await reg.handler(const <String, Object?>{});
        expect(result.ok, isFalse);
        final json = agentResultPayload(result);
        _expectEnvelopeKeys(json);
      },
    );
  });
}
