// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

CoreResult coreResultFromAgentResult(
  final AgentResult result, {
  final Map<String, Object?> meta = const <String, Object?>{},
}) {
  if (result.ok) {
    return CoreResult.success(data: result.data, meta: meta);
  }

  return CoreResult.failure(
    code: result.code ?? CoreErrorCode.unknown,
    message: result.message,
    details: result.details,
    meta: meta,
  );
}
