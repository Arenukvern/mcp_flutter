// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:convert';

import 'package:from_json_to_json/from_json_to_json.dart';

/// Normalized text payload for dynamic resource responses that did not return
/// explicit `content` or `blob` fields.
final class DynamicTextResourcePayload {
  const DynamicTextResourcePayload({
    required this.content,
    required this.message,
    required this.payload,
  });

  final String content;
  final String message;
  final Map<String, Object?> payload;
}

DynamicTextResourcePayload normalizeDynamicTextResourcePayload(
  final Map<String, Object?> data,
) {
  final payload = <String, Object?>{...data}
    ..remove('content')
    ..remove('mimeType')
    ..remove('blob')
    ..remove('isBlob');
  final message = jsonDecodeString(payload['message']);
  payload.remove('message');

  final normalizedPayload = <String, Object?>{
    if (message.isNotEmpty) 'message': message,
    if (payload.isNotEmpty) 'parameters': payload,
  };

  return DynamicTextResourcePayload(
    content: jsonEncode(normalizedPayload),
    message: message,
    payload: payload,
  );
}
