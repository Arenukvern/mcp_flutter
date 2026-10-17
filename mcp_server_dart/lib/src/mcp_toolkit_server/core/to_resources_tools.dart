import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_server/flutter_mcp_core.dart';

CallToolResult toCallToolErrorResult(
  CoreResult result, {
  required String prefix,
}) => CallToolResult(
  isError: true,
  content: [TextContent(text: formatCoreErrorForMcp(result, prefix: prefix))],
);

ReadResourceResult toReadResourceErrorResult({
  required String uri,
  required CoreResult result,
  required String prefix,
}) => ReadResourceResult(
  contents: [
    TextResourceContents(
      uri: uri,
      text: formatCoreErrorForMcp(result, prefix: prefix),
    ),
  ],
);

String formatCoreErrorForMcp(
  CoreResult result, {
  required String prefix,
}) {
  final _ = prefix;
  return jsonEncode(result.toErrorEnvelopeJson());
}

ObjectSchema strictToolInputSchema({
  Map<String, Schema> properties = const <String, Schema>{},
  List<String> required = const <String>[],
}) => ObjectSchema(
  properties: {'connection': connectionObjectSchema, ...properties},
  required: required,
  additionalProperties: false,
);
