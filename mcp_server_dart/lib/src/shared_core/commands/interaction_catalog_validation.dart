// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/dynamic_registry/dynamic_gateway.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/types/results.dart';

/// Validates [arguments] for catalog interaction commands before
/// [CommandCatalog.buildCommand] applies permissive fallbacks.
CoreResult? validationFailureForInteractionCatalogCommand({
  required final String commandName,
  required final Map<String, Object?> arguments,
}) {
  final schema = interactionCatalogInputSchemaFor(commandName);
  if (schema == null) {
    return null;
  }
  return validationFailureForDynamicSchema(
    subjectLabel: 'command "$commandName"',
    schema: schema,
    arguments: arguments,
  );
}
