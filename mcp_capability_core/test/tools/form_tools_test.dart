// mcp_capability_core/test/tools/form_tools_test.dart
import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:mcp_capability_core/src/tools/form_tools.dart';
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';
import 'package:mcp_capability_kernel/testing.dart';
import 'package:mcp_shared_core/mcp_shared_core.dart';
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
  registerFormTools(ctx);
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
  // fill_form — registration & schema
  // =========================================================================
  group('form tools — fill_form registration', () {
    test('registers fill_form with the bare name (no prefix)', () {
      final ctx = _registeredCtx();
      expect(ctx.registeredToolNames, contains('fill_form'));
    });

    test('fill_form schema has type:object and additionalProperties:false', () {
      final ctx = _registeredCtx();
      final schema = ctx.registrationFor('fill_form')!.inputSchema;
      expect(schema['type'], equals('object'));
      expect(schema['additionalProperties'], isFalse);
    });

    test('fill_form schema has required: [fields]', () {
      final ctx = _registeredCtx();
      final required =
          ctx.registrationFor('fill_form')!.inputSchema['required']
              as List<Object?>;
      expect(required, contains('fields'));
      expect(required, isNot(contains('snapshotId')));
    });

    test('fill_form schema — fields is array type', () {
      final ctx = _registeredCtx();
      final props =
          ctx.registrationFor('fill_form')!.inputSchema['properties']
              as Map<String, Object?>;
      final fieldsSchema = props['fields'] as Map<String, Object?>;
      expect(fieldsSchema['type'], equals('array'));
    });

    test(
      'fill_form schema — fields items have additionalProperties:false and required [ref, text]',
      () {
        final ctx = _registeredCtx();
        final props =
            ctx.registrationFor('fill_form')!.inputSchema['properties']
                as Map<String, Object?>;
        final fieldsSchema = props['fields'] as Map<String, Object?>;
        final items = fieldsSchema['items'] as Map<String, Object?>;
        expect(items['type'], equals('object'));
        expect(items['additionalProperties'], isFalse);
        final required = items['required'] as List<Object?>;
        expect(required, containsAll(<String>['ref', 'text']));
        final itemProps = items['properties'] as Map<String, Object?>;
        expect(
          (itemProps['ref'] as Map<String, Object?>)['type'],
          equals('string'),
        );
        expect(
          (itemProps['text'] as Map<String, Object?>)['type'],
          equals('string'),
        );
      },
    );

    test('fill_form schema — snapshotId is integer', () {
      final ctx = _registeredCtx();
      final props =
          ctx.registrationFor('fill_form')!.inputSchema['properties']
              as Map<String, Object?>;
      final snapSchema = props['snapshotId'] as Map<String, Object?>;
      expect(snapSchema['type'], equals('integer'));
    });

    test('fill_form schema includes connection override property', () {
      final ctx = _registeredCtx();
      final props =
          ctx.registrationFor('fill_form')!.inputSchema['properties']
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
  // fill_form — handler: command construction
  // =========================================================================
  group('form tools — fill_form handler command construction', () {
    test(
      'handler builds FillFormCommand with fields list and snapshotId',
      () async {
        final fakeRunner = FakeCommandRunner();
        final ctx = _registeredCtx(runner: fakeRunner);
        await ctx
            .registrationFor('fill_form')!
            .handler(
              CallToolRequest(
                name: 'fill_form',
                arguments: <String, Object?>{
                  'fields': <Object?>[
                    {'ref': 'tf_0', 'text': 'Alice'},
                    {'ref': 'tf_1', 'text': 'alice@example.com'},
                  ],
                  'snapshotId': 7,
                },
              ),
            );
        expect(fakeRunner.executedCommands, hasLength(1));
        final cmd = fakeRunner.executedCommands.first as FillFormCommand;
        expect(cmd.fields, hasLength(2));
        expect(cmd.fields[0], equals({'ref': 'tf_0', 'text': 'Alice'}));
        expect(
          cmd.fields[1],
          equals({'ref': 'tf_1', 'text': 'alice@example.com'}),
        );
        expect(cmd.snapshotId, equals(7));
      },
    );

    test('handler passes snapshotId as null when not provided', () async {
      final fakeRunner = FakeCommandRunner();
      final ctx = _registeredCtx(runner: fakeRunner);
      await ctx
          .registrationFor('fill_form')!
          .handler(
            CallToolRequest(
              name: 'fill_form',
              arguments: <String, Object?>{
                'fields': <Object?>[
                  {'ref': 'tf_0', 'text': 'Bob'},
                ],
              },
            ),
          );
      final cmd = fakeRunner.executedCommands.first as FillFormCommand;
      expect(cmd.snapshotId, isNull);
    });

    test('handler treats snapshotId == 0 as absent (legacy parity)', () async {
      final fakeRunner = FakeCommandRunner();
      final ctx = _registeredCtx(runner: fakeRunner);
      await ctx
          .registrationFor('fill_form')!
          .handler(
            CallToolRequest(
              name: 'fill_form',
              arguments: <String, Object?>{
                'fields': <Object?>[
                  {'ref': 'tf_0', 'text': 'Bob'},
                ],
                'snapshotId': 0,
              },
            ),
          );
      final cmd = fakeRunner.executedCommands.first as FillFormCommand;
      expect(cmd.snapshotId, isNull);
    });

    test(
      'handler uses empty fields list when fields arg is not a List',
      () async {
        final fakeRunner = FakeCommandRunner();
        final ctx = _registeredCtx(runner: fakeRunner);
        // Schema validation would normally block this; handler must be defensive.
        await ctx
            .registrationFor('fill_form')!
            .handler(
              CallToolRequest(
                name: 'fill_form',
                arguments: <String, Object?>{'fields': 'not-a-list'},
              ),
            );
        final cmd = fakeRunner.executedCommands.first as FillFormCommand;
        expect(cmd.fields, isEmpty);
      },
    );

    test('handler calls applyConnectionOverride before execute', () async {
      final fakeRunner = FakeCommandRunner();
      final ctx = _registeredCtx(runner: fakeRunner);
      final args = <String, Object?>{
        'fields': <Object?>[
          {'ref': 'tf_0', 'text': 'X'},
        ],
        'connection': {'port': 9999},
      };
      await ctx
          .registrationFor('fill_form')!
          .handler(CallToolRequest(name: 'fill_form', arguments: args));
      expect(fakeRunner.overrideArguments, hasLength(1));
      expect(fakeRunner.overrideArguments.first, equals(args));
      expect(fakeRunner.executedCommands, hasLength(1));
    });
  });

  // =========================================================================
  // fill_form — handler: success and stop-on-failure paths
  // =========================================================================
  group('form tools — fill_form outcomes', () {
    test('success: all fields filled — non-error CallToolResult', () async {
      final fakeRunner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.success(
          data: <String, Object?>{
            'success': true,
            'fieldCount': 2,
            'results': <Object?>[
              {'ok': true},
              {'ok': true},
            ],
          },
        );
      final ctx = _registeredCtx(runner: fakeRunner);
      final result = await ctx
          .registrationFor('fill_form')!
          .handler(
            CallToolRequest(
              name: 'fill_form',
              arguments: <String, Object?>{
                'fields': <Object?>[
                  {'ref': 'tf_0', 'text': 'Alice'},
                  {'ref': 'tf_1', 'text': 'alice@example.com'},
                ],
              },
            ),
          );
      expect(result.isError, isNot(true));
      final text = (result.content.first as TextContent).text;
      final json = jsonDecode(text) as Map<String, Object?>;
      expect(json['success'], isTrue);
      expect(json['fieldCount'], equals(2));
    });

    test('stop-on-failure: error envelope with fillFormFailed code', () async {
      // The executor returns CoreResult.failure with details.failedAt when any
      // field fails. The capability layer must preserve the full envelope.
      final fakeRunner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.failure(
          code: CoreErrorCode.fillFormFailed,
          message: 'fill_form: field 1 (ref=tf_1) failed',
          details: <String, Object?>{
            'failedAt': 1,
            'failedRef': 'tf_1',
            'results': <Object?>[
              {'ok': true},
            ],
          },
        );
      final ctx = _registeredCtx(runner: fakeRunner);
      final result = await ctx
          .registrationFor('fill_form')!
          .handler(
            CallToolRequest(
              name: 'fill_form',
              arguments: <String, Object?>{
                'fields': <Object?>[
                  {'ref': 'tf_0', 'text': 'Alice'},
                  {'ref': 'tf_1', 'text': 'bad-ref'},
                ],
              },
            ),
          );
      expect(result.isError, isTrue);
      final text = (result.content.first as TextContent).text;
      final json = jsonDecode(text) as Map<String, Object?>;
      expect(json['code'], equals(CoreErrorCode.fillFormFailed));
      _expectEnvelopeKeys(json);
      // Envelope details are JSON-encoded inside the error envelope;
      // the top-level details key must be present (may be null for simple
      // failures — check envelope structure only).
      expect(json.containsKey('details'), isTrue);
    });

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
            .registrationFor('fill_form')!
            .handler(
              CallToolRequest(
                name: 'fill_form',
                arguments: <String, Object?>{
                  'fields': <Object?>[
                    {'ref': 'tf_0', 'text': 'X'},
                  ],
                  'connection': {'port': 9999},
                },
              ),
            );
        expect(fakeRunner.executedCommands, isEmpty);
        expect(result.isError, isTrue);
        final text = (result.content.first as TextContent).text;
        final json = jsonDecode(text) as Map<String, Object?>;
        expect(json['code'], equals(CoreErrorCode.connectFailed));
        _expectEnvelopeKeys(json);
      },
    );
  });
}
