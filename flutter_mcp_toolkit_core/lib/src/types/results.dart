// flutter_mcp_toolkit_core/lib/src/types/results.dart
// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:meta/meta.dart';

import 'error_codes.dart';

@immutable
final class CoreError {
  const CoreError({
    required this.code,
    required this.message,
    this.details,
    this.descriptor,
  });

  final String code;
  final String message;
  final Object? details;
  final CoreErrorDescriptor? descriptor;

  CoreErrorDescriptor get resolvedDescriptor =>
      descriptor ?? descriptorForErrorCode(code);

  Map<String, Object?> toJson() {
    final resolved = resolvedDescriptor;
    return {
      'code': code,
      'message': message,
      'details': details,
      'descriptor': resolved.toJson(),
      'recovery': recoveryForErrorCode(code, details: details),
    };
  }
}

@immutable
final class CoreResult {
  const CoreResult({
    required this.ok,
    this.data,
    this.error,
    this.meta = const <String, Object?>{},
  });

  factory CoreResult.success({
    final Object? data,
    final Map<String, Object?> meta = const <String, Object?>{},
  }) => CoreResult(ok: true, data: data, meta: meta);

  factory CoreResult.failure({
    required final String code,
    required final String message,
    final Object? details,
    final Map<String, Object?> meta = const <String, Object?>{},
  }) {
    final descriptor = descriptorForErrorCode(code);
    return CoreResult(
      ok: false,
      error: CoreError(
        code: code,
        message: message,
        details: details,
        descriptor: descriptor,
      ),
      meta: meta,
    );
  }

  final bool ok;
  final Object? data;
  final CoreError? error;
  final Map<String, Object?> meta;

  int get exitCode {
    if (ok) {
      return 0;
    }
    return error?.resolvedDescriptor.exitCode ?? exitCodeForErrorCode(null);
  }

  CoreResult withMeta(final Map<String, Object?> nextMeta) =>
      CoreResult(ok: ok, data: data, error: error, meta: nextMeta);

  Map<String, Object?> toEnvelopeJson() => {
    'ok': ok,
    'data': data,
    'error': error?.toJson(),
    'meta': meta,
  };

  /// Returns the failure envelope JSON shape `{code, message, details,
  /// descriptor, recovery}`. If this result is a success, returns the same
  /// shape filled with [CoreErrorCode.unknown] / "Unknown error" — callers
  /// should check [ok] first.
  Map<String, Object?> toErrorEnvelopeJson() =>
      error?.toJson() ??
      CoreError(code: CoreErrorCode.unknown, message: 'Unknown error').toJson();
}
