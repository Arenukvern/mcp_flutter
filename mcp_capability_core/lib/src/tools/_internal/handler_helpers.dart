// mcp_capability_core/lib/src/tools/_internal/handler_helpers.dart
// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

/// Internal helpers shared across capability tool handlers.
///
/// All symbols are `@internal` — they are an implementation detail of
/// `mcp_capability_core` and must not be imported from outside this package.
library;

import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:meta/meta.dart';
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';
import 'package:mcp_shared_core/mcp_shared_core.dart';

// ---------------------------------------------------------------------------
// Execution helpers
// ---------------------------------------------------------------------------

/// Standard envelope-preserving execution flow for capability tool handlers.
///
/// Apply per-call connection override → execute the command → translate the
/// CoreResult to a CallToolResult. Override failure short-circuits to the
/// error envelope. Use [onSuccess] for tools whose success payload is not a
/// JSON object (e.g., binary screenshot tools that need ImageContent).
@internal
Future<CallToolResult> runCommand(
  final CommandRunner runner,
  final Map<String, Object?> arguments,
  final CoreCommand command, {
  final CallToolResult Function(Object? data)? onSuccess,
}) async {
  final overrideError = await runner.applyConnectionOverride(arguments);
  if (overrideError != null) return toErrorResult(overrideError);
  final result = await runner.execute(command);
  if (!result.ok) return toErrorResult(result);
  return onSuccess != null
      ? onSuccess(result.data)
      : CallToolResult(
          content: [TextContent(text: jsonEncode(result.data))],
        );
}

/// Serialises a [CoreResult] failure to a structured MCP error result.
///
/// The text content is the JSON-encoded [CoreError] envelope:
/// `{code, message, details, descriptor, recovery}` — the shape that MCP
/// clients parse.
@internal
CallToolResult toErrorResult(final CoreResult result) => CallToolResult(
  isError: true,
  content: [TextContent(text: jsonEncode(result.toErrorEnvelopeJson()))],
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
