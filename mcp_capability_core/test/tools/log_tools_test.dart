// mcp_capability_core/test/tools/log_tools_test.dart
import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:mcp_capability_core/src/tools/log_tools.dart';
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';
import 'package:mcp_capability_kernel/testing.dart';
import 'package:mcp_shared_core/mcp_shared_core.dart';
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
  registerLogTools(ctx);
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
  // get_recent_logs
  // =========================================================================
  group('log tools — get_recent_logs', () {
    test('registers get_recent_logs', () {
      final ctx = _registeredCtx();
      expect(ctx.registeredToolNames, contains('get_recent_logs'));
    });

    test('get_recent_logs schema: additionalProperties false, no required', () {
      final ctx = _registeredCtx();
      final schema = ctx.registrationFor('get_recent_logs')!.inputSchema;
      expect(schema['type'], 'object');
      expect(schema['additionalProperties'], isFalse);
      expect(schema.containsKey('required'), isFalse);
      final props = schema['properties'] as Map<String, Object?>;
      expect((props['count']! as Map<String, Object?>)['type'], 'integer');
      expect(props.containsKey('connection'), isTrue);
    });

    test('get_recent_logs handler builds GetRecentLogsCommand with count',
        () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult =
            CoreResult.success(data: ['log line 1']);
      final ctx = _registeredCtx(runner: runner);
      final reg = ctx.registrationFor('get_recent_logs')!;
      await reg.handler(
        CallToolRequest(
          name: 'get_recent_logs',
          arguments: const <String, Object?>{'count': 25},
        ),
      );
      expect(runner.executedCommands, hasLength(1));
      final cmd = runner.executedCommands.first as GetRecentLogsCommand;
      expect(cmd.count, 25);
    });

    test('get_recent_logs count defaults to 50 when not provided', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.success(data: []);
      final ctx = _registeredCtx(runner: runner);
      final reg = ctx.registrationFor('get_recent_logs')!;
      await reg.handler(
        CallToolRequest(
          name: 'get_recent_logs',
          arguments: const <String, Object?>{},
        ),
      );
      final cmd = runner.executedCommands.first as GetRecentLogsCommand;
      expect(cmd.count, 50);
    });

    test('get_recent_logs handler short-circuits on override failure', () async {
      final runner = FakeCommandRunner()
        ..nextOverrideResult = CoreResult.failure(
          code: CoreErrorCode.connectFailed,
          message: 'no connection',
        );
      final ctx = _registeredCtx(runner: runner);
      final reg = ctx.registrationFor('get_recent_logs')!;
      final result = await reg.handler(
        CallToolRequest(
          name: 'get_recent_logs',
          arguments: const <String, Object?>{},
        ),
      );
      expect(result.isError, isTrue);
      expect(runner.executedCommands, isEmpty);
    });

    test(
        'get_recent_logs handler returns 5-key error envelope on execute failure',
        () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.failure(
          code: CoreErrorCode.interactionFailed,
          message: 'logs failed',
        );
      final ctx = _registeredCtx(runner: runner);
      final reg = ctx.registrationFor('get_recent_logs')!;
      final result = await reg.handler(
        CallToolRequest(
          name: 'get_recent_logs',
          arguments: const <String, Object?>{},
        ),
      );
      expect(result.isError, isTrue);
      final text = (result.content.first as TextContent).text;
      final json = jsonDecode(text) as Map<String, Object?>;
      _expectEnvelopeKeys(json);
    });
  });
}
