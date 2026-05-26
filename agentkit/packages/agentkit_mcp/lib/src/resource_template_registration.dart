import 'package:meta/meta.dart';

import 'resource_registration.dart';

/// A parameterized resource template the capability wants the host to expose.
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
