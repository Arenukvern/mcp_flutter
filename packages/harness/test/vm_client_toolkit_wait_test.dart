import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:flutter_mcp_harness/src/vm_client.dart';
import 'package:test/test.dart';

void main() {
  group('toolkitExtensionsReady', () {
    test('accepts exact snapshot extension', () {
      expect(
        toolkitExtensionsReady([
          ToolkitExtensions.snapshot,
        ]),
        isTrue,
      );
    });

    test('rejects other ext.mcp.toolkit verbs before snapshot registers', () {
      expect(
        toolkitExtensionsReady(['ext.mcp.toolkit.tap_widget']),
        isFalse,
      );
    });

    test('rejects unrelated extensions', () {
      expect(toolkitExtensionsReady(['ext.flutter.inspector.']), isFalse);
    });
  });

  group('waitUntilToolkitRegistered', () {
    test('returns once extensions appear', () async {
      var reads = 0;
      await waitUntilToolkitRegistered(
        readExtensions: () async {
          reads++;
          if (reads >= 3) return [ToolkitExtensions.snapshot];
          return const <String>[];
        },
        rebind: () async {},
        poll: const Duration(milliseconds: 1),
        timeout: const Duration(seconds: 1),
        onTimeout: () => fail('should not time out'),
      );
      expect(reads, greaterThanOrEqualTo(3));
    });

    test('invokes onTimeout when extensions never register', () async {
      var timedOut = false;
      await waitUntilToolkitRegistered(
        readExtensions: () async => const <String>[],
        rebind: () async {},
        poll: const Duration(milliseconds: 1),
        timeout: const Duration(milliseconds: 5),
        onTimeout: () => timedOut = true,
      );
      expect(timedOut, isTrue);
    });
  });
}