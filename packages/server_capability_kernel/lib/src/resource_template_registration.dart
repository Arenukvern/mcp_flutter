// packages/server_capability_kernel/lib/src/resource_template_registration.dart
import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:meta/meta.dart';

import 'resource_registration.dart';

/// A parameterized resource template the capability wants the host to expose.
///
/// [uriTemplate] uses `{param}` placeholders (for example
/// `visual://localhost/app/errors/{count}`). The host publishes the template
/// through MCP and registers a matching registry intent keyed by the template
/// URI pattern.
@immutable
final class ResourceTemplateRegistration {
  const ResourceTemplateRegistration({
    required this.uriTemplate,
    required this.name,
    required this.description,
    required this.mimeType,
    required this.handler,
  });

  final String uriTemplate;
  final String name;
  final String description;
  final String mimeType;
  final ResourceHandler handler;
}
