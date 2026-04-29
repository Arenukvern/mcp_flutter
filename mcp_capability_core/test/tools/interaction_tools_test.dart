// mcp_capability_core/test/tools/interaction_tools_test.dart
import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:mcp_capability_core/src/tools/interaction_tools.dart';
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';
import 'package:mcp_capability_kernel/testing.dart';
import 'package:mcp_shared_core/mcp_shared_core.dart';
import 'package:test/test.dart';

import '../_test_helpers.dart';

// ---------------------------------------------------------------------------
// Helper: build a context with registerInteractionTools applied.
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
  registerInteractionTools(ctx);
  return ctx;
}

// ---------------------------------------------------------------------------
// Helper: assert the 5-key error envelope.
// ---------------------------------------------------------------------------
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
  // tap_widget
  // =========================================================================
  group('interaction tools — tap_widget', () {
    test('registers tap_widget with the bare name (no prefix)', () {
      final ctx = _registeredCtx();
      expect(
        ctx.registeredToolNames,
        contains('tap_widget'),
        reason:
            'capability registers BARE name; kernel/host applies prefix '
            'only at the host boundary',
      );
    });

    test('tap_widget input schema has correct type and required fields', () {
      final ctx = _registeredCtx();
      final reg = ctx.registrationFor('tap_widget');
      expect(reg, isNotNull);
      final schema = reg!.inputSchema;
      expect(schema['type'], 'object');
      expect(schema['additionalProperties'], isFalse);
      final required = schema['required'] as List<Object?>;
      expect(required, contains('ref'));
      final properties = schema['properties'] as Map<String, Object?>;
      expect(properties.containsKey('ref'), isTrue);
      expect(properties.containsKey('snapshotId'), isTrue);
    });

    test('tap_widget schema includes connection override property', () {
      final ctx = _registeredCtx();
      final reg = ctx.registrationFor('tap_widget')!;
      final properties = reg.inputSchema['properties'] as Map<String, Object?>;
      expect(
        properties.containsKey('connection'),
        isTrue,
        reason: 'connection override property must be present in schema',
      );
      final connSchema = properties['connection'] as Map<String, Object?>;
      expect(connSchema['type'], equals('object'));
      final connProps = connSchema['properties'] as Map<String, Object?>;
      expect(connProps.containsKey('targetId'), isTrue);
      expect(connProps.containsKey('mode'), isTrue);
    });

    test('tap_widget handler delegates to CommandRunner.execute', () async {
      final fakeRunner = FakeCommandRunner();
      final ctx = _registeredCtx(runner: fakeRunner);
      final reg = ctx.registrationFor('tap_widget')!;
      final result = await reg.handler(
        CallToolRequest(
          name: 'tap_widget',
          arguments: const <String, Object?>{
            'ref': 's_0',
            'snapshotId': 42,
          },
        ),
      );
      expect(fakeRunner.executedCommands, hasLength(1));
      final cmd = fakeRunner.executedCommands.first as TapWidgetCommand;
      expect(cmd.ref, equals('s_0'));
      expect(cmd.snapshotId, equals(42));
      expect(result, isA<CallToolResult>());
      expect(result.isError, isNot(true));
    });

    test('tap_widget handler omits snapshotId when not provided', () async {
      final fakeRunner = FakeCommandRunner();
      final ctx = _registeredCtx(runner: fakeRunner);
      final reg = ctx.registrationFor('tap_widget')!;
      await reg.handler(
        CallToolRequest(
          name: 'tap_widget',
          arguments: const <String, Object?>{'ref': 'btn-submit'},
        ),
      );
      expect(fakeRunner.executedCommands, hasLength(1));
      final cmd = fakeRunner.executedCommands.first as TapWidgetCommand;
      expect(cmd.snapshotId, isNull);
    });

    test('tap_widget handler treats snapshotId == 0 as absent (legacy parity)',
        () async {
      final fakeRunner = FakeCommandRunner();
      final ctx = _registeredCtx(runner: fakeRunner);
      final reg = ctx.registrationFor('tap_widget')!;
      await reg.handler(
        CallToolRequest(
          name: 'tap_widget',
          arguments: const <String, Object?>{'ref': 's_1', 'snapshotId': 0},
        ),
      );
      final cmd = fakeRunner.executedCommands.first as TapWidgetCommand;
      expect(cmd.snapshotId, isNull);
    });

    test('tap_widget handler calls applyConnectionOverride before execute',
        () async {
      final fakeRunner = FakeCommandRunner();
      final ctx = _registeredCtx(runner: fakeRunner);
      final reg = ctx.registrationFor('tap_widget')!;
      final args = const <String, Object?>{
        'ref': 's_2',
        'connection': {'port': 9999},
      };
      await reg.handler(CallToolRequest(name: 'tap_widget', arguments: args));
      expect(fakeRunner.overrideArguments, hasLength(1));
      expect(fakeRunner.overrideArguments.first, equals(args));
      // execute is also called (override returned null = success)
      expect(fakeRunner.executedCommands, hasLength(1));
    });

    test('tap_widget handler short-circuits on connection override failure',
        () async {
      final fakeRunner = FakeCommandRunner()
        ..nextOverrideResult = CoreResult.failure(
          code: CoreErrorCode.connectFailed,
          message: 'No app running on port 9999',
        );
      final ctx = _registeredCtx(runner: fakeRunner);
      final reg = ctx.registrationFor('tap_widget')!;
      final result = await reg.handler(
        CallToolRequest(
          name: 'tap_widget',
          arguments: const <String, Object?>{
            'ref': 's_0',
            'connection': {'port': 9999},
          },
        ),
      );
      // Must not execute the tap command when override fails.
      expect(fakeRunner.executedCommands, isEmpty);
      expect(result.isError, isTrue);
      // Error content must be the structured JSON envelope.
      final text = (result.content.first as TextContent).text;
      final json = jsonDecode(text) as Map<String, Object?>;
      expect(json['code'], equals(CoreErrorCode.connectFailed));
      _expectEnvelopeKeys(json);
    });

    test('tap_widget handler returns structured error envelope on execute failure',
        () async {
      final fakeRunner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.failure(
          code: CoreErrorCode.interactionFailed,
          message: 'Widget not found',
        );
      final ctx = _registeredCtx(runner: fakeRunner);
      final reg = ctx.registrationFor('tap_widget')!;
      final result = await reg.handler(
        CallToolRequest(
          name: 'tap_widget',
          arguments: const <String, Object?>{'ref': 's_0'},
        ),
      );
      expect(result.isError, isTrue);
      final text = (result.content.first as TextContent).text;
      final json = jsonDecode(text) as Map<String, Object?>;
      expect(json['code'], equals(CoreErrorCode.interactionFailed));
      expect(json['message'], equals('Widget not found'));
      _expectEnvelopeKeys(json);
    });
  });

  // =========================================================================
  // enter_text
  // =========================================================================
  group('interaction tools — enter_text', () {
    test('registers enter_text', () {
      final ctx = _registeredCtx();
      expect(ctx.registeredToolNames, contains('enter_text'));
    });

    test('enter_text schema: additionalProperties false, required [ref, text]',
        () {
      final ctx = _registeredCtx();
      final schema = ctx.registrationFor('enter_text')!.inputSchema;
      expect(schema['additionalProperties'], isFalse);
      final required = schema['required'] as List<Object?>;
      expect(required, containsAll(<String>['ref', 'text']));
      final props = schema['properties'] as Map<String, Object?>;
      expect(props.containsKey('ref'), isTrue);
      expect(props.containsKey('text'), isTrue);
      expect(props.containsKey('snapshotId'), isTrue);
      expect(props.containsKey('connection'), isTrue);
    });

    test('enter_text handler builds EnterTextCommand with correct args',
        () async {
      final fakeRunner = FakeCommandRunner();
      final ctx = _registeredCtx(runner: fakeRunner);
      await ctx.registrationFor('enter_text')!.handler(
        CallToolRequest(
          name: 'enter_text',
          arguments: const <String, Object?>{
            'ref': 'tf_0',
            'text': 'hello world',
            'snapshotId': 7,
          },
        ),
      );
      expect(fakeRunner.executedCommands, hasLength(1));
      final cmd = fakeRunner.executedCommands.first as EnterTextCommand;
      expect(cmd.ref, equals('tf_0'));
      expect(cmd.text, equals('hello world'));
      expect(cmd.snapshotId, equals(7));
    });

    test('enter_text handler short-circuits on override failure', () async {
      final fakeRunner = FakeCommandRunner()
        ..nextOverrideResult = CoreResult.failure(
          code: CoreErrorCode.connectFailed,
          message: 'no app',
        );
      final ctx = _registeredCtx(runner: fakeRunner);
      final result = await ctx.registrationFor('enter_text')!.handler(
        CallToolRequest(
          name: 'enter_text',
          arguments: const <String, Object?>{'ref': 'tf_0', 'text': 'hi'},
        ),
      );
      expect(fakeRunner.executedCommands, isEmpty);
      expect(result.isError, isTrue);
      final json =
          jsonDecode((result.content.first as TextContent).text)
              as Map<String, Object?>;
      _expectEnvelopeKeys(json);
    });

    test('enter_text handler returns error envelope on execute failure',
        () async {
      final fakeRunner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.failure(
          code: CoreErrorCode.interactionFailed,
          message: 'field not found',
        );
      final ctx = _registeredCtx(runner: fakeRunner);
      final result = await ctx.registrationFor('enter_text')!.handler(
        CallToolRequest(
          name: 'enter_text',
          arguments: const <String, Object?>{'ref': 'tf_0', 'text': 'hi'},
        ),
      );
      expect(result.isError, isTrue);
      final json =
          jsonDecode((result.content.first as TextContent).text)
              as Map<String, Object?>;
      _expectEnvelopeKeys(json);
      expect(json['code'], equals(CoreErrorCode.interactionFailed));
    });
  });

  // =========================================================================
  // scroll
  // =========================================================================
  group('interaction tools — scroll', () {
    test('registers scroll', () {
      final ctx = _registeredCtx();
      expect(ctx.registeredToolNames, contains('scroll'));
    });

    test('scroll schema: additionalProperties false, required [direction]', () {
      final ctx = _registeredCtx();
      final schema = ctx.registrationFor('scroll')!.inputSchema;
      expect(schema['additionalProperties'], isFalse);
      final required = schema['required'] as List<Object?>;
      expect(required, contains('direction'));
      final props = schema['properties'] as Map<String, Object?>;
      expect(props.containsKey('direction'), isTrue);
      expect(props.containsKey('ref'), isTrue);
      expect(props.containsKey('distance'), isTrue);
      expect(props.containsKey('snapshotId'), isTrue);
      expect(props.containsKey('connection'), isTrue);
    });

    test('scroll handler builds ScrollCommand with direction, ref, distance',
        () async {
      final fakeRunner = FakeCommandRunner();
      final ctx = _registeredCtx(runner: fakeRunner);
      await ctx.registrationFor('scroll')!.handler(
        CallToolRequest(
          name: 'scroll',
          arguments: const <String, Object?>{
            'direction': 'down',
            'ref': 's_3',
            'distance': 500,
            'snapshotId': 2,
          },
        ),
      );
      final cmd = fakeRunner.executedCommands.first as ScrollCommand;
      expect(cmd.direction, equals('down'));
      expect(cmd.ref, equals('s_3'));
      expect(cmd.distance, equals(500.0));
      expect(cmd.snapshotId, equals(2));
    });

    test('scroll uses direction fallback "down" when direction not provided',
        () async {
      // direction is in `required` so schema validation would block this,
      // but the handler itself should still apply the fallback for safety.
      final fakeRunner = FakeCommandRunner();
      final ctx = _registeredCtx(runner: fakeRunner);
      // Pass an empty string which collapses to null via _stringArgOrNull.
      await ctx.registrationFor('scroll')!.handler(
        CallToolRequest(
          name: 'scroll',
          arguments: const <String, Object?>{'direction': ''},
        ),
      );
      final cmd = fakeRunner.executedCommands.first as ScrollCommand;
      expect(cmd.direction, equals('down'));
    });

    test('scroll ref is null when omitted', () async {
      final fakeRunner = FakeCommandRunner();
      final ctx = _registeredCtx(runner: fakeRunner);
      await ctx.registrationFor('scroll')!.handler(
        CallToolRequest(
          name: 'scroll',
          arguments: const <String, Object?>{'direction': 'up'},
        ),
      );
      final cmd = fakeRunner.executedCommands.first as ScrollCommand;
      expect(cmd.ref, isNull);
    });

    test('scroll distance defaults to 300 when omitted', () async {
      final fakeRunner = FakeCommandRunner();
      final ctx = _registeredCtx(runner: fakeRunner);
      await ctx.registrationFor('scroll')!.handler(
        CallToolRequest(
          name: 'scroll',
          arguments: const <String, Object?>{'direction': 'up'},
        ),
      );
      final cmd = fakeRunner.executedCommands.first as ScrollCommand;
      expect(cmd.distance, equals(300.0));
    });

    test('scroll handler short-circuits on override failure', () async {
      final fakeRunner = FakeCommandRunner()
        ..nextOverrideResult = CoreResult.failure(
          code: CoreErrorCode.connectFailed,
          message: 'no app',
        );
      final ctx = _registeredCtx(runner: fakeRunner);
      final result = await ctx.registrationFor('scroll')!.handler(
        CallToolRequest(
          name: 'scroll',
          arguments: const <String, Object?>{'direction': 'down'},
        ),
      );
      expect(fakeRunner.executedCommands, isEmpty);
      expect(result.isError, isTrue);
      final json =
          jsonDecode((result.content.first as TextContent).text)
              as Map<String, Object?>;
      _expectEnvelopeKeys(json);
    });

    test('scroll handler returns error envelope on execute failure', () async {
      final fakeRunner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.failure(
          code: CoreErrorCode.interactionFailed,
          message: 'scroll failed',
        );
      final ctx = _registeredCtx(runner: fakeRunner);
      final result = await ctx.registrationFor('scroll')!.handler(
        CallToolRequest(
          name: 'scroll',
          arguments: const <String, Object?>{'direction': 'down'},
        ),
      );
      expect(result.isError, isTrue);
      final json =
          jsonDecode((result.content.first as TextContent).text)
              as Map<String, Object?>;
      _expectEnvelopeKeys(json);
    });
  });

  // =========================================================================
  // long_press
  // =========================================================================
  group('interaction tools — long_press', () {
    test('registers long_press', () {
      final ctx = _registeredCtx();
      expect(ctx.registeredToolNames, contains('long_press'));
    });

    test('long_press schema: additionalProperties false, required [ref]', () {
      final ctx = _registeredCtx();
      final schema = ctx.registrationFor('long_press')!.inputSchema;
      expect(schema['additionalProperties'], isFalse);
      final required = schema['required'] as List<Object?>;
      expect(required, contains('ref'));
      final props = schema['properties'] as Map<String, Object?>;
      expect(props.containsKey('ref'), isTrue);
      expect(props.containsKey('snapshotId'), isTrue);
      expect(props.containsKey('connection'), isTrue);
    });

    test('long_press handler builds LongPressCommand', () async {
      final fakeRunner = FakeCommandRunner();
      final ctx = _registeredCtx(runner: fakeRunner);
      await ctx.registrationFor('long_press')!.handler(
        CallToolRequest(
          name: 'long_press',
          arguments: const <String, Object?>{'ref': 's_5', 'snapshotId': 3},
        ),
      );
      final cmd = fakeRunner.executedCommands.first as LongPressCommand;
      expect(cmd.ref, equals('s_5'));
      expect(cmd.snapshotId, equals(3));
    });

    test('long_press handler short-circuits on override failure', () async {
      final fakeRunner = FakeCommandRunner()
        ..nextOverrideResult = CoreResult.failure(
          code: CoreErrorCode.connectFailed,
          message: 'no app',
        );
      final ctx = _registeredCtx(runner: fakeRunner);
      final result = await ctx.registrationFor('long_press')!.handler(
        CallToolRequest(
          name: 'long_press',
          arguments: const <String, Object?>{'ref': 's_5'},
        ),
      );
      expect(fakeRunner.executedCommands, isEmpty);
      expect(result.isError, isTrue);
      final json =
          jsonDecode((result.content.first as TextContent).text)
              as Map<String, Object?>;
      _expectEnvelopeKeys(json);
    });

    test('long_press handler returns error envelope on execute failure',
        () async {
      final fakeRunner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.failure(
          code: CoreErrorCode.interactionFailed,
          message: 'long press failed',
        );
      final ctx = _registeredCtx(runner: fakeRunner);
      final result = await ctx.registrationFor('long_press')!.handler(
        CallToolRequest(
          name: 'long_press',
          arguments: const <String, Object?>{'ref': 's_5'},
        ),
      );
      expect(result.isError, isTrue);
      final json =
          jsonDecode((result.content.first as TextContent).text)
              as Map<String, Object?>;
      _expectEnvelopeKeys(json);
    });
  });

  // =========================================================================
  // swipe
  // =========================================================================
  group('interaction tools — swipe', () {
    test('registers swipe', () {
      final ctx = _registeredCtx();
      expect(ctx.registeredToolNames, contains('swipe'));
    });

    test('swipe schema: additionalProperties false, required [direction]', () {
      final ctx = _registeredCtx();
      final schema = ctx.registrationFor('swipe')!.inputSchema;
      expect(schema['additionalProperties'], isFalse);
      final required = schema['required'] as List<Object?>;
      expect(required, contains('direction'));
      final props = schema['properties'] as Map<String, Object?>;
      expect(props.containsKey('direction'), isTrue);
      expect(props.containsKey('ref'), isTrue);
      expect(props.containsKey('distance'), isTrue);
      expect(props.containsKey('snapshotId'), isTrue);
      expect(props.containsKey('connection'), isTrue);
    });

    test('swipe handler builds SwipeCommand with all args', () async {
      final fakeRunner = FakeCommandRunner();
      final ctx = _registeredCtx(runner: fakeRunner);
      await ctx.registrationFor('swipe')!.handler(
        CallToolRequest(
          name: 'swipe',
          arguments: const <String, Object?>{
            'direction': 'left',
            'ref': 's_6',
            'distance': 400,
            'snapshotId': 5,
          },
        ),
      );
      final cmd = fakeRunner.executedCommands.first as SwipeCommand;
      expect(cmd.direction, equals('left'));
      expect(cmd.ref, equals('s_6'));
      expect(cmd.distance, equals(400.0));
      expect(cmd.snapshotId, equals(5));
    });

    test('swipe uses direction fallback "up" when direction is empty', () async {
      final fakeRunner = FakeCommandRunner();
      final ctx = _registeredCtx(runner: fakeRunner);
      await ctx.registrationFor('swipe')!.handler(
        CallToolRequest(
          name: 'swipe',
          arguments: const <String, Object?>{'direction': ''},
        ),
      );
      final cmd = fakeRunner.executedCommands.first as SwipeCommand;
      expect(cmd.direction, equals('up'));
    });

    test('swipe distance defaults to 300 when omitted', () async {
      final fakeRunner = FakeCommandRunner();
      final ctx = _registeredCtx(runner: fakeRunner);
      await ctx.registrationFor('swipe')!.handler(
        CallToolRequest(
          name: 'swipe',
          arguments: const <String, Object?>{'direction': 'up'},
        ),
      );
      final cmd = fakeRunner.executedCommands.first as SwipeCommand;
      expect(cmd.distance, equals(300.0));
    });

    test('swipe handler short-circuits on override failure', () async {
      final fakeRunner = FakeCommandRunner()
        ..nextOverrideResult = CoreResult.failure(
          code: CoreErrorCode.connectFailed,
          message: 'no app',
        );
      final ctx = _registeredCtx(runner: fakeRunner);
      final result = await ctx.registrationFor('swipe')!.handler(
        CallToolRequest(
          name: 'swipe',
          arguments: const <String, Object?>{'direction': 'up'},
        ),
      );
      expect(fakeRunner.executedCommands, isEmpty);
      expect(result.isError, isTrue);
      final json =
          jsonDecode((result.content.first as TextContent).text)
              as Map<String, Object?>;
      _expectEnvelopeKeys(json);
    });

    test('swipe handler returns error envelope on execute failure', () async {
      final fakeRunner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.failure(
          code: CoreErrorCode.interactionFailed,
          message: 'swipe failed',
        );
      final ctx = _registeredCtx(runner: fakeRunner);
      final result = await ctx.registrationFor('swipe')!.handler(
        CallToolRequest(
          name: 'swipe',
          arguments: const <String, Object?>{'direction': 'up'},
        ),
      );
      expect(result.isError, isTrue);
      final json =
          jsonDecode((result.content.first as TextContent).text)
              as Map<String, Object?>;
      _expectEnvelopeKeys(json);
    });
  });

  // =========================================================================
  // drag
  // =========================================================================
  group('interaction tools — drag', () {
    test('registers drag', () {
      final ctx = _registeredCtx();
      expect(ctx.registeredToolNames, contains('drag'));
    });

    test('drag schema: additionalProperties false, required [fromRef, toRef]',
        () {
      final ctx = _registeredCtx();
      final schema = ctx.registrationFor('drag')!.inputSchema;
      expect(schema['additionalProperties'], isFalse);
      final required = schema['required'] as List<Object?>;
      expect(required, containsAll(<String>['fromRef', 'toRef']));
      final props = schema['properties'] as Map<String, Object?>;
      expect(props.containsKey('fromRef'), isTrue);
      expect(props.containsKey('toRef'), isTrue);
      expect(props.containsKey('snapshotId'), isTrue);
      expect(props.containsKey('connection'), isTrue);
    });

    test('drag handler builds DragCommand with fromRef and toRef', () async {
      final fakeRunner = FakeCommandRunner();
      final ctx = _registeredCtx(runner: fakeRunner);
      await ctx.registrationFor('drag')!.handler(
        CallToolRequest(
          name: 'drag',
          arguments: const <String, Object?>{
            'fromRef': 's_1',
            'toRef': 's_2',
            'snapshotId': 9,
          },
        ),
      );
      final cmd = fakeRunner.executedCommands.first as DragCommand;
      expect(cmd.fromRef, equals('s_1'));
      expect(cmd.toRef, equals('s_2'));
      expect(cmd.snapshotId, equals(9));
    });

    test('drag handler short-circuits on override failure', () async {
      final fakeRunner = FakeCommandRunner()
        ..nextOverrideResult = CoreResult.failure(
          code: CoreErrorCode.connectFailed,
          message: 'no app',
        );
      final ctx = _registeredCtx(runner: fakeRunner);
      final result = await ctx.registrationFor('drag')!.handler(
        CallToolRequest(
          name: 'drag',
          arguments: const <String, Object?>{'fromRef': 's_1', 'toRef': 's_2'},
        ),
      );
      expect(fakeRunner.executedCommands, isEmpty);
      expect(result.isError, isTrue);
      final json =
          jsonDecode((result.content.first as TextContent).text)
              as Map<String, Object?>;
      _expectEnvelopeKeys(json);
    });

    test('drag handler returns error envelope on execute failure', () async {
      final fakeRunner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.failure(
          code: CoreErrorCode.interactionFailed,
          message: 'drag failed',
        );
      final ctx = _registeredCtx(runner: fakeRunner);
      final result = await ctx.registrationFor('drag')!.handler(
        CallToolRequest(
          name: 'drag',
          arguments: const <String, Object?>{'fromRef': 's_1', 'toRef': 's_2'},
        ),
      );
      expect(result.isError, isTrue);
      final json =
          jsonDecode((result.content.first as TextContent).text)
              as Map<String, Object?>;
      _expectEnvelopeKeys(json);
    });
  });

  // =========================================================================
  // hover
  // =========================================================================
  group('interaction tools — hover', () {
    test('registers hover', () {
      final ctx = _registeredCtx();
      expect(ctx.registeredToolNames, contains('hover'));
    });

    test('hover schema: additionalProperties false, required [ref]', () {
      final ctx = _registeredCtx();
      final schema = ctx.registrationFor('hover')!.inputSchema;
      expect(schema['additionalProperties'], isFalse);
      final required = schema['required'] as List<Object?>;
      expect(required, contains('ref'));
      final props = schema['properties'] as Map<String, Object?>;
      expect(props.containsKey('ref'), isTrue);
      expect(props.containsKey('snapshotId'), isTrue);
      expect(props.containsKey('connection'), isTrue);
    });

    test('hover handler builds HoverCommand', () async {
      final fakeRunner = FakeCommandRunner();
      final ctx = _registeredCtx(runner: fakeRunner);
      await ctx.registrationFor('hover')!.handler(
        CallToolRequest(
          name: 'hover',
          arguments: const <String, Object?>{'ref': 's_7', 'snapshotId': 4},
        ),
      );
      final cmd = fakeRunner.executedCommands.first as HoverCommand;
      expect(cmd.ref, equals('s_7'));
      expect(cmd.snapshotId, equals(4));
    });

    test('hover handler short-circuits on override failure', () async {
      final fakeRunner = FakeCommandRunner()
        ..nextOverrideResult = CoreResult.failure(
          code: CoreErrorCode.connectFailed,
          message: 'no app',
        );
      final ctx = _registeredCtx(runner: fakeRunner);
      final result = await ctx.registrationFor('hover')!.handler(
        CallToolRequest(
          name: 'hover',
          arguments: const <String, Object?>{'ref': 's_7'},
        ),
      );
      expect(fakeRunner.executedCommands, isEmpty);
      expect(result.isError, isTrue);
      final json =
          jsonDecode((result.content.first as TextContent).text)
              as Map<String, Object?>;
      _expectEnvelopeKeys(json);
    });

    test('hover handler returns error envelope on execute failure', () async {
      final fakeRunner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.failure(
          code: CoreErrorCode.interactionFailed,
          message: 'hover failed',
        );
      final ctx = _registeredCtx(runner: fakeRunner);
      final result = await ctx.registrationFor('hover')!.handler(
        CallToolRequest(
          name: 'hover',
          arguments: const <String, Object?>{'ref': 's_7'},
        ),
      );
      expect(result.isError, isTrue);
      final json =
          jsonDecode((result.content.first as TextContent).text)
              as Map<String, Object?>;
      _expectEnvelopeKeys(json);
    });
  });

  // =========================================================================
  // press_key
  // =========================================================================
  group('interaction tools — press_key', () {
    test('registers press_key', () {
      final ctx = _registeredCtx();
      expect(ctx.registeredToolNames, contains('press_key'));
    });

    test('press_key schema: additionalProperties false, required [key]', () {
      final ctx = _registeredCtx();
      final schema = ctx.registrationFor('press_key')!.inputSchema;
      expect(schema['additionalProperties'], isFalse);
      final required = schema['required'] as List<Object?>;
      expect(required, contains('key'));
      final props = schema['properties'] as Map<String, Object?>;
      expect(props.containsKey('key'), isTrue);
      expect(props.containsKey('ctrl'), isTrue);
      expect(props.containsKey('shift'), isTrue);
      expect(props.containsKey('alt'), isTrue);
      expect(props.containsKey('meta'), isTrue);
      expect(props.containsKey('connection'), isTrue);
      // press_key has no snapshotId — verify it is NOT there
      expect(props.containsKey('snapshotId'), isFalse);
    });

    test('press_key handler builds PressKeyCommand with all modifiers',
        () async {
      final fakeRunner = FakeCommandRunner();
      final ctx = _registeredCtx(runner: fakeRunner);
      await ctx.registrationFor('press_key')!.handler(
        CallToolRequest(
          name: 'press_key',
          arguments: const <String, Object?>{
            'key': 'Enter',
            'ctrl': true,
            'shift': false,
            'alt': true,
            'meta': false,
          },
        ),
      );
      final cmd = fakeRunner.executedCommands.first as PressKeyCommand;
      expect(cmd.key, equals('Enter'));
      expect(cmd.ctrl, isTrue);
      expect(cmd.shift, isFalse);
      expect(cmd.alt, isTrue);
      expect(cmd.meta, isFalse);
    });

    test('press_key handler defaults all modifiers to false when omitted',
        () async {
      final fakeRunner = FakeCommandRunner();
      final ctx = _registeredCtx(runner: fakeRunner);
      await ctx.registrationFor('press_key')!.handler(
        CallToolRequest(
          name: 'press_key',
          arguments: const <String, Object?>{'key': 'Escape'},
        ),
      );
      final cmd = fakeRunner.executedCommands.first as PressKeyCommand;
      expect(cmd.ctrl, isFalse);
      expect(cmd.shift, isFalse);
      expect(cmd.alt, isFalse);
      expect(cmd.meta, isFalse);
    });

    test('press_key handler short-circuits on override failure', () async {
      final fakeRunner = FakeCommandRunner()
        ..nextOverrideResult = CoreResult.failure(
          code: CoreErrorCode.connectFailed,
          message: 'no app',
        );
      final ctx = _registeredCtx(runner: fakeRunner);
      final result = await ctx.registrationFor('press_key')!.handler(
        CallToolRequest(
          name: 'press_key',
          arguments: const <String, Object?>{'key': 'Tab'},
        ),
      );
      expect(fakeRunner.executedCommands, isEmpty);
      expect(result.isError, isTrue);
      final json =
          jsonDecode((result.content.first as TextContent).text)
              as Map<String, Object?>;
      _expectEnvelopeKeys(json);
    });

    test('press_key handler returns error envelope on execute failure',
        () async {
      final fakeRunner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.failure(
          code: CoreErrorCode.interactionFailed,
          message: 'key not supported',
        );
      final ctx = _registeredCtx(runner: fakeRunner);
      final result = await ctx.registrationFor('press_key')!.handler(
        CallToolRequest(
          name: 'press_key',
          arguments: const <String, Object?>{'key': 'F13'},
        ),
      );
      expect(result.isError, isTrue);
      final json =
          jsonDecode((result.content.first as TextContent).text)
              as Map<String, Object?>;
      _expectEnvelopeKeys(json);
      expect(json['code'], equals(CoreErrorCode.interactionFailed));
    });
  });
}
