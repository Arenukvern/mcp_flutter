import 'package:meta/meta.dart';

typedef AgentArguments = Map<String, Object?>;
typedef InputSchema = Map<String, Object?>;
typedef AgentWireMap = Map<String, String>;

@immutable
final class AgentArtifact {
  const AgentArtifact.text(this.text, {this.mimeType = 'text/plain'})
    : bytes = null;

  const AgentArtifact.bytes(this.bytes, {required this.mimeType}) : text = null;

  final String mimeType;
  final String? text;
  final List<int>? bytes;
}

@immutable
final class AgentResult {
  const AgentResult._({
    required this.ok,
    this.message = '',
    this.data = const {},
    this.artifacts = const [],
    this.code,
    this.details = const {},
  });

  factory AgentResult.success({
    final String message = 'ok',
    final Map<String, Object?> data = const {},
    final List<AgentArtifact> artifacts = const [],
  }) => AgentResult._(ok: true, message: message, data: data, artifacts: artifacts);

  factory AgentResult.failure({
    required final String code,
    required final String message,
    final Map<String, Object?> details = const {},
  }) => AgentResult._(
    ok: false,
    code: code,
    message: message,
    details: details,
  );

  final bool ok;
  final String message;
  final Map<String, Object?> data;
  final List<AgentArtifact> artifacts;
  final String? code;
  final Map<String, Object?> details;
}
