// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:convert';
import 'dart:io' as io;

import 'package:intentcall_session/intentcall_session.dart';

final class BundleBuilder {
  BundleBuilder({
    required this.bundlesDir,
    required this.snapshotStore,
    required this.stateFilePath,
  });

  final String bundlesDir;
  final IntentSnapshotStore snapshotStore;
  final String stateFilePath;

  Future<Map<String, Object?>> createBundle({
    required final String fromSnapshot,
    final String? outputDirectory,
    final SafeWriteOptions writeOptions = const SafeWriteOptions(),
  }) async {
    final snapshot = await snapshotStore.loadSnapshot(fromSnapshot);
    final outputPath = _resolveOutputPath(fromSnapshot, outputDirectory);
    final outputDir = io.Directory(outputPath);

    final bundlePlan = _buildBundlePlan(
      snapshot: snapshot,
      outputPath: outputPath,
      snapshotId: fromSnapshot,
    );
    final nextFiles = bundlePlan.filesByRelativePath;
    final existingFiles = _readDirectoryTextFiles(outputDir);
    final outputExists = outputDir.existsSync();

    final status = _resolveDirectoryStatus(
      exists: outputExists,
      existingFiles: existingFiles,
      nextFiles: nextFiles,
    );
    final diff = writeOptions.diff
        ? _buildDirectoryDiff(
            target: outputPath,
            existingFiles: existingFiles,
            nextFiles: nextFiles,
          )
        : null;

    if (writeOptions.check) {
      final writeResult = SafeWriteResult(
        target: outputPath,
        status: status,
        wrote: false,
        options: writeOptions,
        diff: diff,
      );
      return _bundleResponse(
        outputPath: outputPath,
        snapshotId: fromSnapshot,
        fileEntries: bundlePlan.fileEntries,
        writeResult: writeResult,
      );
    }

    if (writeOptions.noOverwrite && outputExists) {
      final writeResult = SafeWriteResult(
        target: outputPath,
        status: SafeWriteStatus.blocked,
        wrote: false,
        options: writeOptions,
        diff: diff,
      );
      return _bundleResponse(
        outputPath: outputPath,
        snapshotId: fromSnapshot,
        fileEntries: bundlePlan.fileEntries,
        writeResult: writeResult,
      );
    }

    if (status == SafeWriteStatus.unchanged && outputExists) {
      final writeResult = SafeWriteResult(
        target: outputPath,
        status: SafeWriteStatus.unchanged,
        wrote: false,
        options: writeOptions,
        diff: diff,
      );
      return _bundleResponse(
        outputPath: outputPath,
        snapshotId: fromSnapshot,
        fileEntries: bundlePlan.fileEntries,
        writeResult: writeResult,
      );
    }

    final stageDir = io.Directory(_stageDirectoryPath(outputPath));
    if (stageDir.existsSync()) {
      stageDir.deleteSync(recursive: true);
    }
    stageDir.createSync(recursive: true);

    try {
      for (final entry in nextFiles.entries) {
        final file = io.File('${stageDir.path}/${entry.key}');
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(entry.value);
      }

      final publishResult = _publishStagedDirectory(
        outputPath: outputPath,
        stagePath: stageDir.path,
        createBackup: writeOptions.backup,
      );

      final writeResult = SafeWriteResult(
        target: outputPath,
        status: status,
        wrote: true,
        options: writeOptions,
        backupPath: publishResult.backupPath,
        diff: diff,
      );

      return _bundleResponse(
        outputPath: outputPath,
        snapshotId: fromSnapshot,
        fileEntries: bundlePlan.fileEntries,
        writeResult: writeResult,
      );
    } finally {
      if (stageDir.existsSync()) {
        stageDir.deleteSync(recursive: true);
      }
    }
  }

  Map<String, Object?> _bundleResponse({
    required final String outputPath,
    required final String snapshotId,
    required final List<Map<String, Object?>> fileEntries,
    required final SafeWriteResult writeResult,
  }) => {
    'outputDirectory': outputPath,
    'manifestPath': '$outputPath/manifest.json',
    'snapshotId': snapshotId,
    'fileCount': fileEntries.length,
    'files': fileEntries,
    'writeResults': [writeResult.toJson()],
  };

  String _resolveOutputPath(final String snapshotId, final String? outputDir) {
    if (outputDir != null && outputDir.isNotEmpty) {
      return outputDir;
    }

    final safeId = snapshotId.replaceAll(RegExp('[^a-zA-Z0-9._-]'), '_');
    return '$bundlesDir/$safeId';
  }

