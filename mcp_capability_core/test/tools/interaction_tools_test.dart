// mcp_capability_core/test/tools/interaction_tools_test.dart
import 'package:dart_mcp/server.dart';
import 'package:mcp_capability_core/src/tools/interaction_tools.dart';
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';
import 'package:test/test.dart';

import '../_test_helpers.dart';

final class _FakeVmServiceClient implements VmServiceClient {
  _FakeVmServiceClient({this.response});

  final Map<String, Object?>? response;
  String? lastMethod;
  Map<String, Object?>? lastArgs;

  @override
  Future<Map<String, Object?>> callServiceExtension(
    final String method, {
    final Map<String, Object?>? args,
  }) async {
    lastMethod = method;
    lastArgs = args;
    return response ?? const <String, Object?>{};
  }
}

void main() {
  group('interaction tools — tap_widget', () {
    test('registers tap_widget with the bare name (no prefix)', () {
      final ctx = FakeCapabilityContext(
        capabilityId: 'core',
        services: <Type, HostService>{
          VmServiceClient: _FakeVmServiceClient(),
        },
      );
      registerInteractionTools(ctx);
      expect(
        ctx.registeredToolNames,
        contains('tap_widget'),
        reason:
            'capability registers BARE name; kernel/host applies prefix '
            'only at the host boundary',
      );
    });

    test('tap_widget input schema has correct type and required fields', () {
      final ctx = FakeCapabilityContext(
        capabilityId: 'core',
        services: <Type, HostService>{
          VmServiceClient: _FakeVmServiceClient(),
        },
      );
      registerInteractionTools(ctx);
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

    test('tap_widget handler delegates to VM service extension', () async {
      final fakeVm = _FakeVmServiceClient(
        response: const <String, Object?>{'success': true},
      );
      final ctx = FakeCapabilityContext(
        capabilityId: 'core',
        services: <Type, HostService>{
          VmServiceClient: fakeVm,
        },
      );
      registerInteractionTools(ctx);
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
      expect(fakeVm.lastMethod, equals('ext.mcp.toolkit.tap_widget'));
      expect(fakeVm.lastArgs?['ref'], equals('s_0'));
      expect(fakeVm.lastArgs?['snapshotId'], equals(42));
      expect(result, isA<CallToolResult>());
    });

    test('tap_widget handler omits snapshotId when not provided', () async {
      final fakeVm = _FakeVmServiceClient(
        response: const <String, Object?>{'success': true},
      );
      final ctx = FakeCapabilityContext(
        capabilityId: 'core',
        services: <Type, HostService>{
          VmServiceClient: fakeVm,
        },
      );
      registerInteractionTools(ctx);
      final reg = ctx.registrationFor('tap_widget')!;
      await reg.handler(
        CallToolRequest(
          name: 'tap_widget',
          arguments: const <String, Object?>{'ref': 'btn-submit'},
        ),
      );
      expect(fakeVm.lastArgs, isNotNull);
      expect(fakeVm.lastArgs!.containsKey('snapshotId'), isFalse);
    });

    test('tap_widget handler treats snapshotId == 0 as absent (legacy parity)',
        () async {
      final fakeVm = _FakeVmServiceClient(
        response: const <String, Object?>{'success': true},
      );
      final ctx = FakeCapabilityContext(
        capabilityId: 'core',
        services: <Type, HostService>{
          VmServiceClient: fakeVm,
        },
      );
      registerInteractionTools(ctx);
      final reg = ctx.registrationFor('tap_widget')!;
      await reg.handler(
        CallToolRequest(
          name: 'tap_widget',
          arguments: const <String, Object?>{'ref': 's_1', 'snapshotId': 0},
        ),
      );
      // snapshotId == 0 is the jsonDecodeInt sentinel — legacy code treats it
      // as null and omits it from the extension call.
      expect(fakeVm.lastArgs!.containsKey('snapshotId'), isFalse);
    });
  });
}
