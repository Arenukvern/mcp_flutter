import 'dart:io';

import 'package:flutter_inspector_mcp_server/flutter_mcp_core.dart';
import 'package:test/test.dart';

void main() {
  group('SafeFileWriter', () {
    late Directory tempDir;
    late String targetPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('flutter_mcp_safe_write_');
      targetPath = '${tempDir.path}/payload.txt';
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('--check reports drift without writing', () async {
      final result = await SafeFileWriter.writeTextFile(
        path: targetPath,
        content: 'next',
        options: const SafeWriteOptions(check: true, diff: true),
      );

      expect(result.status, equals(SafeWriteStatus.added));
      expect(result.wrote, isFalse);
      expect(File(targetPath).existsSync(), isFalse);
      expect(result.diff, isA<Map<String, Object?>>());
    });

    test('--no-overwrite blocks existing target', () async {
      final file = File(targetPath);
      file.writeAsStringSync('before');

      final result = await SafeFileWriter.writeTextFile(
        path: targetPath,
        content: 'after',
        options: const SafeWriteOptions(noOverwrite: true, diff: true),
      );

      expect(result.status, equals(SafeWriteStatus.blocked));
      expect(result.wrote, isFalse);
      expect(file.readAsStringSync(), equals('before'));
      expect(result.diff, isA<Map<String, Object?>>());
    });

    test('--backup creates timestamped backup before update', () async {
      final file = File(targetPath);
      file.writeAsStringSync('before');

      final result = await SafeFileWriter.writeTextFile(
        path: targetPath,
        content: 'after',
        options: const SafeWriteOptions(backup: true),
      );

      expect(result.status, equals(SafeWriteStatus.updated));
      expect(result.wrote, isTrue);
      expect(result.backupPath, isNotNull);
      expect(file.readAsStringSync(), equals('after'));

      final backup = File(result.backupPath!);
      expect(backup.existsSync(), isTrue);
      expect(backup.readAsStringSync(), equals('before'));
    });

    test('--diff emits deterministic unified diff metadata', () async {
      final file = File(targetPath);
      file.writeAsStringSync('before');

      final result = await SafeFileWriter.writeTextFile(
        path: targetPath,
        content: 'after',
        options: const SafeWriteOptions(diff: true, check: true),
      );

      final diff = result.diff;
      expect(diff, isNotNull);
      expect(diff!['format'], equals('unified'));
      expect(diff['target'], equals(targetPath));

      final text = diff['text'] as String;
      expect(text.contains('--- $targetPath (before)'), isTrue);
      expect(text.contains('+++ $targetPath (after)'), isTrue);
      expect(text.contains('-before'), isTrue);
      expect(text.contains('+after'), isTrue);
    });

    test('unchanged content returns unchanged and does not rewrite', () async {
      final file = File(targetPath);
      file.writeAsStringSync('same');

      final beforeModified = file.lastModifiedSync();

      final result = await SafeFileWriter.writeTextFile(
        path: targetPath,
        content: 'same',
      );

      expect(result.status, equals(SafeWriteStatus.unchanged));
      expect(result.wrote, isFalse);
      expect(file.readAsStringSync(), equals('same'));
      expect(file.lastModifiedSync(), equals(beforeModified));
    });
  });
}
