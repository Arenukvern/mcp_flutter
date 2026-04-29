// mcp_capability_core/test/_test_helpers.dart
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';

/// In-memory CapabilityContext for unit tests. Stores registrations and
/// exposes them for assertion. Throws [HostServiceUnavailableError] on
/// `require<T>()` unless a service is provided via the [services] map.
///
/// Pass [config] to supply specific config values (e.g. `dumps_supported`).
final class FakeCapabilityContext implements CapabilityContext {
  FakeCapabilityContext({
    required this.capabilityId,
    final Map<Type, HostService>? services,
    final CapabilityConfig? config,
  })  : _services = services ?? const <Type, HostService>{},
        _config = config ?? const CapabilityConfig();

  @override
  final String capabilityId;

  final Map<Type, HostService> _services;
  final Map<String, ToolRegistration> _tools = <String, ToolRegistration>{};
  final CapabilityConfig _config;

  Iterable<String> get registeredToolNames => _tools.keys;
  ToolRegistration? registrationFor(final String name) => _tools[name];

  @override
  CapabilityConfig get config => _config;

  @override
  void registerTool(final ToolRegistration registration) {
    _tools[registration.name] = registration;
  }

  @override
  void registerResource(final ResourceRegistration registration) {
    throw UnimplementedError(
      'registerResource not implemented in FakeCapabilityContext',
    );
  }

  @override
  T require<T extends HostService>() {
    final service = _services[T];
    if (service == null) {
      throw HostServiceUnavailableError(
        'Host service of type $T was not provided to FakeCapabilityContext.',
      );
    }
    return service as T;
  }

  @override
  void log(final String message, {final LogLevel level = LogLevel.info}) {}
}
