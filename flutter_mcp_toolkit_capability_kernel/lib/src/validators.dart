// flutter_mcp_toolkit_capability_kernel/lib/src/validators.dart
import 'kernel_errors.dart';

const _reservedCapabilityIds = <String>{'app'};
final _capabilityIdPattern = RegExp(r'^[a-z][a-z0-9_]*$');

/// Throws [InvalidCapabilityIdError] if [id] is empty, malformed, or
/// reserved.
void validateCapabilityId(final String id) {
  if (id.isEmpty) {
    throw InvalidCapabilityIdError('Capability id must not be empty.');
  }
  if (!_capabilityIdPattern.hasMatch(id)) {
    throw InvalidCapabilityIdError(
      'Capability id "$id" must match ^[a-z][a-z0-9_]*\$.',
    );
  }
  if (_reservedCapabilityIds.contains(id)) {
    throw InvalidCapabilityIdError(
      'Capability id "$id" is reserved (used internally for unscoped '
      'dynamic registrations).',
    );
  }
}

/// Throws [PrePrefixedToolNameError] if [name] starts with
/// `<capabilityId>_`.
void validateBareToolName({
  required final String capabilityId,
  required final String name,
}) {
  final prefix = '${capabilityId}_';
  if (name.startsWith(prefix)) {
    throw PrePrefixedToolNameError(
      'Tool name "$name" must not start with the capability prefix '
      '"$prefix"; pass the bare name and let the kernel apply the prefix.',
    );
  }
}

/// Returns `<capabilityId>_<name>`.
String applyPrefix({
  required final String capabilityId,
  required final String name,
}) => '${capabilityId}_$name';
