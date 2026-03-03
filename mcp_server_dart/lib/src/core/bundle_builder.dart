// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter_inspector_mcp_server/src/core/snapshot_store.dart';

final class BundleBuilder {
  BundleBuilder({
    required this.bundlesDir,
    required this.snapshotStore,
    required this.stateFilePath,
  });

  final String bundlesDir;
  final SnapshotStore snapshotStore;
  final String stateFilePath;

  Future<Map<String, Object?>> createBundle({
    required final String fromSnapshot,
    final String? outputDirectory,
  }) async {
    final snapshot = await snapshotStore.loadSnapshot(fromSnapshot);
    final outputPath = _resolveOutputPath(fromSnapshot, outputDirectory);

    final outDir = io.Directory(outputPath);
    if (outDir.existsSync()) {
      outDir.deleteSync(recursive: true);
    }
    outDir.createSync(recursive: true);

    final files = <Map<String, Object?>>[];

    final snapshotFile = io.File('${outDir.path}/snapshot.json');
    snapshotFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(snapshot),
    );
    files.add({'path': snapshotFile.path, 'type': 'snapshot'});

    final commandsDir = io.Directory('${outDir.path}/commands');
    commandsDir.createSync(recursive: true);

    final results = snapshot['results'];
    if (results is List) {
      for (var i = 0; i < results.length; i += 1) {
        final item = results[i];
        if (item is! Map) {
          continue;
        }

        final json = item.cast<String, Object?>();
        final name = '${json['name'] ?? 'unknown'}'.replaceAll(
          RegExp(r'[^a-zA-Z0-9._-]'),
          '_',
        );
        final file = io.File(
          '${commandsDir.path}/${i.toString().padLeft(2, '0')}_$name.json',
        );
        file.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(json),
        );
        files.add({
          'path': file.path,
          'type': 'command_result',
          'command': name,
        });
      }
    }

    final stateFile = io.File(stateFilePath);
    if (stateFile.existsSync()) {
      final copyTarget = io.File('${outDir.path}/state.json');
      copyTarget.writeAsStringSync(stateFile.readAsStringSync());
      files.add({'path': copyTarget.path, 'type': 'state'});
    }

    files.sort((final a, final b) {
      return '${a['path']}'.compareTo('${b['path']}');
    });

    final manifest = <String, Object?>{
      'bundleVersion': 1,
      'snapshotId': fromSnapshot,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'sourceSnapshotCreatedAt': snapshot['createdAt'],
      'files': files,
    };

    final manifestFile = io.File('${outDir.path}/manifest.json');
    manifestFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(manifest),
    );

    return {
      'outputDirectory': outDir.path,
      'manifestPath': manifestFile.path,
      'snapshotId': fromSnapshot,
      'fileCount': files.length,
      'files': files,
    };
  }

  String _resolveOutputPath(final String snapshotId, final String? outputDir) {
    if (outputDir != null && outputDir.isNotEmpty) {
      return outputDir;
    }

    final safeId = snapshotId.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return '$bundlesDir/$safeId';
  }
}
