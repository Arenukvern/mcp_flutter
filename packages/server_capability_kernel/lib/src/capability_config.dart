// packages/server_capability_kernel/lib/src/capability_config.dart
import 'package:meta/meta.dart';

/// Capability-scoped configuration parsed from CLI flags or config file.
///
/// The host parses the full CLI arg set, then hands each capability its
/// scoped slice. Unknown keys are ignored (capabilities can evolve their
/// config independently).
@immutable
final class CapabilityConfig {
  const CapabilityConfig({Map<String, Object?>? values})
    : _values = values ?? const <String, Object?>{};

  final Map<String, Object?> _values;

  T? get<T>(String key) {
    final value = _values[key];
    if (value is T) return value;
    return null;
  }

  bool getBool(String key, {bool defaultValue = false}) =>
      get<bool>(key) ?? defaultValue;

  String? getString(String key) => get<String>(key);

  int? getInt(String key) => get<int>(key);
}
