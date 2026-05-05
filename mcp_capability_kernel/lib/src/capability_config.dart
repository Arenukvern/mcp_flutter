// mcp_capability_kernel/lib/src/capability_config.dart
import 'package:meta/meta.dart';

/// Capability-scoped configuration parsed from CLI flags or config file.
///
/// The host parses the full CLI arg set, then hands each capability its
/// scoped slice. Unknown keys are ignored (capabilities can evolve their
/// config independently).
@immutable
final class CapabilityConfig {
  const CapabilityConfig({final Map<String, Object?>? values})
    : _values = values ?? const <String, Object?>{};

  final Map<String, Object?> _values;

  T? get<T>(final String key) {
    final value = _values[key];
    if (value is T) return value;
    return null;
  }

  bool getBool(final String key, {final bool defaultValue = false}) =>
      get<bool>(key) ?? defaultValue;

  String? getString(final String key) => get<String>(key);

  int? getInt(final String key) => get<int>(key);
}
