// flutter_mcp_toolkit_capability_core/test/tools/inspection_tools_test.dart
import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_capability_core/src/tools/inspection_tools.dart';
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
  registerInspectionTools(ctx);
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
  // get_view_details
  // =========================================================================
  group('inspection tools — get_view_details', () {
    test('registers get_view_details', () {
      final ctx = _registeredCtx();
      expect(ctx.registeredToolNames, contains('get_view_details'));
    });

    test(
      'get_view_details schema: additionalProperties false, no required',
      () {
        final ctx = _registeredCtx();
        final schema = ctx.registrationFor('get_view_details')!.inputSchema;
        expect(schema['type'], 'object');
        expect(schema['additionalProperties'], isFalse);
        expect(schema.containsKey('required'), isFalse);
        final props = schema['properties'] as Map<String, Object?>;
        expect(props.containsKey('connection'), isTrue);
      },
    );

    test('get_view_details handler delegates GetViewDetailsCommand', () async {
      final viewData = <String, Object?>{'views': []};
      final runner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.success(data: viewData);
      final ctx = _registeredCtx(runner: runner);
      final reg = ctx.registrationFor('get_view_details')!;
      final result = await reg.handler(
        CallToolRequest(
          name: 'get_view_details',
          arguments: const <String, Object?>{},
        ),
      );
      expect(result.isError, isNot(true));
      expect(runner.executedCommands.first, isA<GetViewDetailsCommand>());
    });

    test(
      'get_view_details handler short-circuits on override failure',
      () async {
        final runner = FakeCommandRunner()
          ..nextOverrideResult = CoreResult.failure(
            code: CoreErrorCode.connectFailed,
            message: 'no connection',
          );
        final ctx = _registeredCtx(runner: runner);
        final reg = ctx.registrationFor('get_view_details')!;
        final result = await reg.handler(
          CallToolRequest(
            name: 'get_view_details',
            arguments: const <String, Object?>{},
          ),
        );
        expect(result.isError, isTrue);
        expect(runner.executedCommands, isEmpty);
      },
    );

    test(
      'get_view_details handler returns 5-key error envelope on execute failure',
      () async {
        final runner = FakeCommandRunner()
          ..nextExecuteResult = CoreResult.failure(
            code: CoreErrorCode.getViewDetailsFailed,
            message: 'view details failed',
          );
        final ctx = _registeredCtx(runner: runner);
        final reg = ctx.registrationFor('get_view_details')!;
        final result = await reg.handler(
          CallToolRequest(
            name: 'get_view_details',
            arguments: const <String, Object?>{},
          ),
        );
        expect(result.isError, isTrue);
        final text = (result.content.first as TextContent).text;
        final json = jsonDecode(text) as Map<String, Object?>;
        _expectEnvelopeKeys(json);
      },
    );
  });

  // =========================================================================
  // inspect_widget_at_point
  // =========================================================================
  group('inspection tools — inspect_widget_at_point', () {
    test('registers inspect_widget_at_point', () {
      final ctx = _registeredCtx();
      expect(ctx.registeredToolNames, contains('inspect_widget_at_point'));
    });

    test(
      'inspect_widget_at_point schema: required [x, y], x/y/viewId integer',
      () {
        final ctx = _registeredCtx();
        final schema = ctx
            .registrationFor('inspect_widget_at_point')!
            .inputSchema;
        expect(schema['type'], 'object');
        expect(schema['additionalProperties'], isFalse);
        final required = schema['required'] as List;
        expect(required, containsAll(<String>['x', 'y']));
        final props = schema['properties'] as Map<String, Object?>;
        expect((props['x']! as Map<String, Object?>)['type'], 'integer');
        expect((props['y']! as Map<String, Object?>)['type'], 'integer');
        expect((props['viewId']! as Map<String, Object?>)['type'], 'integer');
        expect(props.containsKey('connection'), isTrue);
      },
    );

    test(
      'inspect_widget_at_point handler builds InspectWidgetAtPointCommand',
      () async {
        final runner = FakeCommandRunner()
          ..nextExecuteResult = CoreResult.success(data: {'widget': 'Text'});
        final ctx = _registeredCtx(runner: runner);
        final reg = ctx.registrationFor('inspect_widget_at_point')!;
        await reg.handler(
          CallToolRequest(
            name: 'inspect_widget_at_point',
            arguments: const <String, Object?>{'x': 100, 'y': 200, 'viewId': 1},
          ),
        );
        final cmd =
            runner.executedCommands.first as InspectWidgetAtPointCommand;
        expect(cmd.x, 100);
        expect(cmd.y, 200);
        expect(cmd.viewId, 1);
      },
    );

    test('inspect_widget_at_point viewId is null when not provided', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.success(data: {});
      final ctx = _registeredCtx(runner: runner);
      final reg = ctx.registrationFor('inspect_widget_at_point')!;
      await reg.handler(
        CallToolRequest(
          name: 'inspect_widget_at_point',
          arguments: const <String, Object?>{'x': 50, 'y': 75},
        ),
      );
      final cmd = runner.executedCommands.first as InspectWidgetAtPointCommand;
      expect(cmd.viewId, isNull);
    });

    test(
      'inspect_widget_at_point handler short-circuits on override failure',
      () async {
        final runner = FakeCommandRunner()
          ..nextOverrideResult = CoreResult.failure(
            code: CoreErrorCode.connectFailed,
            message: 'no connection',
          );
        final ctx = _registeredCtx(runner: runner);
        final reg = ctx.registrationFor('inspect_widget_at_point')!;
        final result = await reg.handler(
          CallToolRequest(
            name: 'inspect_widget_at_point',
            arguments: const <String, Object?>{'x': 0, 'y': 0},
          ),
        );
        expect(result.isError, isTrue);
        expect(runner.executedCommands, isEmpty);
      },
    );

    test(
      'inspect_widget_at_point handler returns 5-key error envelope on execute failure',
      () async {
        final runner = FakeCommandRunner()
          ..nextExecuteResult = CoreResult.failure(
            code: CoreErrorCode.interactionFailed,
            message: 'inspect failed',
          );
        final ctx = _registeredCtx(runner: runner);
        final reg = ctx.registrationFor('inspect_widget_at_point')!;
        final result = await reg.handler(
          CallToolRequest(
            name: 'inspect_widget_at_point',
            arguments: const <String, Object?>{'x': 0, 'y': 0},
          ),
        );
        expect(result.isError, isTrue);
        final text = (result.content.first as TextContent).text;
        final json = jsonDecode(text) as Map<String, Object?>;
        _expectEnvelopeKeys(json);
      },
    );
  });

  // =========================================================================
  // get_app_errors
  // =========================================================================
  group('inspection tools — get_app_errors', () {
    test('registers get_app_errors', () {
      final ctx = _registeredCtx();
      expect(ctx.registeredToolNames, contains('get_app_errors'));
    });

    test(
      'get_app_errors schema: additionalProperties false, count integer, no required',
      () {
        final ctx = _registeredCtx();
        final schema = ctx.registrationFor('get_app_errors')!.inputSchema;
        expect(schema['type'], 'object');
        expect(schema['additionalProperties'], isFalse);
        expect(schema.containsKey('required'), isFalse);
        final props = schema['properties'] as Map<String, Object?>;
        expect((props['count']! as Map<String, Object?>)['type'], 'integer');
        expect(props.containsKey('connection'), isTrue);
      },
    );

    test('get_app_errors count defaults to 4 when not provided', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.success(
          data: {'message': 'No errors found', 'errors': []},
        );
      final ctx = _registeredCtx(runner: runner);
      final reg = ctx.registrationFor('get_app_errors')!;
      await reg.handler(
        CallToolRequest(
          name: 'get_app_errors',
          arguments: const <String, Object?>{},
        ),
      );
      final cmd = runner.executedCommands.first as GetAppErrorsCommand;
      expect(cmd.count, 4);
    });

    test(
      'get_app_errors handler fans out message + per-error TextContent',
      () async {
        final runner = FakeCommandRunner()
          ..nextExecuteResult = CoreResult.success(
            data: {
              'message': '2 errors',
              'errors': [
                {'type': 'StateError', 'message': 'bad state'},
                {'type': 'TypeError', 'message': 'type mismatch'},
              ],
            },
          );
        final ctx = _registeredCtx(runner: runner);
        final reg = ctx.registrationFor('get_app_errors')!;
        final result = await reg.handler(
          CallToolRequest(
            name: 'get_app_errors',
            arguments: const <String, Object?>{'count': 4},
          ),
        );
        expect(result.isError, isNot(true));
        // message + 2 errors = 3 content items
        expect(result.content, hasLength(3));
        expect((result.content[0] as TextContent).text, '2 errors');
        final error1 =
            jsonDecode((result.content[1] as TextContent).text) as Map;
        expect(error1['type'], 'StateError');
        final error2 =
            jsonDecode((result.content[2] as TextContent).text) as Map;
        expect(error2['type'], 'TypeError');
      },
    );

    test(
      'get_app_errors with no errors returns single message content',
      () async {
        final runner = FakeCommandRunner()
          ..nextExecuteResult = CoreResult.success(
            data: {'message': 'No errors found', 'errors': []},
          );
        final ctx = _registeredCtx(runner: runner);
        final reg = ctx.registrationFor('get_app_errors')!;
        final result = await reg.handler(
          CallToolRequest(
            name: 'get_app_errors',
            arguments: const <String, Object?>{},
          ),
        );
        expect(result.isError, isNot(true));
        expect(result.content, hasLength(1));
        expect((result.content[0] as TextContent).text, 'No errors found');
      },
    );

    test('get_app_errors handler short-circuits on override failure', () async {
      final runner = FakeCommandRunner()
        ..nextOverrideResult = CoreResult.failure(
          code: CoreErrorCode.connectFailed,
          message: 'no connection',
        );
      final ctx = _registeredCtx(runner: runner);
      final reg = ctx.registrationFor('get_app_errors')!;
      final result = await reg.handler(
        CallToolRequest(
          name: 'get_app_errors',
          arguments: const <String, Object?>{},
        ),
      );
      expect(result.isError, isTrue);
      expect(runner.executedCommands, isEmpty);
    });

    test(
      'get_app_errors handler returns 5-key error envelope on execute failure',
      () async {
        final runner = FakeCommandRunner()
          ..nextExecuteResult = CoreResult.failure(
            code: CoreErrorCode.getAppErrorsFailed,
            message: 'errors fetch failed',
          );
        final ctx = _registeredCtx(runner: runner);
        final reg = ctx.registrationFor('get_app_errors')!;
        final result = await reg.handler(
          CallToolRequest(
            name: 'get_app_errors',
            arguments: const <String, Object?>{},
          ),
        );
        expect(result.isError, isTrue);
        final text = (result.content.first as TextContent).text;
        final json = jsonDecode(text) as Map<String, Object?>;
        _expectEnvelopeKeys(json);
      },
    );
  });

  // =========================================================================
  // get_screenshots
  // =========================================================================
  group('inspection tools — get_screenshots', () {
    test('registers get_screenshots', () {
      final ctx = _registeredCtx();
      expect(ctx.registeredToolNames, contains('get_screenshots'));
    });

    test(
      'get_screenshots schema: additionalProperties false, no required, '
      'compress boolean, mode/permissionPolicy string, connection present',
      () {
        final ctx = _registeredCtx();
        final schema = ctx.registrationFor('get_screenshots')!.inputSchema;
        expect(schema['type'], 'object');
        expect(schema['additionalProperties'], isFalse);
        expect(schema.containsKey('required'), isFalse);
        final props = schema['properties'] as Map<String, Object?>;
        expect((props['compress']! as Map<String, Object?>)['type'], 'boolean');
        expect((props['mode']! as Map<String, Object?>)['type'], 'string');
        expect(
          (props['permissionPolicy']! as Map<String, Object?>)['type'],
          'string',
        );
        expect(props.containsKey('connection'), isTrue);
        // No enum constraints — match legacy schema exactly.
        expect(
          (props['mode']! as Map<String, Object?>).containsKey('enum'),
          isFalse,
        );
      },
    );

    test(
      'get_screenshots handler builds GetScreenshotsCommand from args',
      () async {
        final runner = FakeCommandRunner()
          ..nextExecuteResult = CoreResult.success(
            data: {'images': <String>[], 'fileUrls': <String>[]},
          );
        final ctx = _registeredCtx(runner: runner);
        final reg = ctx.registrationFor('get_screenshots')!;
        await reg.handler(
          CallToolRequest(
            name: 'get_screenshots',
            arguments: const <String, Object?>{
              'compress': false,
              'mode': 'flutter_layer',
              'permissionPolicy': 'auto_request_once',
            },
          ),
        );
        final cmd = runner.executedCommands.first as GetScreenshotsCommand;
        expect(cmd.compress, isFalse);
        expect(cmd.mode, ScreenshotMode.flutterLayer);
        expect(cmd.permissionPolicy, PermissionPolicy.autoRequestOnce);
      },
    );

    test(
      'get_screenshots onSuccess: fileUrls branch returns TextContent + meta',
      () async {
        final runner = FakeCommandRunner()
          ..nextExecuteResult = CoreResult.success(
            data: {
              'fileUrls': [
                'file:///tmp/screen0.png',
                'file:///tmp/screen1.png',
              ],
              'images': <String>[],
            },
          );
        final ctx = _registeredCtx(runner: runner);
        final reg = ctx.registrationFor('get_screenshots')!;
        final result = await reg.handler(
          CallToolRequest(
            name: 'get_screenshots',
            arguments: const <String, Object?>{},
          ),
        );
        expect(result.isError, isNot(true));
        expect(result.content, hasLength(2));
        expect(
          (result.content[0] as TextContent).text,
          contains('file:///tmp/screen0.png'),
        );
        expect(
          (result.content[1] as TextContent).text,
          contains('file:///tmp/screen1.png'),
        );
        // meta must carry the fileUrls list
        expect(result.meta, isNotNull);
      },
    );

    test(
      'get_screenshots onSuccess: images branch returns ImageContent blocks',
      () async {
        final runner = FakeCommandRunner()
          ..nextExecuteResult = CoreResult.success(
            data: {
              'fileUrls': <String>[],
              'images': ['base64dataA', 'base64dataB'],
            },
          );
        final ctx = _registeredCtx(runner: runner);
        final reg = ctx.registrationFor('get_screenshots')!;
        final result = await reg.handler(
          CallToolRequest(
            name: 'get_screenshots',
            arguments: const <String, Object?>{},
          ),
        );
        expect(result.isError, isNot(true));
        expect(result.content, hasLength(2));
        expect(result.content[0], isA<ImageContent>());
        expect((result.content[0] as ImageContent).data, 'base64dataA');
        expect((result.content[0] as ImageContent).mimeType, 'image/png');
        expect(result.content[1], isA<ImageContent>());
        expect((result.content[1] as ImageContent).data, 'base64dataB');
      },
    );

    test(
      'get_screenshots handler short-circuits on override failure',
      () async {
        final runner = FakeCommandRunner()
          ..nextOverrideResult = CoreResult.failure(
            code: CoreErrorCode.connectFailed,
            message: 'no connection',
          );
        final ctx = _registeredCtx(runner: runner);
        final reg = ctx.registrationFor('get_screenshots')!;
        final result = await reg.handler(
          CallToolRequest(
            name: 'get_screenshots',
            arguments: const <String, Object?>{},
          ),
        );
        expect(result.isError, isTrue);
        expect(runner.executedCommands, isEmpty);
      },
    );

    test(
      'get_screenshots handler returns 5-key error envelope on execute failure',
      () async {
        final runner = FakeCommandRunner()
          ..nextExecuteResult = CoreResult.failure(
            code: CoreErrorCode.getViewDetailsFailed,
            message: 'screenshots failed',
          );
        final ctx = _registeredCtx(runner: runner);
        final reg = ctx.registrationFor('get_screenshots')!;
        final result = await reg.handler(
          CallToolRequest(
            name: 'get_screenshots',
            arguments: const <String, Object?>{},
          ),
        );
        expect(result.isError, isTrue);
        final text = (result.content.first as TextContent).text;
        final json = jsonDecode(text) as Map<String, Object?>;
        _expectEnvelopeKeys(json);
      },
    );
  });

  // =========================================================================
  // capture_ui_snapshot
  // =========================================================================
  group('inspection tools — capture_ui_snapshot', () {
    test('registers capture_ui_snapshot', () {
      final ctx = _registeredCtx();
      expect(ctx.registeredToolNames, contains('capture_ui_snapshot'));
    });

    test('capture_ui_snapshot schema: additionalProperties false, no required, '
        'errorsCount integer, compress/includeViewDetails/includeErrors boolean, '
        'screenshotMode/permissionPolicy string, connection present', () {
      final ctx = _registeredCtx();
      final schema = ctx.registrationFor('capture_ui_snapshot')!.inputSchema;
      expect(schema['type'], 'object');
      expect(schema['additionalProperties'], isFalse);
      expect(schema.containsKey('required'), isFalse);
      final props = schema['properties'] as Map<String, Object?>;
      expect(
        (props['errorsCount']! as Map<String, Object?>)['type'],
        'integer',
      );
      expect((props['compress']! as Map<String, Object?>)['type'], 'boolean');
      expect(
        (props['includeViewDetails']! as Map<String, Object?>)['type'],
        'boolean',
      );
      expect(
        (props['includeErrors']! as Map<String, Object?>)['type'],
        'boolean',
      );
      expect(
        (props['screenshotMode']! as Map<String, Object?>)['type'],
        'string',
      );
      expect(
        (props['permissionPolicy']! as Map<String, Object?>)['type'],
        'string',
      );
      expect(props.containsKey('connection'), isTrue);
      // No enum constraints — match legacy.
      expect(
        (props['screenshotMode']! as Map<String, Object?>).containsKey('enum'),
        isFalse,
      );
    });

    test(
      'capture_ui_snapshot handler builds CaptureUiSnapshotCommand from args',
      () async {
        final runner = FakeCommandRunner()
          ..nextExecuteResult = CoreResult.success(data: {'ok': true});
        final ctx = _registeredCtx(runner: runner);
        final reg = ctx.registrationFor('capture_ui_snapshot')!;
        await reg.handler(
          CallToolRequest(
            name: 'capture_ui_snapshot',
            arguments: const <String, Object?>{
              'errorsCount': 8,
              'compress': false,
              'includeViewDetails': false,
              'includeErrors': false,
              'screenshotMode': 'desktop_window',
              'permissionPolicy': 'request_always',
            },
          ),
        );
        final cmd = runner.executedCommands.first as CaptureUiSnapshotCommand;
        expect(cmd.errorsCount, 8);
        expect(cmd.compress, isFalse);
        expect(cmd.includeViewDetails, isFalse);
        expect(cmd.includeErrors, isFalse);
        expect(cmd.screenshotMode, ScreenshotMode.desktopWindow);
        expect(cmd.permissionPolicy, PermissionPolicy.requestAlways);
      },
    );

    test('capture_ui_snapshot defaults: errorsCount=4, compress=true, '
        'includeViewDetails=true, includeErrors=true', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.success(data: {'ok': true});
      final ctx = _registeredCtx(runner: runner);
      final reg = ctx.registrationFor('capture_ui_snapshot')!;
      await reg.handler(
        CallToolRequest(
          name: 'capture_ui_snapshot',
          arguments: const <String, Object?>{},
        ),
      );
      final cmd = runner.executedCommands.first as CaptureUiSnapshotCommand;
      expect(cmd.errorsCount, 4);
      expect(cmd.compress, isTrue);
      expect(cmd.includeViewDetails, isTrue);
      expect(cmd.includeErrors, isTrue);
    });

    test(
      'capture_ui_snapshot success returns single TextContent with JSON',
      () async {
        final payload = <String, Object?>{
          'screenshots': ['base64...'],
          'errors': [],
        };
        final runner = FakeCommandRunner()
          ..nextExecuteResult = CoreResult.success(data: payload);
        final ctx = _registeredCtx(runner: runner);
        final reg = ctx.registrationFor('capture_ui_snapshot')!;
        final result = await reg.handler(
          CallToolRequest(
            name: 'capture_ui_snapshot',
            arguments: const <String, Object?>{},
          ),
        );
        expect(result.isError, isNot(true));
        expect(result.content, hasLength(1));
        final text = (result.content.first as TextContent).text;
        final decoded = jsonDecode(text) as Map<String, Object?>;
        expect(decoded.containsKey('screenshots'), isTrue);
      },
    );

    test(
      'capture_ui_snapshot handler short-circuits on override failure',
      () async {
        final runner = FakeCommandRunner()
          ..nextOverrideResult = CoreResult.failure(
            code: CoreErrorCode.connectFailed,
            message: 'no connection',
          );
        final ctx = _registeredCtx(runner: runner);
        final reg = ctx.registrationFor('capture_ui_snapshot')!;
        final result = await reg.handler(
          CallToolRequest(
            name: 'capture_ui_snapshot',
            arguments: const <String, Object?>{},
          ),
        );
        expect(result.isError, isTrue);
        expect(runner.executedCommands, isEmpty);
      },
    );

    test(
      'capture_ui_snapshot handler returns 5-key error envelope on execute failure',
      () async {
        final runner = FakeCommandRunner()
          ..nextExecuteResult = CoreResult.failure(
            code: CoreErrorCode.getViewDetailsFailed,
            message: 'snapshot failed',
          );
        final ctx = _registeredCtx(runner: runner);
        final reg = ctx.registrationFor('capture_ui_snapshot')!;
        final result = await reg.handler(
          CallToolRequest(
            name: 'capture_ui_snapshot',
            arguments: const <String, Object?>{},
          ),
        );
        expect(result.isError, isTrue);
        final text = (result.content.first as TextContent).text;
        final json = jsonDecode(text) as Map<String, Object?>;
        _expectEnvelopeKeys(json);
      },
    );
  });
}