  ({
    Map<String, String> filesByRelativePath,
    List<Map<String, Object?>> fileEntries,
  })
  _buildBundlePlan({
    required final Map<String, Object?> snapshot,
    required final String outputPath,
    required final String snapshotId,
  }) {
    final filesByRelativePath = <String, String>{};
    final fileEntries = <Map<String, Object?>>[];

    void addFile({
      required final String relativePath,
      required final String content,
      required final String type,
      final String? command,
    }) {
      filesByRelativePath[relativePath] = content;
      fileEntries.add({
        'path': '$outputPath/$relativePath',
        'type': type,
        'command': ?command,
      });
    }

    addFile(
      relativePath: 'snapshot.json',
      content: const JsonEncoder.withIndent('  ').convert(snapshot),
      type: 'snapshot',
    );

    final results = snapshot['results'];
    if (results is List) {
      for (var index = 0; index < results.length; index += 1) {
        final item = results[index];
        if (item is! Map) {
          continue;
        }

        final json = item.cast<String, Object?>();
        final name = '${json['name'] ?? 'unknown'}'.replaceAll(
          RegExp('[^a-zA-Z0-9._-]'),
          '_',
        );
        addFile(
          relativePath:
              'commands/${index.toString().padLeft(2, '0')}_$name.json',
          content: const JsonEncoder.withIndent('  ').convert(json),
          type: 'command_result',
          command: name,
        );
      }
    }

    final stateFile = io.File(stateFilePath);
    if (stateFile.existsSync()) {
      addFile(
        relativePath: 'state.json',
        content: stateFile.readAsStringSync(),
        type: 'state',
      );
    }

    fileEntries.sort(
      (final a, final b) => '${a['path']}'.compareTo('${b['path']}'),
    );

    final manifest = <String, Object?>{
      'bundleVersion': 1,
      'snapshotId': snapshotId,
      // Keep manifest stable across identical re-builds so unchanged status is
      // deterministic under safe-write semantics.
      'createdAt':
          snapshot['createdAt'] ?? DateTime.now().toUtc().toIso8601String(),
      'sourceSnapshotCreatedAt': snapshot['createdAt'],
      'files': fileEntries,
    };
    filesByRelativePath['manifest.json'] = const JsonEncoder.withIndent(
      '  ',
    ).convert(manifest);

    return (filesByRelativePath: filesByRelativePath, fileEntries: fileEntries);
  }

  String _resolveDirectoryStatus({
    required final bool exists,
    required final Map<String, String> existingFiles,
    required final Map<String, String> nextFiles,
  }) {
    if (!exists) {
      return SafeWriteStatus.added;
    }
    if (_directoryContentsEqual(existingFiles, nextFiles)) {
      return SafeWriteStatus.unchanged;
    }
    return SafeWriteStatus.updated;
  }

  bool _directoryContentsEqual(
    final Map<String, String> left,
    final Map<String, String> right,
  ) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  Map<String, String> _readDirectoryTextFiles(final io.Directory directory) {
    if (!directory.existsSync()) {
      return const <String, String>{};
    }

    final files = <String, String>{};
    final rootPath = directory.path;
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is! io.File) {
        continue;
      }
      final absolutePath = entity.path;
      final relativePath = absolutePath.startsWith('$rootPath/')
          ? absolutePath.substring(rootPath.length + 1)
          : absolutePath.substring(rootPath.length);
      files[relativePath] = entity.readAsStringSync();
    }
    return files;
  }

  Map<String, Object?> _buildDirectoryDiff({
    required final String target,
    required final Map<String, String> existingFiles,
    required final Map<String, String> nextFiles,
  }) {
    final allPaths = <String>{...existingFiles.keys, ...nextFiles.keys}.toList()
      ..sort();
    final changes = <Map<String, Object?>>[];

    for (final relativePath in allPaths) {
      final before = existingFiles[relativePath];
      final after = nextFiles[relativePath];
      if (before == after) {
        continue;
      }

      final status = switch ((before, after)) {
        (null, final String _) => 'added',
        (final String _, null) => 'removed',
        _ => 'updated',
      };
      changes.add({
        'path': '$target/$relativePath',
        'status': status,
        'diff': buildUnifiedDiffMetadata(
          target: '$target/$relativePath',
          previousContent: before,
          nextContent: after ?? '',
        ),
      });
    }

    return {
      'format': 'unified',
      'target': target,
      'changedFileCount': changes.length,
      'changes': changes,
    };
  }

  ({String? backupPath}) _publishStagedDirectory({
    required final String outputPath,
    required final String stagePath,
    required final bool createBackup,
  }) {
    final outputDir = io.Directory(outputPath);
    final stageDir = io.Directory(stagePath);
    if (!outputDir.existsSync()) {
      stageDir.renameSync(outputPath);
      return (backupPath: null);
    }

    final swapPath =
        '$outputPath.swap.${io.pid}.${DateTime.now().microsecondsSinceEpoch}';
    final swapDir = outputDir.renameSync(swapPath);

    try {
      stageDir.renameSync(outputPath);
    } on Exception {
      if (io.Directory(outputPath).existsSync()) {
        io.Directory(outputPath).deleteSync(recursive: true);
      }
      swapDir.renameSync(outputPath);
      rethrow;
    }

    String? backupPath;
    if (createBackup) {
      final backupDirectoryPath = createTimestampedBackupPath(outputPath);
      backupPath = backupDirectoryPath;
      _copyDirectory(
        source: swapDir,
        target: io.Directory(backupDirectoryPath),
      );
    }
    if (swapDir.existsSync()) {
      swapDir.deleteSync(recursive: true);
    }

    return (backupPath: backupPath);
  }

  String _stageDirectoryPath(final String outputPath) =>
      '$outputPath.stage.${io.pid}.${DateTime.now().microsecondsSinceEpoch}';

  void _copyDirectory({
    required final io.Directory source,
    required final io.Directory target,
  }) {
    target.createSync(recursive: true);
    for (final entity in source.listSync(recursive: true)) {
      final sourcePath = entity.path;
      final relativePath = sourcePath.substring(source.path.length + 1);
      final targetPath = '${target.path}/$relativePath';
      if (entity is io.Directory) {
        io.Directory(targetPath).createSync(recursive: true);
      } else if (entity is io.File) {
        final targetFile = io.File(targetPath);
        targetFile.parent.createSync(recursive: true);
        entity.copySync(targetPath);
      }
    }
  }
}
