// packages/server_capability_core/test/tools/navigation_tools_test.dart
import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_capability_core/src/tools/navigation_tools.dart';
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
  registerNavigationTools(ctx);
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
  // handle_dialog
  // =========================================================================
  group('navigation tools — handle_dialog', () {
    test('registers handle_dialog', () {
      final ctx = _registeredCtx();
      expect(ctx.registeredToolNames, contains('handle_dialog'));
    });

    test(
      'handle_dialog schema: additionalProperties false, required [action]',
      () {
        final ctx = _registeredCtx();
        final schema = ctx.registrationFor('handle_dialog')!.inputSchema;
        expect(schema['type'], 'object');
        expect(schema['additionalProperties'], isFalse);
        final required = schema['required'] as List;
        expect(required, contains('action'));
        final props = schema['properties'] as Map<String, Object?>;
        expect((props['action']! as Map<String, Object?>)['type'], 'string');
        expect(props.containsKey('connection'), isTrue);
      },
    );

    test(
      'handle_dialog handler builds HandleDialogCommand with action',
      () async {
        final runner = FakeCommandRunner()
          ..nextExecuteResult = CoreResult.success(data: {'dismissed': true});
        final ctx = _registeredCtx(runner: runner);
        final reg = ctx.registrationFor('handle_dialog')!;
        final result = await reg.handler(const <String, Object?>{'action': 'dismiss'});
        expect(result.ok, isTrue);
        expect(runner.executedCommands, hasLength(1));
        final cmd = runner.executedCommands.first as HandleDialogCommand;
        expect(cmd.action, 'dismiss');
      },
    );

    test(
      'handle_dialog action defaults to "dismiss" when not provided',
      () async {
        final runner = FakeCommandRunner()
          ..nextExecuteResult = CoreResult.success(data: {});
        final ctx = _registeredCtx(runner: runner);
        final reg = ctx.registrationFor('handle_dialog')!;
        await reg.handler(const <String, Object?>{});
        final cmd = runner.executedCommands.first as HandleDialogCommand;
        expect(cmd.action, 'dismiss');
      },
    );

    test('handle_dialog handler short-circuits on override failure', () async {
      final runner = FakeCommandRunner()
        ..nextOverrideResult = CoreResult.failure(
          code: CoreErrorCode.connectFailed,
          message: 'no connection',
        );
      final ctx = _registeredCtx(runner: runner);
      final reg = ctx.registrationFor('handle_dialog')!;
      final result = await reg.handler(const <String, Object?>{'action': 'dismiss'});
      expect(result.ok, isFalse);
      expect(runner.executedCommands, isEmpty);
    });

    test(
      'handle_dialog handler returns 5-key error envelope on execute failure',
      () async {
        final runner = FakeCommandRunner()
          ..nextExecuteResult = CoreResult.failure(
            code: CoreErrorCode.interactionFailed,
            message: 'dialog failed',
          );
        final ctx = _registeredCtx(runner: runner);
        final reg = ctx.registrationFor('handle_dialog')!;
        final result = await reg.handler(const <String, Object?>{'action': 'dismiss'});
        expect(result.ok, isFalse);
        final json = agentResultPayload(result);
        _expectEnvelopeKeys(json);
      },
    );
  });

  // =========================================================================
  // navigate
  // =========================================================================
  group('navigation tools — navigate', () {
    test('registers navigate', () {
      final ctx = _registeredCtx();
      expect(ctx.registeredToolNames, contains('navigate'));
    });

    test('navigate schema: additionalProperties false, required [action]', () {
      final ctx = _registeredCtx();
      final schema = ctx.registrationFor('navigate')!.inputSchema;
      expect(schema['type'], 'object');
      expect(schema['additionalProperties'], isFalse);
      final required = schema['required'] as List;
      expect(required, contains('action'));
      final props = schema['properties'] as Map<String, Object?>;
      expect((props['action']! as Map<String, Object?>)['type'], 'string');
      expect((props['route']! as Map<String, Object?>)['type'], 'string');
      final argsSchema = props['arguments'] as Map<String, Object?>;
      expect(argsSchema['type'], 'object');
      expect(argsSchema['additionalProperties'], isTrue);
      expect(props.containsKey('connection'), isTrue);
    });

    test('navigate handler builds NavigateCommand with all args', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.success(data: {'navigated': true});
      final ctx = _registeredCtx(runner: runner);
      final reg = ctx.registrationFor('navigate')!;
      await reg.handler(const <String, Object?>{
            'action': 'push',
            'route': '/details',
            'arguments': {'id': 42},
          });
      final cmd = runner.executedCommands.first as NavigateCommand;
      expect(cmd.action, 'push');
      expect(cmd.route, '/details');
      expect(cmd.arguments, {'id': 42});
    });

    test('navigate action defaults to "push" when not provided', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.success(data: {});
      final ctx = _registeredCtx(runner: runner);
      final reg = ctx.registrationFor('navigate')!;
      await reg.handler(const <String, Object?>{});
      final cmd = runner.executedCommands.first as NavigateCommand;
      expect(cmd.action, 'push');
      expect(cmd.route, isNull);
      expect(cmd.arguments, isNull);
    });

    test('navigate handler short-circuits on override failure', () async {
      final runner = FakeCommandRunner()
        ..nextOverrideResult = CoreResult.failure(
          code: CoreErrorCode.connectFailed,
          message: 'no connection',
        );
      final ctx = _registeredCtx(runner: runner);
      final reg = ctx.registrationFor('navigate')!;
      final result = await reg.handler(const <String, Object?>{'action': 'pop'});
      expect(result.ok, isFalse);
      expect(runner.executedCommands, isEmpty);
    });

    test(
      'navigate handler returns 5-key error envelope on execute failure',
      () async {
        final runner = FakeCommandRunner()
          ..nextExecuteResult = CoreResult.failure(
            code: CoreErrorCode.navigateFailed,
            message: 'navigate failed',
          );
        final ctx = _registeredCtx(runner: runner);
        final reg = ctx.registrationFor('navigate')!;
        final result = await reg.handler(const <String, Object?>{
              'action': 'push',
              'route': '/home',
            });
        expect(result.ok, isFalse);
        final json = agentResultPayload(result);
        _expectEnvelopeKeys(json);
      },
    );
  });
}
