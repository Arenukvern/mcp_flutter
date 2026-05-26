import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:meta/meta.dart';

import '../naming/qualified_name.dart';
import 'agent_intent_kind.dart';

@immutable
final class AgentIntentDescriptor {
  AgentIntentDescriptor({
    required this.namespace,
    required this.name,
    required this.description,
    required this.kind,
    required this.inputSchema,
    this.methodName,
    this.resourceUri,
    this.mimeType,
  }) {
    validateNamespace(namespace);
    validateBareName(name);
  }

  final String namespace;
  final String name;
  final String description;
  final AgentIntentKind kind;
  final InputSchema inputSchema;
  final String? methodName;
  final String? resourceUri;
  final String? mimeType;

  String get qualifiedName => qualifyName(namespace: namespace, name: name);

  String get effectiveMethodName => methodName ?? name;

  String get effectiveResourceUri =>
      resourceUri ?? AgentResultEnvelope.resourceUriForName(name);
}
