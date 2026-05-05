// mcp_capability_kernel/lib/src/kernel_errors.dart
/// Base type for kernel-detected misconfiguration.
sealed class KernelError extends Error {
  KernelError(this.message);
  final String message;
  @override
  String toString() => '$runtimeType: $message';
}

/// Capability id is invalid or reserved.
final class InvalidCapabilityIdError extends KernelError {
  InvalidCapabilityIdError(super.message);
}

/// Tool name passed to registerTool already starts with the capability prefix
/// (capabilities must register bare names).
final class PrePrefixedToolNameError extends KernelError {
  PrePrefixedToolNameError(super.message);
}

/// Two registrations resolve to the same fully-qualified name.
final class ToolNameCollisionError extends KernelError {
  ToolNameCollisionError(super.message);
}

/// register() called twice on the same capability for the same host.
final class CapabilityAlreadyRegisteredError extends KernelError {
  CapabilityAlreadyRegisteredError(super.message);
}

/// `require<T>()` called for a service the host didn't provide.
final class HostServiceUnavailableError extends KernelError {
  HostServiceUnavailableError(super.message);
}
