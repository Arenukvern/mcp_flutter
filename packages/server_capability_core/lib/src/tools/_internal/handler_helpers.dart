// packages/server_capability_core/lib/src/tools/_internal/handler_helpers.dart
// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

/// Internal helpers shared across capability tool handlers.
///
/// All symbols are `@internal` — they are an implementation detail of
/// `flutter_mcp_toolkit_capability_core` and must not be imported from outside this package.
library;

import 'package:intentcall_schema/intentcall_schema.dart';
import 'package:meta/meta.dart';
import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';

// ---------------------------------------------------------------------------
// Execution helpers
// ---------------------------------------------------------------------------

/// Standard envelope-preserving execution flow for capability tool handlers.
///
/// Apply per-call connection override → execute the command → translate the
/// [CoreResult] to an [AgentResult]. Override failure short-circuits to the
/// error envelope. Use [onSuccess] for tools whose success payload is not a
/// plain JSON object (e.g. screenshot tools with image artifacts).
@internal
Future<AgentResult> runCommand(
  final CommandRunner runner,
  final Map<String, Object?> arguments,
  final CoreCommand command, {
  final AgentResult Function(Object? data)? onSuccess,
}) async {
  final overrideError = await runner.applyConnectionOverride(arguments);
  if (overrideError != null) return agentErrorFromCore(overrideError);
  final result = await runner.execute(command);
  if (!result.ok) return agentErrorFromCore(result);
  return onSuccess != null
      ? onSuccess(result.data)
      : AgentResult.success(
          data: result.data is Map<String, Object?>
              ? Map<String, Object?>.from(result.data! as Map)
              : <String, Object?>{'payload': result.data},
        );
}

/// Serialises a [CoreResult] failure to a structured [AgentResult].
@internal
AgentResult agentErrorFromCore(final CoreResult result) => AgentResult.failure(
  code: result.error?.code ?? 'core_error',
  message: result.error?.message ?? 'Command failed',
  details: result.toErrorEnvelopeJson(),
);

// ---------------------------------------------------------------------------
// Argument coercion helpers
// ---------------------------------------------------------------------------

/// Returns the string value of [raw] trimmed, or null if absent/non-string.
@internal
String? stringArgOrNull(final Object? raw) {
  if (raw is! String) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Returns the int value of [raw], or null if absent or non-numeric.
///
/// Unlike [intArgOrNull], zero is a valid coordinate (e.g. inspect at origin).
@internal
int? coordinateIntArgOrNull(final Object? raw) => switch (raw) {
  final int v => v,
  final num v when v == v.toInt() => v.toInt(),
  _ => null,
};

/// Returns the int value of [raw], or null if absent, non-numeric, or zero.
///
/// Zero is treated as absent for legacy parity (`snapshotId == 0` means "not
/// provided" in the wire protocol).
@internal
int? intArgOrNull(final Object? raw) {
  final value = switch (raw) {
    final int v => v,
    final num v when v == v.toInt() => v.toInt(),
    _ => null,
  };
  if (value == null || value == 0) return null;
  return value;
}

/// Returns the double value of [raw], or [defaultValue] if absent/non-numeric.
@internal
double doubleArgOrDefault(final Object? raw, final double defaultValue) {
  if (raw == null) return defaultValue;
  if (raw is num) return raw.toDouble();
  return defaultValue;
}

/// Returns the bool value of [raw], or false if absent/non-bool.
@internal
bool boolArgOrFalse(final Object? raw) {
  if (raw is bool) return raw;
  return false;
}

/// Returns the bool value of [raw], or [defaultValue] if absent/non-bool.
/// Mirrors legacy behaviour where some args (e.g. compress, includeErrors)
/// default to true and the wire payload may either omit the key or pass
/// "false" as a string.
@internal
bool boolArgOrDefault(final Object? raw, {required final bool defaultValue}) {
  if (raw is bool) return raw;
  if (raw is String) return raw.toLowerCase() != 'false';
  return defaultValue;
}

/// Returns the int value of [raw] coerced to int, or [defaultValue] if
/// absent / non-numeric / zero. The "zero ⇒ default" rule matches legacy
/// `whenZeroUse` semantics for fields like `errorsCount`.
@internal
int intArgOrDefault(final Object? raw, {required final int defaultValue}) {
  final v = switch (raw) {
    final int v => v,
    final num v when v == v.toInt() => v.toInt(),
    _ => null,
  };
  if (v == null || v == 0) return defaultValue;
  return v;
}

/// Routing metadata from screenshot payloads for MCP image-only tool responses.
@internal
Map<String, Object?> screenshotRoutingSummary(final Map<String, Object?> data) {
  final summary = <String, Object?>{};
  for (final key in <String>[
    'captureHints',
    'warnings',
    'suggestedAction',
    'requestedMode',
    'actualMode',
    'captureMode',
    'desktopCaptureRetried',
    'desktopCaptureRecovery',
  ]) {
    final value = data[key];
    if (value != null) {
      summary[key] = value;
    }
  }
  return summary;
}
