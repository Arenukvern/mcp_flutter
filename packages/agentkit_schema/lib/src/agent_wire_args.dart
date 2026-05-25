import 'dart:convert';

import 'agent_result.dart';

/// Parses VM service extension wire maps (`Map<String, String>`).
extension type const AgentWireArgs(AgentWireMap _raw) {
  String? string(final String key) {
    final value = _raw[key];
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool? bool_(final String key) {
    final normalized = string(key)?.toLowerCase();
    if (normalized == null) {
      return null;
    }
    if (normalized == '1' ||
        normalized == 'true' ||
        normalized == 'yes') {
      return true;
    }
    if (normalized == '0' ||
        normalized == 'false' ||
        normalized == 'no') {
      return false;
    }
    return null;
  }

  int? int_(final String key) => int.tryParse(_raw[key]?.trim() ?? '');

  double? double_(final String key) =>
      double.tryParse(_raw[key]?.trim() ?? '');

  Map<String, Object?>? jsonObject(final String key) {
    final raw = string(key);
    if (raw == null) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, Object?>.from(decoded);
    }
    return null;
  }

  AgentArguments toAgentArguments() =>
      Map<String, Object?>.from(_raw);
}
