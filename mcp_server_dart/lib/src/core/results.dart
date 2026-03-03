// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:meta/meta.dart';

@immutable
final class CoreError {
  const CoreError({required this.code, required this.message, this.details});

  final String code;
  final String message;
  final Object? details;

  Map<String, Object?> toJson() => {
    'code': code,
    'message': message,
    'details': details,
  };
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
  }) => CoreResult(
    ok: false,
    error: CoreError(code: code, message: message, details: details),
    meta: meta,
  );

  final bool ok;
  final Object? data;
  final CoreError? error;
  final Map<String, Object?> meta;

  CoreResult withMeta(final Map<String, Object?> nextMeta) =>
      CoreResult(ok: ok, data: data, error: error, meta: nextMeta);

  Map<String, Object?> toEnvelopeJson() => {
    'ok': ok,
    'data': data,
    'error': error?.toJson(),
    'meta': meta,
  };
}
