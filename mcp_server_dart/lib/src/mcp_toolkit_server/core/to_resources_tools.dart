import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_server/flutter_mcp_core.dart';

CallToolResult toCallToolErrorResult(
  final CoreResult result, {
  required final String prefix,
}) => CallToolResult(
  isError: true,
  content: [TextContent(text: formatCoreErrorForMcp(result, prefix: prefix))],
);

ReadResourceResult toReadResourceErrorResult({
  required final String uri,
  required final CoreResult result,
  required final String prefix,
}) => ReadResourceResult(
  contents: [
    TextResourceContents(
      uri: uri,
      text: formatCoreErrorForMcp(result, prefix: prefix),
    ),
  ],
);

String formatCoreErrorForMcp(
  final CoreResult result, {
  required final String prefix,
}) {
  final _ = prefix;
  return jsonEncode(result.toErrorEnvelopeJson());
}

ObjectSchema strictToolInputSchema({
  final Map<String, Schema> properties = const <String, Schema>{},
  final List<String> required = const <String>[],
}) => ObjectSchema(
  properties: {'connection': connectionObjectSchema, ...properties},
  required: required,
  additionalProperties: false,
);
