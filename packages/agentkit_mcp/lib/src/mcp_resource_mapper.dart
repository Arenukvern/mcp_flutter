import 'dart:convert';

import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:dart_mcp/server.dart';

AgentResult readResourceResultToAgentResult(final ReadResourceResult result) {
  final artifacts = <AgentArtifact>[];
  final contents = <Map<String, Object?>>[];
  for (final block in result.contents) {
    if (block is TextResourceContents) {
      artifacts.add(
        AgentArtifact.text(
          block.text,
          mimeType: block.mimeType ?? 'application/json',
        ),
      );
      contents.add(<String, Object?>{
        'type': 'text',
        'uri': block.uri,
        'mimeType': block.mimeType,
        'text': block.text,
      });
    } else if (block is BlobResourceContents) {
      artifacts.add(
        AgentArtifact.text(
          block.blob,
          mimeType: block.mimeType ?? 'application/octet-stream',
        ),
      );
      contents.add(<String, Object?>{
        'type': 'blob',
        'uri': block.uri,
        'mimeType': block.mimeType,
      });
    }
  }
  return AgentResult.success(
    data: <String, Object?>{'contents': contents},
    artifacts: artifacts,
  );
}

ReadResourceResult agentResultToReadResourceResult(
  final AgentResult result, {
  required final String uri,
}) {
  if (!result.ok) {
    return ReadResourceResult(
      contents: [
        TextResourceContents(
          uri: uri,
          mimeType: 'application/json',
          text: jsonEncode({
            'code': result.code ?? 'agent_error',
            'message': result.message,
            'details': result.details,
          }),
        ),
      ],
    );
  }

  final contentsRaw = result.data['contents'];
  if (contentsRaw is List) {
    final contents = <ResourceContents>[];
    for (final entry in contentsRaw) {
      if (entry is! Map) continue;
      final map = Map<String, Object?>.from(entry);
      final entryUri = map['uri'] is String ? map['uri']! as String : uri;
      final mime = map['mimeType'] is String
          ? map['mimeType']! as String
          : 'application/json';
      final text = map['text'];
      if (text is String) {
        contents.add(
          TextResourceContents(uri: entryUri, mimeType: mime, text: text),
        );
        continue;
      }
      final blob = map['blob'];
      if (blob is String) {
        contents.add(
          BlobResourceContents(uri: entryUri, mimeType: mime, blob: blob),
        );
      }
    }
    if (contents.isNotEmpty) {
      return ReadResourceResult(contents: contents);
    }
  }

  if (result.artifacts.isNotEmpty) {
    return ReadResourceResult(
      contents: [
        for (final artifact in result.artifacts)
          if (artifact.mimeType.startsWith('image/') && artifact.text != null)
            BlobResourceContents(
              uri: uri,
              mimeType: artifact.mimeType,
              blob: artifact.text!,
            )
          else
            TextResourceContents(
              uri: uri,
              mimeType: artifact.mimeType,
              text: artifact.text ?? '',
            ),
      ],
    );
  }

  final resource = result.data['resource'];
  if (resource is Map) {
    final map = Map<String, Object?>.from(resource);
    final text = map['text'];
    if (text is String) {
      return ReadResourceResult(
        contents: [
          TextResourceContents(
            uri: map['uri'] is String ? map['uri']! as String : uri,
            mimeType: map['mimeType'] is String
                ? map['mimeType']! as String
                : 'application/json',
            text: text,
          ),
        ],
      );
    }
  }

  final text = result.data['text'];
  if (text is String) {
    return ReadResourceResult(
      contents: [
        TextResourceContents(
          uri: uri,
          mimeType: 'application/json',
          text: text,
        ),
      ],
    );
  }

  return ReadResourceResult(
    contents: [
      TextResourceContents(
        uri: uri,
        mimeType: 'application/json',
        text: jsonEncode(result.data),
      ),
    ],
  );
}
