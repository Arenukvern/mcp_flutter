import 'dart:async';

import 'package:flutter_mcp_harness/src/toolkit_extensions.dart';
import 'package:flutter_mcp_harness/src/vm_client.dart';
import 'package:test/test.dart';
import 'package:vm_service/vm_service.dart' as vm;

void main() {
  group('toolkitExtensionsReady', () {
    test('accepts requiredAtAttach', () {
      expect(
        toolkitExtensionsReady(ToolkitExtensions.requiredAtAttach),
        isTrue,
      );
    });

    test('accepts full driver set', () {
      expect(
        toolkitExtensionsReady(ToolkitExtensions.requiredForToolkitDriver),
        isTrue,
      );
    });

    test('rejects when enter_text is missing', () {
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

  group('assertToolkitExtension', () {
    test('optional verb missing throws with version hint', () {
      expect(
        () => assertToolkitExtension(
          ToolkitExtensions.requiredAtAttach.toSet(),
          ToolkitExtensions.scroll,
        ),
        throwsA(
          predicate<StateError>(
            (error) =>
                error.message.contains(ToolkitExtensions.scroll) &&
                error.message.contains(
                  ToolkitExtensions.minimumMcpToolkitVersionForFullDriverSet,
                ),
          ),
        ),
      );
    });

    test('optional verb present allows use', () {
      expect(
        () => assertToolkitExtension(
          {
            ...ToolkitExtensions.requiredAtAttach,
            ToolkitExtensions.navigate,
          },
          ToolkitExtensions.navigate,
        ),
        returnsNormally,
      );
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
        readExtensions: () async => [...ToolkitExtensions.requiredAtAttach],
        rebind: () async {},
        extensionAdded: const Stream<ToolkitExtensionRegistrationEvent>.empty(),
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
    test('completes with only requiredAtAttach registered', () async {
      final present = await waitUntilToolkitRegistered(
        readExtensions: () async => [...ToolkitExtensions.requiredAtAttach],
        rebind: () async {},
        extensionAdded: const Stream<ToolkitExtensionRegistrationEvent>.empty(),
        timeout: const Duration(seconds: 1),
      );
      expect(
        present,
        containsAll(ToolkitExtensions.requiredAtAttach),
      );
    });

    test('completes when extensions arrive on the event stream', () async {
      final added = StreamController<ToolkitExtensionRegistrationEvent>();
      unawaited(
        Future<void>(() async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          for (final name in ToolkitExtensions.requiredAtAttach) {
            added.add(ToolkitExtensionRegistrationEvent(extension: name));
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

    test('throws TimeoutException when hard extensions never register',
        () async {
      await expectLater(
        waitUntilToolkitRegistered(
          readExtensions: () async => const <String>[],
          rebind: () async {},
          extensionAdded:
              const Stream<ToolkitExtensionRegistrationEvent>.empty(),
          timeout: const Duration(milliseconds: 50),
          rpcTimeout: const Duration(milliseconds: 10),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('snapshot and tap without enter_text does not complete', () async {
      final added = StreamController<ToolkitExtensionRegistrationEvent>();
      added.add(ToolkitExtensionRegistrationEvent(extension: ToolkitExtensions.tap));
      await expectLater(
        waitUntilToolkitRegistered(
          readExtensions: () async => [
            ToolkitExtensions.snapshot,
            ToolkitExtensions.tap,
          ],
          rebind: () async {},
          extensionAdded: added.stream,
          timeout: const Duration(milliseconds: 50),
          rpcTimeout: const Duration(milliseconds: 10),
        ),
        throwsA(isA<TimeoutException>()),
      );
      await added.close();
    });

    test('hot restart during wait does not count hard verb from dead isolate',
        () async {
      final added = StreamController<ToolkitExtensionRegistrationEvent>();
      added.add(
        ToolkitExtensionRegistrationEvent(
          isolateId: 'isol-old',
          extension: ToolkitExtensions.tap,
        ),
      );
      added.add(
        ToolkitExtensionRegistrationEvent(
          isolateId: 'isol-old',
          extension: ToolkitExtensions.snapshot,
        ),
      );
      added.add(
        ToolkitExtensionRegistrationEvent(
          isolateId: 'isol-new',
          extension: ToolkitExtensions.snapshot,
        ),
      );

      late final TimeoutException timeout;
      try {
        await waitUntilToolkitRegistered(
          readExtensions: () async => const <String>[],
          rebind: () async {},
          extensionAdded: added.stream,
          timeout: const Duration(milliseconds: 80),
          rpcTimeout: const Duration(milliseconds: 20),
        );
        fail('expected attach wait to time out after hot restart');
      } on TimeoutException catch (error) {
        timeout = error;
      }
      await added.close();

      expect(timeout.message, contains(ToolkitExtensions.tap));
      expect(timeout.message, contains(ToolkitExtensions.enterText));
    });

    test('hot restart during wait drops optional verb from reported present',
        () async {
      final added = StreamController<ToolkitExtensionRegistrationEvent>();
      added.add(
        ToolkitExtensionRegistrationEvent(
          isolateId: 'isol-old',
          extension: ToolkitExtensions.scroll,
        ),
      );
      added.add(
        ToolkitExtensionRegistrationEvent(
          isolateId: 'isol-old',
          extension: ToolkitExtensions.snapshot,
        ),
      );
      added.add(
        ToolkitExtensionRegistrationEvent(
          isolateId: 'isol-old',
          extension: ToolkitExtensions.tap,
        ),
      );
      added.add(
        ToolkitExtensionRegistrationEvent(
          isolateId: 'isol-new',
          extension: ToolkitExtensions.snapshot,
        ),
      );
      unawaited(
        Future<void>(() async {
          await Future<void>.delayed(const Duration(milliseconds: 15));
          for (final name in [
            ToolkitExtensions.tap,
            ToolkitExtensions.enterText,
          ]) {
            added.add(
              ToolkitExtensionRegistrationEvent(
                isolateId: 'isol-new',
                extension: name,
              ),
            );
          }
        }),
      );

      final present = await waitUntilToolkitRegistered(
        readExtensions: () async => const <String>[],
        rebind: () async {},
        readBoundIsolateId: () async => 'isol-new',
        extensionAdded: added.stream,
        timeout: const Duration(seconds: 1),
        rpcTimeout: const Duration(milliseconds: 100),
      );
      await added.close();

      expect(present, containsAll(ToolkitExtensions.requiredAtAttach));
      expect(present, isNot(contains(ToolkitExtensions.scroll)));
    });

    test('resets present when a new isolate id appears', () async {
      final added = StreamController<ToolkitExtensionRegistrationEvent>();
      added.add(
        ToolkitExtensionRegistrationEvent(
          isolateId: 'isol-a',
          extension: ToolkitExtensions.snapshot,
        ),
      );
      added.add(
        ToolkitExtensionRegistrationEvent(
          isolateId: 'isol-a',
          extension: ToolkitExtensions.tap,
        ),
      );
      added.add(
        ToolkitExtensionRegistrationEvent(
          isolateId: 'isol-b',
          extension: ToolkitExtensions.snapshot,
        ),
      );
      unawaited(
        Future<void>(() async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          for (final name in [
            ToolkitExtensions.tap,
            ToolkitExtensions.enterText,
          ]) {
            added.add(
              ToolkitExtensionRegistrationEvent(
                isolateId: 'isol-b',
                extension: name,
              ),
            );
          }
        }),
      );
      await waitUntilToolkitRegistered(
        readExtensions: () async => const <String>[],
        rebind: () async {},
        readBoundIsolateId: () async => 'isol-b',
        extensionAdded: added.stream,
        timeout: const Duration(seconds: 1),
        rpcTimeout: const Duration(milliseconds: 100),
      );
      await added.close();
    });

    test('SentinelException during snapshot is retryable', () async {
      var reads = 0;
      final present = await waitUntilToolkitRegistered(
        readExtensions: () async {
          reads++;
          if (reads == 1) {
            throw vm.SentinelException.parse('getIsolate', {
              'type': 'Sentinel',
              'valueAsString': 'Collected',
              'kind': 'Collected',
            });
          }
          return [...ToolkitExtensions.requiredAtAttach];
        },
        rebind: () async {},
        extensionAdded: const Stream<ToolkitExtensionRegistrationEvent>.empty(),
        timeout: const Duration(seconds: 1),
        rpcTimeout: const Duration(milliseconds: 100),
      );
      expect(reads, greaterThanOrEqualTo(2));
      expect(present, containsAll(ToolkitExtensions.requiredAtAttach));
    });

    test('per-RPC timeout on hung rebind then event-driven retry', () async {
      final added = StreamController<ToolkitExtensionRegistrationEvent>();
      var rebindCalls = 0;
      unawaited(
        Future<void>(() async {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          for (final name in ToolkitExtensions.requiredAtAttach) {
            added.add(ToolkitExtensionRegistrationEvent(extension: name));
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