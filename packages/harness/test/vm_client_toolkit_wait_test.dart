import 'dart:async';

import 'package:flutter_mcp_harness/src/toolkit_extensions.dart';
import 'package:flutter_mcp_harness/src/vm_client.dart';
import 'package:test/test.dart';
import 'package:vm_service/vm_service.dart' as vm;

void main() {
  group('toolkitExtensionsReady', () {
    test('accepts the full ToolkitDriver extension set', () {
      expect(
        toolkitExtensionsReady(ToolkitExtensions.requiredForToolkitDriver),
        isTrue,
      );
    });

    test('rejects a partial toolkit subset', () {
      expect(
        toolkitExtensionsReady([ToolkitExtensions.tap]),
        isFalse,
      );
      expect(
        toolkitExtensionsReady([
          ToolkitExtensions.snapshot,
          ToolkitExtensions.tap,
        ]),
        isFalse,
      );
    });

    test('rejects unrelated extensions', () {
      expect(toolkitExtensionsReady(['ext.flutter.inspector.']), isFalse);
    });
  });

  group('subscribeIsolateStream', () {
    test('stream already subscribed (103) returns false', () async {
      final subscribed = await subscribeIsolateStream(
        streamListen: (_) async => throw vm.RPCError('streamListen', 103),
        budget: const Duration(seconds: 1),
      );
      expect(subscribed, isFalse);
    });

    test('103 path still allows toolkit registration to complete', () async {
      final subscribed = await subscribeIsolateStream(
        streamListen: (_) async => throw vm.RPCError('streamListen', 103),
        budget: const Duration(seconds: 1),
      );
      expect(subscribed, isFalse);
      await waitUntilToolkitRegistered(
        readExtensions: () async => [
          ...ToolkitExtensions.requiredForToolkitDriver,
        ],
        rebind: () async {},
        extensionAdded: const Stream<String>.empty(),
        timeout: const Duration(seconds: 1),
      );
    });

    test('hung streamListen throws TimeoutException', () async {
      await expectLater(
        subscribeIsolateStream(
          streamListen: (_) async {
            await Future<void>.delayed(const Duration(seconds: 5));
            return vm.Success();
          },
          budget: const Duration(milliseconds: 30),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('cancelIsolateStreamIfSubscribed is no-op when not subscribed', () async {
      var canceled = false;
      await cancelIsolateStreamIfSubscribed((_) async {
        canceled = true;
        return vm.Success();
      }, false);
      expect(canceled, isFalse);
    });
  });

  group('waitUntilToolkitRegistered', () {
    test('completes when extensions are already registered', () async {
      await waitUntilToolkitRegistered(
        readExtensions: () async => [
          ...ToolkitExtensions.requiredForToolkitDriver,
        ],
        rebind: () async {},
        extensionAdded: const Stream<String>.empty(),
        timeout: const Duration(seconds: 1),
      );
    });

    test('completes when an extension arrives on the event stream', () async {
      final added = StreamController<String>();
      unawaited(
        Future<void>(() async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          for (final name in ToolkitExtensions.requiredForToolkitDriver) {
            added.add(name);
          }
        }),
      );
      await waitUntilToolkitRegistered(
        readExtensions: () async => const <String>[],
        rebind: () async {},
        extensionAdded: added.stream,
        timeout: const Duration(seconds: 1),
        rpcTimeout: const Duration(milliseconds: 100),
      );
      await added.close();
    });

    test('throws TimeoutException when registration never completes', () async {
      await expectLater(
        waitUntilToolkitRegistered(
          readExtensions: () async => const <String>[],
          rebind: () async {},
          extensionAdded: const Stream<String>.empty(),
          timeout: const Duration(milliseconds: 50),
          rpcTimeout: const Duration(milliseconds: 10),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('partial toolkit registration does not complete before deadline',
        () async {
      final added = StreamController<String>();
      added.add(ToolkitExtensions.tap);
      await expectLater(
        waitUntilToolkitRegistered(
          readExtensions: () async => [ToolkitExtensions.tap],
          rebind: () async {},
          extensionAdded: added.stream,
          timeout: const Duration(milliseconds: 50),
          rpcTimeout: const Duration(milliseconds: 10),
        ),
        throwsA(isA<TimeoutException>()),
      );
      await added.close();
    });

    test('per-RPC timeout on hung rebind then event-driven retry', () async {
      final added = StreamController<String>();
      var rebindCalls = 0;
      unawaited(
        Future<void>(() async {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          for (final name in ToolkitExtensions.requiredForToolkitDriver) {
            added.add(name);
          }
        }),
      );
      await waitUntilToolkitRegistered(
        readExtensions: () async => const <String>[],
        rebind: () async {
          rebindCalls++;
          if (rebindCalls == 1) {
            await Future<void>.delayed(const Duration(seconds: 10));
          }
        },
        extensionAdded: added.stream,
        timeout: const Duration(seconds: 2),
        rpcTimeout: const Duration(milliseconds: 30),
      );
      expect(rebindCalls, greaterThanOrEqualTo(1));
      await added.close();
    });
  });
}