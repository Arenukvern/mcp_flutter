import 'dart:convert';

import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:dart_mcp/server.dart';

AgentResult mcpResultToAgentResult(final CallToolResult result) {
  if (result.isError == true) {
    final text = _firstText(result);
    return AgentResult.failure(
      code: 'mcp_tool_error',
      message: text ?? 'MCP tool returned an error',
      details: {'content': _contentMaps(result)},
    );
  }
  return AgentResult.success(
    data: {
      'content': _contentMaps(result),
      if (_firstText(result) case final String text) 'text': text,
    },
    artifacts: _artifactsFromContent(result),
  );
}

CallToolResult agentResultToMcpResult(final AgentResult result) {
  if (!result.ok) {
    return CallToolResult(
      isError: true,
      content: [
        TextContent(
          text: jsonEncode({
            'code': result.code ?? 'agent_error',
            'message': result.message,
            'details': result.details,
          }),
        ),
      ],
    );
  }
  if (result.artifacts.isNotEmpty) {
    return CallToolResult(
      content: [
        for (final artifact in result.artifacts)
          if (artifact.text != null) TextContent(text: artifact.text!),
      ],
    );
  }
  final text = result.data['text'];
  if (text is String) {
    return CallToolResult(content: [TextContent(text: text)]);
  }
  return CallToolResult(content: [TextContent(text: jsonEncode(result.data))]);
}

List<AgentArtifact> _artifactsFromContent(final CallToolResult result) {
  final artifacts = <AgentArtifact>[];
  for (final block in result.content) {
    if (block is TextContent) {
      artifacts.add(AgentArtifact.text(block.text));
    }
  }
  return artifacts;
}

String? _firstText(final CallToolResult result) {
  for (final block in result.content) {
    if (block is TextContent) {
      return block.text;
    }
  }
  return null;
}

List<Map<String, Object?>> _contentMaps(final CallToolResult result) =>
    result.content
        .map((final block) {
          if (block is TextContent) {
            return <String, Object?>{'type': 'text', 'text': block.text};
          }
          return <String, Object?>{
            'type': block.runtimeType.toString(),
            'value': block.toString(),
          };
        })
        .toList(growable: false);
