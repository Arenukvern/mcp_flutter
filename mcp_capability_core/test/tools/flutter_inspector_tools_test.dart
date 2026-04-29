// mcp_capability_core/test/tools/flutter_inspector_tools_test.dart
import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:mcp_capability_core/src/tools/flutter_inspector_tools.dart';
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
  registerFlutterInspectorTools(ctx);
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

void _expectBaseSchema(
  final Map<String, Object?> schema, {
  final List<String> extraProps = const [],
}) {
  expect(schema['type'], 'object');
  expect(schema['additionalProperties'], isFalse);
  expect(schema.containsKey('required'), isFalse);
  final props = schema['properties'] as Map<String, Object?>;
  expect(props.containsKey('connection'), isTrue);
  for (final p in extraProps) {
    expect(props.containsKey(p), isTrue, reason: 'schema must have $p');
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // Registration
  // =========================================================================
  group('flutter_inspector_tools — registration', () {
    test('registers all 6 tools', () {
      final ctx = _registeredCtx();
      expect(
        ctx.registeredToolNames,
        containsAll(<String>[
          'hot_reload_flutter',
          'hot_restart_flutter',
          'connect_debug_app',
          'discover_debug_apps',
          'get_vm',
          'get_extension_rpcs',
        ]),
      );
    });
  });

  // =========================================================================
  // hot_restart_flutter
  // =========================================================================
  group('flutter_inspector_tools — hot_restart_flutter', () {
    test('schema: only connection; additionalProperties false', () {
      final ctx = _registeredCtx();
      _expectBaseSchema(
        ctx.registrationFor('hot_restart_flutter')!.inputSchema,
      );
    });

    test('handler executes HotRestartFlutterCommand', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.success(data: {'type': 'Restarted'});
      final ctx = _registeredCtx(runner: runner);
      final result = await ctx.registrationFor('hot_restart_flutter')!.handler(
        CallToolRequest(
          name: 'hot_restart_flutter',
          arguments: const <String, Object?>{},
        ),
      );
      expect(result.isError, isNot(true));
      expect(runner.executedCommands.single, isA<HotRestartFlutterCommand>());
    });

    test('handler short-circuits on override failure', () async {
      final runner = FakeCommandRunner()
        ..nextOverrideResult = CoreResult.failure(
          code: CoreErrorCode.connectFailed,
          message: 'no connection',
        );
      final ctx = _registeredCtx(runner: runner);
      final result = await ctx.registrationFor('hot_restart_flutter')!.handler(
        CallToolRequest(
          name: 'hot_restart_flutter',
          arguments: const <String, Object?>{},
        ),
      );
      expect(result.isError, isTrue);
      expect(runner.executedCommands, isEmpty);
    });

    test('returns 5-key error envelope on execute failure', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.failure(
          code: CoreErrorCode.hotRestartFailed,
          message: 'hot restart failed',
        );
      final ctx = _registeredCtx(runner: runner);
      final result = await ctx.registrationFor('hot_restart_flutter')!.handler(
        CallToolRequest(
          name: 'hot_restart_flutter',
          arguments: const <String, Object?>{},
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
  // hot_reload_flutter
  // =========================================================================
  group('flutter_inspector_tools — hot_reload_flutter', () {
    test('schema: has force and connection, additionalProperties false', () {
      final ctx = _registeredCtx();
      _expectBaseSchema(
        ctx.registrationFor('hot_reload_flutter')!.inputSchema,
        extraProps: ['force'],
      );
      final props =
          ctx.registrationFor('hot_reload_flutter')!.inputSchema['properties']
              as Map<String, Object?>;
      expect(
        (props['force'] as Map<String, Object?>)['type'],
        'boolean',
        reason: 'force must be boolean',
      );
    });

    test('handler executes HotReloadFlutterCommand with force=false by default',
        () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult =
            CoreResult.success(data: {'type': 'ReloadReport'});
      final ctx = _registeredCtx(runner: runner);
      await ctx.registrationFor('hot_reload_flutter')!.handler(
        CallToolRequest(
          name: 'hot_reload_flutter',
          arguments: const <String, Object?>{},
        ),
      );
      expect(runner.executedCommands.first, isA<HotReloadFlutterCommand>());
      final cmd = runner.executedCommands.first as HotReloadFlutterCommand;
      expect(cmd.force, isFalse);
    });

    test('handler passes force=true when provided', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult =
            CoreResult.success(data: {'type': 'ReloadReport'});
      final ctx = _registeredCtx(runner: runner);
      await ctx.registrationFor('hot_reload_flutter')!.handler(
        CallToolRequest(
          name: 'hot_reload_flutter',
          arguments: const <String, Object?>{'force': true},
        ),
      );
      final cmd = runner.executedCommands.first as HotReloadFlutterCommand;
      expect(cmd.force, isTrue);
    });

    test('success yields 2 TextContent items, first is "Hot reload completed"',
        () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult =
            CoreResult.success(data: {'type': 'ReloadReport'});
      final ctx = _registeredCtx(runner: runner);
      final result =
          await ctx.registrationFor('hot_reload_flutter')!.handler(
        CallToolRequest(
          name: 'hot_reload_flutter',
          arguments: const <String, Object?>{},
        ),
      );
      expect(result.isError, isNot(true));
      expect(result.content.length, 2);
      expect(
        (result.content.first as TextContent).text,
        'Hot reload completed',
      );
      final decoded =
          jsonDecode((result.content[1] as TextContent).text)
              as Map<String, Object?>;
      expect(decoded['type'], 'ReloadReport');
    });

    test('handler short-circuits on override failure', () async {
      final runner = FakeCommandRunner()
        ..nextOverrideResult = CoreResult.failure(
          code: CoreErrorCode.connectFailed,
          message: 'no connection',
        );
      final ctx = _registeredCtx(runner: runner);
      final result =
          await ctx.registrationFor('hot_reload_flutter')!.handler(
        CallToolRequest(
          name: 'hot_reload_flutter',
          arguments: const <String, Object?>{},
        ),
      );
      expect(result.isError, isTrue);
      expect(runner.executedCommands, isEmpty);
    });

    test('returns 5-key error envelope on execute failure', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.failure(
          code: CoreErrorCode.hotReloadFailed,
          message: 'hot reload failed',
        );
      final ctx = _registeredCtx(runner: runner);
      final result =
          await ctx.registrationFor('hot_reload_flutter')!.handler(
        CallToolRequest(
          name: 'hot_reload_flutter',
          arguments: const <String, Object?>{},
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
  // connect_debug_app
  // =========================================================================
  group('flutter_inspector_tools — connect_debug_app', () {
    test('schema: connection only, additionalProperties false, no required', () {
      final ctx = _registeredCtx();
      _expectBaseSchema(
        ctx.registrationFor('connect_debug_app')!.inputSchema,
      );
      // Only 'connection' in properties
      final props =
          ctx.registrationFor('connect_debug_app')!.inputSchema['properties']
              as Map<String, Object?>;
      expect(props.keys.toList(), ['connection']);
    });

    test(
        'handler dispatches ConnectCommand directly — no applyConnectionOverride call',
        () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult =
            CoreResult.success(data: {'connected': true});
      final ctx = _registeredCtx(runner: runner);
      await ctx.registrationFor('connect_debug_app')!.handler(
        CallToolRequest(
          name: 'connect_debug_app',
          arguments: const <String, Object?>{},
        ),
      );
      // Must have executed ConnectCommand but NOT called applyConnectionOverride
      expect(runner.executedCommands.first, isA<ConnectCommand>());
      expect(runner.callLog, equals(['execute']));
    });

    test('handler returns success data as JSON', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult =
            CoreResult.success(data: {'endpoint': 'ws://127.0.0.1:8181/ws'});
      final ctx = _registeredCtx(runner: runner);
      final result =
          await ctx.registrationFor('connect_debug_app')!.handler(
        CallToolRequest(
          name: 'connect_debug_app',
          arguments: const <String, Object?>{},
        ),
      );
      expect(result.isError, isNot(true));
      final decoded =
          jsonDecode((result.content.first as TextContent).text)
              as Map<String, Object?>;
      expect(decoded['endpoint'], 'ws://127.0.0.1:8181/ws');
    });

    test('returns 5-key error envelope on connect failure', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.failure(
          code: CoreErrorCode.connectFailed,
          message: 'connection failed',
        );
      final ctx = _registeredCtx(runner: runner);
      final result =
          await ctx.registrationFor('connect_debug_app')!.handler(
        CallToolRequest(
          name: 'connect_debug_app',
          arguments: const <String, Object?>{},
        ),
      );
      expect(result.isError, isTrue);
      final json =
          jsonDecode((result.content.first as TextContent).text)
              as Map<String, Object?>;
      _expectEnvelopeKeys(json);
    });

    test('returns error on malformed connection argument', () async {
      final runner = FakeCommandRunner();
      final ctx = _registeredCtx(runner: runner);
      final result =
          await ctx.registrationFor('connect_debug_app')!.handler(
        CallToolRequest(
          name: 'connect_debug_app',
          arguments: const <String, Object?>{'connection': 'not-an-object'},
        ),
      );
      expect(result.isError, isTrue);
      // No execute call — parse error short-circuits
      expect(runner.executedCommands, isEmpty);
    });
  });

  // =========================================================================
  // discover_debug_apps
  // =========================================================================
  group('flutter_inspector_tools — discover_debug_apps', () {
    test('schema: connection only, additionalProperties false, no required', () {
      final ctx = _registeredCtx();
      _expectBaseSchema(
        ctx.registrationFor('discover_debug_apps')!.inputSchema,
      );
    });

    test('handler dispatches DiscoverDebugAppsCommand — no override call', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.success(
          data: {'targets': [], 'count': 0},
        );
      final ctx = _registeredCtx(runner: runner);
      await ctx.registrationFor('discover_debug_apps')!.handler(
        CallToolRequest(
          name: 'discover_debug_apps',
          arguments: const <String, Object?>{},
        ),
      );
      expect(runner.executedCommands.first, isA<DiscoverDebugAppsCommand>());
      expect(runner.callLog, equals(['execute']));
    });

    test('handler returns success data as JSON', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.success(
          data: {'targets': [], 'count': 0, 'ports': []},
        );
      final ctx = _registeredCtx(runner: runner);
      final result =
          await ctx.registrationFor('discover_debug_apps')!.handler(
        CallToolRequest(
          name: 'discover_debug_apps',
          arguments: const <String, Object?>{},
        ),
      );
      expect(result.isError, isNot(true));
      final decoded =
          jsonDecode((result.content.first as TextContent).text)
              as Map<String, Object?>;
      expect(decoded['count'], 0);
    });

    test('returns 5-key error envelope on execute failure', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.failure(
          code: CoreErrorCode.discoverDebugAppsFailed,
          message: 'discovery failed',
        );
      final ctx = _registeredCtx(runner: runner);
      final result =
          await ctx.registrationFor('discover_debug_apps')!.handler(
        CallToolRequest(
          name: 'discover_debug_apps',
          arguments: const <String, Object?>{},
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
  // get_vm
  // =========================================================================
  group('flutter_inspector_tools — get_vm', () {
    test('schema: connection only, additionalProperties false, no required', () {
      final ctx = _registeredCtx();
      _expectBaseSchema(ctx.registrationFor('get_vm')!.inputSchema);
    });

    test('handler executes GetVmCommand', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult =
            CoreResult.success(data: {'type': 'VM', 'version': '3.x'});
      final ctx = _registeredCtx(runner: runner);
      await ctx.registrationFor('get_vm')!.handler(
        CallToolRequest(name: 'get_vm', arguments: const <String, Object?>{}),
      );
      expect(runner.executedCommands.first, isA<GetVmCommand>());
    });

    test('handler short-circuits on override failure', () async {
      final runner = FakeCommandRunner()
        ..nextOverrideResult = CoreResult.failure(
          code: CoreErrorCode.connectFailed,
          message: 'no connection',
        );
      final ctx = _registeredCtx(runner: runner);
      final result = await ctx.registrationFor('get_vm')!.handler(
        CallToolRequest(name: 'get_vm', arguments: const <String, Object?>{}),
      );
      expect(result.isError, isTrue);
      expect(runner.executedCommands, isEmpty);
    });

    test('handler returns success data as JSON', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult =
            CoreResult.success(data: {'type': 'VM', 'pid': 42});
      final ctx = _registeredCtx(runner: runner);
      final result = await ctx.registrationFor('get_vm')!.handler(
        CallToolRequest(name: 'get_vm', arguments: const <String, Object?>{}),
      );
      expect(result.isError, isNot(true));
      final decoded =
          jsonDecode((result.content.first as TextContent).text)
              as Map<String, Object?>;
      expect(decoded['pid'], 42);
    });

    test('returns 5-key error envelope on execute failure', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.failure(
          code: CoreErrorCode.getVmFailed,
          message: 'get_vm failed',
        );
      final ctx = _registeredCtx(runner: runner);
      final result = await ctx.registrationFor('get_vm')!.handler(
        CallToolRequest(name: 'get_vm', arguments: const <String, Object?>{}),
      );
      expect(result.isError, isTrue);
      final json =
          jsonDecode((result.content.first as TextContent).text)
              as Map<String, Object?>;
      _expectEnvelopeKeys(json);
    });
  });

  // =========================================================================
  // get_extension_rpcs
  // =========================================================================
  group('flutter_inspector_tools — get_extension_rpcs', () {
    test(
        'schema: isolateId, isRawResponse, connection present; additionalProperties false',
        () {
      final ctx = _registeredCtx();
      _expectBaseSchema(
        ctx.registrationFor('get_extension_rpcs')!.inputSchema,
        extraProps: ['isolateId', 'isRawResponse'],
      );
      final props =
          ctx.registrationFor('get_extension_rpcs')!.inputSchema['properties']
              as Map<String, Object?>;
      expect(
        (props['isolateId'] as Map<String, Object?>)['type'],
        'string',
      );
      expect(
        (props['isRawResponse'] as Map<String, Object?>)['type'],
        'boolean',
      );
    });

    test('handler executes GetExtensionRpcsCommand', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult =
            CoreResult.success(data: ['ext.flutter.inspector']);
      final ctx = _registeredCtx(runner: runner);
      await ctx.registrationFor('get_extension_rpcs')!.handler(
        CallToolRequest(
          name: 'get_extension_rpcs',
          arguments: const <String, Object?>{},
        ),
      );
      expect(runner.executedCommands.first, isA<GetExtensionRpcsCommand>());
    });

    test('handler short-circuits on override failure', () async {
      final runner = FakeCommandRunner()
        ..nextOverrideResult = CoreResult.failure(
          code: CoreErrorCode.connectFailed,
          message: 'no connection',
        );
      final ctx = _registeredCtx(runner: runner);
      final result =
          await ctx.registrationFor('get_extension_rpcs')!.handler(
        CallToolRequest(
          name: 'get_extension_rpcs',
          arguments: const <String, Object?>{},
        ),
      );
      expect(result.isError, isTrue);
      expect(runner.executedCommands, isEmpty);
    });

    test('handler ignores vestigial isolateId / isRawResponse args', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult =
            CoreResult.success(data: ['ext.flutter.inspector']);
      final ctx = _registeredCtx(runner: runner);
      // Passing isolateId and isRawResponse: they must be accepted (no error)
      // and the executor receives GetExtensionRpcsCommand (ignores the args).
      final result =
          await ctx.registrationFor('get_extension_rpcs')!.handler(
        CallToolRequest(
          name: 'get_extension_rpcs',
          arguments: const <String, Object?>{
            'isolateId': 'isolates/1',
            'isRawResponse': true,
          },
        ),
      );
      expect(result.isError, isNot(true));
      expect(runner.executedCommands.first, isA<GetExtensionRpcsCommand>());
    });

    test('returns 5-key error envelope on execute failure', () async {
      final runner = FakeCommandRunner()
        ..nextExecuteResult = CoreResult.failure(
          code: CoreErrorCode.getExtensionRpcsFailed,
          message: 'get_extension_rpcs failed',
        );
      final ctx = _registeredCtx(runner: runner);
      final result =
          await ctx.registrationFor('get_extension_rpcs')!.handler(
        CallToolRequest(
          name: 'get_extension_rpcs',
          arguments: const <String, Object?>{},
        ),
      );
      expect(result.isError, isTrue);
      final json =
          jsonDecode((result.content.first as TextContent).text)
              as Map<String, Object?>;
      _expectEnvelopeKeys(json);
    });
  });
}
