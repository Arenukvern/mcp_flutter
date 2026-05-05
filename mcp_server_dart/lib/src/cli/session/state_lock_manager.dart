// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:math';

import 'package:meta/meta.dart';

@immutable
final class LockAcquisition {
  const LockAcquisition({
    required this.token,
    required this.lockFilePath,
    required this.acquiredAt,
    required this.waitMs,
    required this.staleLockRecovered,
    this.previousOwner,
  });

  final String token;
  final String lockFilePath;
  final DateTime acquiredAt;
  final int waitMs;
  final bool staleLockRecovered;
  final Map<String, Object?>? previousOwner;

  Map<String, Object?> toJson() => {
    'token': token,
    'lockFilePath': lockFilePath,
    'acquiredAt': acquiredAt.toUtc().toIso8601String(),
    'waitMs': waitMs,
    'staleLockRecovered': staleLockRecovered,
    'previousOwner': previousOwner,
  };
}

final class StateLockException implements Exception {
  const StateLockException({
    required this.message,
    required this.lockFilePath,
    this.owner,
  });

  final String message;
  final String lockFilePath;
  final Map<String, Object?>? owner;

  @override
  String toString() =>
      'StateLockException(message: $message, lockFilePath: $lockFilePath, owner: $owner)';
}

final class StateLockManager {
  StateLockManager({
    required this.lockFilePath,
    this.staleLockTtl = const Duration(minutes: 5),
    this.acquireTimeout = const Duration(seconds: 10),
    this.pollInterval = const Duration(milliseconds: 50),
  });

  final String lockFilePath;
  final Duration staleLockTtl;
  final Duration acquireTimeout;
  final Duration pollInterval;

  Future<T> withLock<T>(final Future<T> Function() action) async {
    final acquisition = await acquire();
    try {
      return await action();
    } finally {
      await release(acquisition);
    }
  }

  Future<LockAcquisition> acquire({final Duration? timeout}) async {
    final effectiveTimeout = timeout ?? acquireTimeout;
    final start = DateTime.now().toUtc();
    var staleRecovered = false;
    Map<String, Object?>? previousOwner;

    while (true) {
      final token = _nextToken();
      final lockFile = io.File(lockFilePath);

      try {
        lockFile.parent.createSync(recursive: true);
        lockFile.createSync(exclusive: true);

        final payload = {
          'token': token,
          'pid': io.pid,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'hostname': io.Platform.localHostname,
        };
        lockFile.writeAsStringSync(jsonEncode(payload));

        final waitMs = DateTime.now().toUtc().difference(start).inMilliseconds;
        return LockAcquisition(
          token: token,
          lockFilePath: lockFilePath,
          acquiredAt: DateTime.now().toUtc(),
          waitMs: waitMs,
          staleLockRecovered: staleRecovered,
          previousOwner: previousOwner,
        );
      } on io.FileSystemException {
        final staleOutcome = await _recoverStaleLockIfNeeded(lockFile);
        staleRecovered = staleRecovered || staleOutcome.recovered;
        previousOwner ??= staleOutcome.owner;

        final elapsed = DateTime.now().toUtc().difference(start);
        if (elapsed >= effectiveTimeout) {
          throw StateLockException(
            message:
                'Timed out acquiring state lock after ${elapsed.inMilliseconds}ms',
            lockFilePath: lockFilePath,
            owner: staleOutcome.owner,
          );
        }

        await Future<void>.delayed(pollInterval);
      }
    }
  }

  Future<void> release(final LockAcquisition acquisition) async {
    final lockFile = io.File(lockFilePath);
    if (!lockFile.existsSync()) {
      return;
    }

    try {
      final raw = lockFile.readAsStringSync();
      final decoded = _decodeMap(raw);
      final token = decoded['token']?.toString();

      if (token != acquisition.token) {
        return;
      }
      lockFile.deleteSync();
    } on Exception {
      // Lock release must be best effort.
    }
  }

  Future<({bool recovered, Map<String, Object?>? owner})>
  _recoverStaleLockIfNeeded(final io.File lockFile) async {
    try {
      final raw = lockFile.readAsStringSync();
      final owner = _decodeMap(raw);
      final createdAtRaw = owner['createdAt']?.toString();
      final createdAt = createdAtRaw == null
          ? null
          : DateTime.tryParse(createdAtRaw)?.toUtc();

      if (createdAt == null) {
        return (recovered: false, owner: owner);
      }

      final now = DateTime.now().toUtc();
      if (now.difference(createdAt) <= staleLockTtl) {
        return (recovered: false, owner: owner);
      }

      lockFile.deleteSync();
      return (recovered: true, owner: owner);
    } on Exception {
      return (recovered: false, owner: null);
    }
  }

  Map<String, Object?> _decodeMap(final String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.cast<String, Object?>();
    }
    return const <String, Object?>{};
  }

  String _nextToken() {
    final rand = Random();
    final suffix = rand.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 'lock_${DateTime.now().microsecondsSinceEpoch}_$suffix';
  }
}
