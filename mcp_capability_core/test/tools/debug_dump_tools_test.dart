// mcp_capability_core/test/tools/debug_dump_tools_test.dart
import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:mcp_capability_core/src/tools/debug_dump_tools.dart';
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
  registerDebugDumpTools(ctx);
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

/// Shared schema assertions for all debug dump tools.
/// Each tool has no required fields, additionalProperties: false, and a
/// connection property.
void _expectDumpSchema(final Map<String, Object?> schema) {
  expect(schema['type'], 'object');
  expect(schema['additionalProperties'], isFalse);
  expect(schema.containsKey('required'), isFalse);
  final props = schema['properties'] as Map<String, Object?>;
  expect(props.containsKey('connection'), isTrue);
}

void main() {
  // =========================================================================
  // Registration
  // =========================================================================
  group('debug_dump_tools — registration', () {
    test('registers all 4 dump tools', () {
      final ctx = _registeredCtx();
      expect(
        ctx.registeredToolNames,
        containsAll(<String>[
          'debug_dump_layer_tree',
          'debug_dump_semantics_tree',
          'debug_dump_render_tree',
          'debug_dump_focus_tree',
        ]),
      );
    });
  });

  // =========================================================================
  // debug_dump_layer_tree
  // =========================================================================
  group('debug_dump_tools — debug_dump_layer_tree', () {
    test('schema: no required, additionalProperties false, connection present',
        () {
      final ctx = _registeredCtx();
      _expectDumpSchema(
        ctx.registrationFor('debug_dump_layer_tree')!.inputSchema,
      );
    });

    test('handler executes DebugDumpLayerTreeCommand', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult =
            CoreResult.success(data: {'tree': 'layer data'});
      final ctx = _registeredCtx(runner: runner);
      final reg = ctx.registrationFor('debug_dump_layer_tree')!;
      final result = await reg.handler(
        CallToolRequest(
          name: 'debug_dump_layer_tree',
          arguments: const <String, Object?>{},
        ),
      );
      expect(result.isError, isNot(true));
      expect(runner.executedCommands.first, isA<DebugDumpLayerTreeCommand>());
      final text = (result.content.first as TextContent).text;
      final decoded = jsonDecode(text) as Map<String, Object?>;
      expect(decoded['tree'], 'layer data');
    });

    test('handler short-circuits on override failure', () async {
      final runner = FakeCommandRunner()
        ..nextOverrideResult = CoreResult.failure(
          code: CoreErrorCode.connectFailed,
          message: 'no connection',
        );
      final ctx = _registeredCtx(runner: runner);
      final result = await ctx.registrationFor('debug_dump_layer_tree')!.handler(
        CallToolRequest(
          name: 'debug_dump_layer_tree',
          arguments: const <String, Object?>{},
        ),
      );
      expect(result.isError, isTrue);
      expect(runner.executedCommands, isEmpty);
    });

    test('returns 5-key error envelope on execute failure', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.failure(
          code: CoreErrorCode.interactionFailed,
          message: 'dump failed',
        );
      final ctx = _registeredCtx(runner: runner);
      final result = await ctx.registrationFor('debug_dump_layer_tree')!.handler(
        CallToolRequest(
          name: 'debug_dump_layer_tree',
          arguments: const <String, Object?>{},
        ),
      );
      expect(result.isError, isTrue);
      final json =
          jsonDecode((result.content.first as TextContent).text) as Map<String, Object?>;
      _expectEnvelopeKeys(json);
    });
  });

  // =========================================================================
  // debug_dump_semantics_tree
  // =========================================================================
  group('debug_dump_tools — debug_dump_semantics_tree', () {
    test('schema: no required, additionalProperties false, connection present',
        () {
      final ctx = _registeredCtx();
      _expectDumpSchema(
        ctx.registrationFor('debug_dump_semantics_tree')!.inputSchema,
      );
    });

    test('handler executes DebugDumpSemanticsTreeCommand', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult =
            CoreResult.success(data: {'tree': 'semantics data'});
      final ctx = _registeredCtx(runner: runner);
      final reg = ctx.registrationFor('debug_dump_semantics_tree')!;
      await reg.handler(
        CallToolRequest(
          name: 'debug_dump_semantics_tree',
          arguments: const <String, Object?>{},
        ),
      );
      expect(
        runner.executedCommands.first,
        isA<DebugDumpSemanticsTreeCommand>(),
      );
    });

    test('handler short-circuits on override failure', () async {
      final runner = FakeCommandRunner()
        ..nextOverrideResult = CoreResult.failure(
          code: CoreErrorCode.connectFailed,
          message: 'no connection',
        );
      final ctx = _registeredCtx(runner: runner);
      final result =
          await ctx.registrationFor('debug_dump_semantics_tree')!.handler(
        CallToolRequest(
          name: 'debug_dump_semantics_tree',
          arguments: const <String, Object?>{},
        ),
      );
      expect(result.isError, isTrue);
      expect(runner.executedCommands, isEmpty);
    });

    test('returns 5-key error envelope on execute failure', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.failure(
          code: CoreErrorCode.interactionFailed,
          message: 'dump failed',
        );
      final ctx = _registeredCtx(runner: runner);
      final result =
          await ctx.registrationFor('debug_dump_semantics_tree')!.handler(
        CallToolRequest(
          name: 'debug_dump_semantics_tree',
          arguments: const <String, Object?>{},
        ),
      );
      expect(result.isError, isTrue);
      final json =
          jsonDecode((result.content.first as TextContent).text) as Map<String, Object?>;
      _expectEnvelopeKeys(json);
    });
  });

  // =========================================================================
  // debug_dump_render_tree
  // =========================================================================
  group('debug_dump_tools — debug_dump_render_tree', () {
    test('schema: no required, additionalProperties false, connection present',
        () {
      final ctx = _registeredCtx();
      _expectDumpSchema(
        ctx.registrationFor('debug_dump_render_tree')!.inputSchema,
      );
    });

    test('handler executes DebugDumpRenderTreeCommand', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult =
            CoreResult.success(data: {'tree': 'render data'});
      final ctx = _registeredCtx(runner: runner);
      final reg = ctx.registrationFor('debug_dump_render_tree')!;
      await reg.handler(
        CallToolRequest(
          name: 'debug_dump_render_tree',
          arguments: const <String, Object?>{},
        ),
      );
      expect(
        runner.executedCommands.first,
        isA<DebugDumpRenderTreeCommand>(),
      );
    });

    test('handler short-circuits on override failure', () async {
      final runner = FakeCommandRunner()
        ..nextOverrideResult = CoreResult.failure(
          code: CoreErrorCode.connectFailed,
          message: 'no connection',
        );
      final ctx = _registeredCtx(runner: runner);
      final result =
          await ctx.registrationFor('debug_dump_render_tree')!.handler(
        CallToolRequest(
          name: 'debug_dump_render_tree',
          arguments: const <String, Object?>{},
        ),
      );
      expect(result.isError, isTrue);
      expect(runner.executedCommands, isEmpty);
    });

    test('returns 5-key error envelope on execute failure', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.failure(
          code: CoreErrorCode.interactionFailed,
          message: 'dump failed',
        );
      final ctx = _registeredCtx(runner: runner);
      final result =
          await ctx.registrationFor('debug_dump_render_tree')!.handler(
        CallToolRequest(
          name: 'debug_dump_render_tree',
          arguments: const <String, Object?>{},
        ),
      );
      expect(result.isError, isTrue);
      final json =
          jsonDecode((result.content.first as TextContent).text) as Map<String, Object?>;
      _expectEnvelopeKeys(json);
    });
  });

  // =========================================================================
  // debug_dump_focus_tree
  // =========================================================================
  group('debug_dump_tools — debug_dump_focus_tree', () {
    test('schema: no required, additionalProperties false, connection present',
        () {
      final ctx = _registeredCtx();
      _expectDumpSchema(
        ctx.registrationFor('debug_dump_focus_tree')!.inputSchema,
      );
    });

    test('handler executes DebugDumpFocusTreeCommand', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult =
            CoreResult.success(data: {'tree': 'focus data'});
      final ctx = _registeredCtx(runner: runner);
      final reg = ctx.registrationFor('debug_dump_focus_tree')!;
      await reg.handler(
        CallToolRequest(
          name: 'debug_dump_focus_tree',
          arguments: const <String, Object?>{},
        ),
      );
      expect(
        runner.executedCommands.first,
        isA<DebugDumpFocusTreeCommand>(),
      );
    });

    test('handler short-circuits on override failure', () async {
      final runner = FakeCommandRunner()
        ..nextOverrideResult = CoreResult.failure(
          code: CoreErrorCode.connectFailed,
          message: 'no connection',
        );
      final ctx = _registeredCtx(runner: runner);
      final result =
          await ctx.registrationFor('debug_dump_focus_tree')!.handler(
        CallToolRequest(
          name: 'debug_dump_focus_tree',
          arguments: const <String, Object?>{},
        ),
      );
      expect(result.isError, isTrue);
      expect(runner.executedCommands, isEmpty);
    });

    test('returns 5-key error envelope on execute failure', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.failure(
          code: CoreErrorCode.interactionFailed,
          message: 'dump failed',
        );
      final ctx = _registeredCtx(runner: runner);
      final result =
          await ctx.registrationFor('debug_dump_focus_tree')!.handler(
        CallToolRequest(
          name: 'debug_dump_focus_tree',
          arguments: const <String, Object?>{},
        ),
      );
      expect(result.isError, isTrue);
      final json =
          jsonDecode((result.content.first as TextContent).text) as Map<String, Object?>;
      _expectEnvelopeKeys(json);
    });
  });
}
