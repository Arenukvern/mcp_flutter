// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:io' as io;
import 'dart:math' as math;

abstract final class SafeWriteStatus {
  static const added = 'added';
  static const updated = 'updated';
  static const unchanged = 'unchanged';
  static const blocked = 'blocked';
}

final class SafeWriteOptions {
  const SafeWriteOptions({
    this.check = false,
    this.diff = false,
    this.backup = false,
    this.noOverwrite = false,
  });

  final bool check;
  final bool diff;
  final bool backup;
  final bool noOverwrite;

  Map<String, Object?> toJson() => {
    'check': check,
    'diff': diff,
    'backup': backup,
    'noOverwrite': noOverwrite,
  };
}

final class SafeWriteResult {
  const SafeWriteResult({
    required this.target,
    required this.status,
    required this.wrote,
    required this.options,
    this.backupPath,
    this.diff,
  });

  final String target;
  final String status;
  final bool wrote;
  final SafeWriteOptions options;
  final String? backupPath;
  final Map<String, Object?>? diff;

  bool get blocked => status == SafeWriteStatus.blocked;

  Map<String, Object?> toJson() => {
    'target': target,
    'status': status,
    'wrote': wrote,
    'options': options.toJson(),
    if (backupPath != null) 'backupPath': backupPath,
    if (diff != null) 'diff': diff,
  };
}

// ignore: avoid_classes_with_only_static_members
abstract final class SafeFileWriter {
  static Future<SafeWriteResult> writeTextFile({
    required final String path,
    required final String content,
    final SafeWriteOptions options = const SafeWriteOptions(),
  }) async {
    final file = io.File(path);
    final existing = file.existsSync();
    final previousContent = existing ? file.readAsStringSync() : null;
    final status = _statusForWrite(
      exists: existing,
      previousContent: previousContent,
      nextContent: content,
    );

    final diff = options.diff
        ? buildUnifiedDiffMetadata(
            target: path,
            previousContent: previousContent,
            nextContent: content,
          )
        : null;

    if (options.check) {
      return SafeWriteResult(
        target: path,
        status: status,
        wrote: false,
        options: options,
        diff: diff,
      );
    }

    if (options.noOverwrite && existing) {
      return SafeWriteResult(
        target: path,
        status: SafeWriteStatus.blocked,
        wrote: false,
        options: options,
        diff: diff,
      );
    }

    if (status == SafeWriteStatus.unchanged) {
      return SafeWriteResult(
        target: path,
        status: SafeWriteStatus.unchanged,
        wrote: false,
        options: options,
        diff: diff,
      );
    }

    String? backupPath;
    if (options.backup && existing) {
      backupPath = createTimestampedBackupPath(path);
      final backupFile = io.File(backupPath);
      backupFile.parent.createSync(recursive: true);
      file.copySync(backupPath);
    }

    final tempPath =
        '$path.tmp.${io.pid}.${DateTime.now().microsecondsSinceEpoch}';
    final tempFile = io.File(tempPath);
    tempFile.parent.createSync(recursive: true);
    tempFile.writeAsStringSync(content);

    if (!existing) {
      tempFile.renameSync(path);
      return SafeWriteResult(
        target: path,
        status: status,
        wrote: true,
        options: options,
        backupPath: backupPath,
        diff: diff,
      );
    }

    final swapPath =
        '$path.swap.${io.pid}.${DateTime.now().microsecondsSinceEpoch}';
    final swapFile = io.File(swapPath);

    file.renameSync(swapPath);
    try {
      tempFile.renameSync(path);
      if (swapFile.existsSync()) {
        swapFile.deleteSync();
      }
    } on Exception {
      try {
        if (io.File(path).existsSync()) {
          io.File(path).deleteSync();
        }
      } on Exception {
        // Best effort cleanup.
      }
      if (swapFile.existsSync()) {
        swapFile.renameSync(path);
      }
      rethrow;
    }

    return SafeWriteResult(
      target: path,
      status: status,
      wrote: true,
      options: options,
      backupPath: backupPath,
      diff: diff,
    );
  }

  static String _statusForWrite({
    required final bool exists,
    required final String? previousContent,
    required final String nextContent,
  }) {
    if (!exists) {
      return SafeWriteStatus.added;
    }
    if (previousContent == nextContent) {
      return SafeWriteStatus.unchanged;
    }
    return SafeWriteStatus.updated;
  }
}

Map<String, Object?>? buildUnifiedDiffMetadata({
  required final String target,
  required final String? previousContent,
  required final String nextContent,
}) {
  if (previousContent == null && nextContent.isEmpty) {
    return null;
  }
  if (previousContent != null && previousContent == nextContent) {
    return null;
  }

  return {
    'format': 'unified',
    'target': target,
    'text': _buildUnifiedDiffText(
      target: target,
      previousContent: previousContent,
      nextContent: nextContent,
    ),
  };
}

String createTimestampedBackupPath(final String originalPath) {
  final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(
    ':',
    '',
  );
  return '$originalPath.backup.$timestamp';
}

String _buildUnifiedDiffText({
  required final String target,
  required final String? previousContent,
  required final String nextContent,
}) {
  final before = _splitLines(previousContent ?? '');
  final after = _splitLines(nextContent);

  final lines = <String>[
    '--- $target (before)',
    '+++ $target (after)',
    '@@ -1,${math.max(1, before.length)} +1,${math.max(1, after.length)} @@',
  ];

  final maxLength = math.max(before.length, after.length);
  for (var index = 0; index < maxLength; index += 1) {
    final left = index < before.length ? before[index] : null;
    final right = index < after.length ? after[index] : null;

    if (left == right) {
      if (left != null) {
        lines.add(' $left');
      }
      continue;
    }

    if (left != null) {
      lines.add('-$left');
    }
    if (right != null) {
      lines.add('+$right');
    }
  }

  return lines.join('\n');
}

List<String> _splitLines(final String source) {
  if (source.isEmpty) {
    return const <String>[];
  }
  return source.split('\n');
}
