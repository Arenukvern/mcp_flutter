// packages/server_capability_kernel/lib/src/resource_registration.dart
import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:meta/meta.dart';

/// Handler for a capability resource read — transport-agnostic [AgentResult].
typedef ResourceHandler = Future<AgentResult> Function(String uri);

/// A resource the capability wants the host to expose.
///
/// [uri] is the bare URI; the host may rewrite the authority/path according
/// to the capability namespace policy. Resource handlers are not prefixed
/// (URIs are already namespaced).
@immutable
final class ResourceRegistration {
  const ResourceRegistration({
    required this.uri,
    required this.name,
    required this.description,
    required this.mimeType,
    required this.handler,
  });

  final String uri;
  final String name;
  final String description;
  final String mimeType;
  final ResourceHandler handler;
}
