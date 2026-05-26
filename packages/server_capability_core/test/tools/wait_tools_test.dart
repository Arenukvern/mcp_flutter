// packages/server_capability_core/test/tools/wait_tools_test.dart

import 'package:flutter_mcp_toolkit_capability_core/src/tools/wait_tools.dart';
import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';
import 'package:flutter_mcp_toolkit_capability_kernel/testing.dart';
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';
import 'package:test/test.dart';

import '../_test_helpers.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

FakeCapabilityContext _makeCtx({FakeCommandRunner? runner}) {
  final r = runner ?? FakeCommandRunner();
  return FakeCapabilityContext(
    capabilityId: 'core',
    services: <Type, HostService>{CommandRunner: r},
  );
}

FakeCapabilityContext _registeredCtx({FakeCommandRunner? runner}) {
  final ctx = _makeCtx(runner: runner);
  registerWaitTools(ctx);
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
  // wait_for — registration & schema
  // =========================================================================
  group('wait tools — wait_for registration', () {
    test('registers wait_for with the bare name (no prefix)', () {
      final ctx = _registeredCtx();
      expect(ctx.registeredToolNames, contains('wait_for'));
    });

    test(
      'wait_for input schema has correct type and additionalProperties:false',
      () {
        final ctx = _registeredCtx();
        final schema = ctx.registrationFor('wait_for')!.inputSchema;
        expect(schema['type'], equals('object'));
        expect(schema['additionalProperties'], isFalse);
      },
    );

    test('wait_for schema has required: [predicate]', () {
      final ctx = _registeredCtx();
      final required =
          ctx.registrationFor('wait_for')!.inputSchema['required']
              as List<Object?>;
      expect(required, contains('predicate'));
      expect(required, isNot(contains('timeoutMs')));
    });

    test(
      'wait_for schema — predicate is object with additionalProperties:true',
      () {
        final ctx = _registeredCtx();
        final props =
            ctx.registrationFor('wait_for')!.inputSchema['properties']
                as Map<String, Object?>;
        final predSchema = props['predicate'] as Map<String, Object?>;
        expect(predSchema['type'], equals('object'));
        // additionalProperties must be explicitly true — legacy parity (Schema.object(additionalProperties:true))
        expect(
          predSchema['additionalProperties'],
          isTrue,
          reason:
              'predicate schema must allow arbitrary keys (additionalProperties:true)',
        );
      },
    );

    test('wait_for schema — timeoutMs is integer', () {
      final ctx = _registeredCtx();
      final props =
          ctx.registrationFor('wait_for')!.inputSchema['properties']
              as Map<String, Object?>;
      final tSchema = props['timeoutMs'] as Map<String, Object?>;
      expect(tSchema['type'], equals('integer'));
    });

    test('wait_for schema includes connection override property', () {
      final ctx = _registeredCtx();
      final props =
          ctx.registrationFor('wait_for')!.inputSchema['properties']
              as Map<String, Object?>;
      expect(props.containsKey('connection'), isTrue);
      final connSchema = props['connection'] as Map<String, Object?>;
      expect(connSchema['type'], equals('object'));
      final connProps = connSchema['properties'] as Map<String, Object?>;
      expect(connProps.containsKey('targetId'), isTrue);
      expect(connProps.containsKey('mode'), isTrue);
    });
  });

  // =========================================================================
  // wait_for — handler: command construction
  // =========================================================================
  group('wait tools — wait_for handler command construction', () {
    test(
      'handler builds WaitForCommand with provided predicate and timeoutMs',
      () async {
        final fakeRunner = FakeCommandRunner();
        final ctx = _registeredCtx(runner: fakeRunner);
        await ctx
            .registrationFor('wait_for')!
            .handler(<String, Object?>{
                  'predicate': {'kind': 'text', 'text': 'Submit'},
                  'timeoutMs': 8000,
                });
        expect(fakeRunner.executedCommands, hasLength(1));
        final cmd = fakeRunner.executedCommands.first as WaitForCommand;
        expect(cmd.predicate, equals({'kind': 'text', 'text': 'Submit'}));
        expect(cmd.timeoutMs, equals(8000));
      },
    );

    test('handler defaults timeoutMs to 5000 when not provided', () async {
      final fakeRunner = FakeCommandRunner();
      final ctx = _registeredCtx(runner: fakeRunner);
      await ctx
          .registrationFor('wait_for')!
          .handler(<String, Object?>{
                'predicate': {'kind': 'stable', 'stableWindowMs': 200},
              });
      final cmd = fakeRunner.executedCommands.first as WaitForCommand;
      expect(
        cmd.timeoutMs,
        equals(5000),
        reason: 'omitted timeoutMs must default to 5000 (legacy parity)',
      );
    });

    test(
      'handler defaults timeoutMs to 5000 when timeoutMs is 0 (legacy parity)',
      () async {
        // intArgOrNull returns null for 0, so ?? 5000 applies.
        final fakeRunner = FakeCommandRunner();
        final ctx = _registeredCtx(runner: fakeRunner);
        await ctx
            .registrationFor('wait_for')!
            .handler(<String, Object?>{
                  'predicate': {'kind': 'time', 'ms': 100},
                  'timeoutMs': 0,
                });
        final cmd = fakeRunner.executedCommands.first as WaitForCommand;
        expect(cmd.timeoutMs, equals(5000));
      },
    );

    test(
      'handler uses empty predicate map when predicate is not a Map',
      () async {
        final fakeRunner = FakeCommandRunner();
        final ctx = _registeredCtx(runner: fakeRunner);
        // Schema validation would normally block this, but the handler should
        // be defensive.
        await ctx
            .registrationFor('wait_for')!
            .handler(<String, Object?>{'predicate': 'not-a-map'});
        final cmd = fakeRunner.executedCommands.first as WaitForCommand;
        expect(cmd.predicate, isEmpty);
      },
    );

    test('handler calls applyConnectionOverride before execute', () async {
      final fakeRunner = FakeCommandRunner();
      final ctx = _registeredCtx(runner: fakeRunner);
      final args = <String, Object?>{
        'predicate': {'kind': 'time', 'ms': 50},
        'connection': {'port': 9999},
      };
      await ctx
          .registrationFor('wait_for')!
          .handler(args);
      expect(fakeRunner.overrideArguments, hasLength(1));
      expect(fakeRunner.overrideArguments.first, equals(args));
      expect(fakeRunner.executedCommands, hasLength(1));
    });
  });

  // =========================================================================
  // wait_for — handler: three outcome paths
  // =========================================================================
  group('wait tools — wait_for outcomes', () {
    test(
      'outcome: match success — non-error CallToolResult with matched:true',
      () async {
        final fakeRunner = FakeCommandRunner()
          ..nextExecuteResult = CoreResult.success(
            data: <String, Object?>{'matched': true, 'elapsedMs': 312},
          );
        final ctx = _registeredCtx(runner: fakeRunner);
        final result = await ctx
            .registrationFor('wait_for')!
            .handler(<String, Object?>{
                  'predicate': {'kind': 'text', 'text': 'Done'},
                });
        expect(result.ok, isTrue);
        final json = agentResultPayload(result);
        expect(json['matched'], isTrue);
        expect(json['elapsedMs'], equals(312));
      },
    );

    test('outcome: timeout — error envelope with waitTimeout code', () async {
      final fakeRunner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.failure(
          code: CoreErrorCode.waitTimeout,
          message: 'wait_for timed out after 5000ms',
          details: <String, Object?>{'matched': false, 'elapsedMs': 5000},
        );
      final ctx = _registeredCtx(runner: fakeRunner);
      final result = await ctx
          .registrationFor('wait_for')!
          .handler(<String, Object?>{
                'predicate': {'kind': 'text', 'text': 'Never'},
                'timeoutMs': 5000,
              });
      expect(result.ok, isFalse);
      final json = agentResultPayload(result);
      expect(json['code'], equals(CoreErrorCode.waitTimeout));
      _expectEnvelopeKeys(json);
    });

    test(
      'outcome: actual error — error envelope with waitForFailed code',
      () async {
        final fakeRunner = FakeCommandRunner()
          ..nextExecuteResult = CoreResult.failure(
            code: CoreErrorCode.waitForFailed,
            message: 'wait_for returned malformed payload',
          );
        final ctx = _registeredCtx(runner: fakeRunner);
        final result = await ctx
            .registrationFor('wait_for')!
            .handler(<String, Object?>{
                  'predicate': {'kind': 'text', 'text': 'X'},
                });
        expect(result.ok, isFalse);
        final json = agentResultPayload(result);
        expect(json['code'], equals(CoreErrorCode.waitForFailed));
        _expectEnvelopeKeys(json);
      },
    );

    test(
      'override short-circuit — executedCommands is empty, isError is true',
      () async {
        final fakeRunner = FakeCommandRunner()
          ..nextOverrideResult = CoreResult.failure(
            code: CoreErrorCode.connectFailed,
            message: 'No app running on port 9999',
          );
        final ctx = _registeredCtx(runner: fakeRunner);
        final result = await ctx
            .registrationFor('wait_for')!
            .handler(<String, Object?>{
                  'predicate': {'kind': 'time', 'ms': 100},
                  'connection': {'port': 9999},
                });
        expect(fakeRunner.executedCommands, isEmpty);
        expect(result.ok, isFalse);
        final json = agentResultPayload(result);
        expect(json['code'], equals(CoreErrorCode.connectFailed));
        _expectEnvelopeKeys(json);
      },
    );
  });
}
