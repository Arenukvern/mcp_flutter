import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_toolkit_server/flutter_mcp_core.dart';
import 'package:intentcall_session/intentcall_session.dart';
import 'package:test/test.dart';

void main() {
  group('BundleBuilder', () {
    late Directory tempDir;
    late String snapshotsDir;
    late String bundlesDir;
    late String stateFilePath;
    late IntentSnapshotStore snapshotStore;
    late BundleBuilder bundleBuilder;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('flutter_mcp_bundle_');
      snapshotsDir = '${tempDir.path}/snapshots';
      bundlesDir = '${tempDir.path}/bundles';
      stateFilePath = '${tempDir.path}/state.json';
      snapshotStore = IntentSnapshotStore(snapshotsDir: snapshotsDir);
      bundleBuilder = BundleBuilder(
        bundlesDir: bundlesDir,
        snapshotStore: snapshotStore,
        stateFilePath: stateFilePath,
      );

      Directory(snapshotsDir).createSync(recursive: true);
      File(stateFilePath).writeAsStringSync('{"schemaVersion":1}');

      final snapshotPayload = {
        'id': 'baseline',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'results': [
          {
            'name': 'status',
            'args': <String, Object?>{},
            'result': {
              'ok': true,
              'data': {'connected': false},
            },
          },
        ],
      };
      File('$snapshotsDir/baseline.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(snapshotPayload),
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('--check mode does not write output directory', () async {
      final outputPath = '${tempDir.path}/bundle_check';
      final result = await bundleBuilder.createBundle(
        fromSnapshot: 'baseline',
        outputDirectory: outputPath,
        writeOptions: const SafeWriteOptions(check: true, diff: true),
      );

      expect(Directory(outputPath).existsSync(), isFalse);
      final writes = (result['writeResults']! as List)
          .cast<Map<String, Object?>>();
      expect(writes.single['status'], equals(SafeWriteStatus.added));
      expect(writes.single['wrote'], isFalse);
      expect(writes.single['diff'], isA<Map<String, Object?>>());
    });

    test(
      '--no-overwrite blocks existing output without deleting content',
      () async {
        final outputPath = '${tempDir.path}/bundle_existing';
        final outputDir = Directory(outputPath)..createSync(recursive: true);
        final sentinel = File('$outputPath/sentinel.txt')
          ..writeAsStringSync('keep');

        final result = await bundleBuilder.createBundle(
          fromSnapshot: 'baseline',
          outputDirectory: outputPath,
          writeOptions: const SafeWriteOptions(noOverwrite: true),
        );

        final writes = (result['writeResults']! as List)
            .cast<Map<String, Object?>>();
        expect(writes.single['status'], equals(SafeWriteStatus.blocked));
        expect(writes.single['wrote'], isFalse);
        expect(outputDir.existsSync(), isTrue);
        expect(sentinel.existsSync(), isTrue);
        expect(sentinel.readAsStringSync(), equals('keep'));
      },
    );

    test('second publish with unchanged content reports unchanged', () async {
      final outputPath = '${tempDir.path}/bundle_unchanged';

      final first = await bundleBuilder.createBundle(
        fromSnapshot: 'baseline',
        outputDirectory: outputPath,
      );
      final firstWrites = (first['writeResults']! as List)
          .cast<Map<String, Object?>>();
      expect(firstWrites.single['status'], equals(SafeWriteStatus.added));

      final second = await bundleBuilder.createBundle(
        fromSnapshot: 'baseline',
        outputDirectory: outputPath,
      );
      final secondWrites = (second['writeResults']! as List)
          .cast<Map<String, Object?>>();
      expect(secondWrites.single['status'], equals(SafeWriteStatus.unchanged));
      expect(secondWrites.single['wrote'], isFalse);
      expect(File('$outputPath/manifest.json').existsSync(), isTrue);
    });
  });
}
