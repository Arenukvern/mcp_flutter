import 'dart:convert';

import 'agent_result.dart';

/// Coerces VM service-extension wire values (`Map` values often [String]) to
/// types expected by [validateAgainstSchema], using [schema] property types.
AgentArguments coerceArgumentsForSchema(
  final InputSchema schema,
  final AgentArguments arguments,
) {
  if (schema['type'] != 'object') {
    return Map<String, Object?>.from(arguments);
  }

  final properties = _propertySchemas(schema);
  final coerced = <String, Object?>{};
  for (final entry in arguments.entries) {
    final propertySchema = properties[entry.key];
    if (propertySchema == null) {
      coerced[entry.key] = entry.value;
      continue;
    }
    final value = _coercePropertyValue(propertySchema, entry.value);
    if (!identical(value, _omitProperty)) {
      coerced[entry.key] = value;
    }
  }
  return coerced;
}

const Object _omitProperty = Object();

Object? _coercePropertyValue(
  final Map<String, Object?> propertySchema,
  final Object? value,
) {
  if (value == null) {
    return null;
  }

  final type = propertySchema['type'];
  if (type is! String) {
    return value;
  }

  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty && type != 'string') {
      return _omitProperty;
    }
    return switch (type) {
      'string' => value,
      'integer' => int.tryParse(trimmed) ?? value,
      'number' => num.tryParse(trimmed) ?? value,
      'boolean' => _parseWireBool(trimmed) ?? value,
      'object' => _parseWireJsonMap(trimmed) ?? value,
      'array' => _parseWireJsonList(trimmed, propertySchema) ?? value,
      _ => value,
    };
  }

  if (type == 'object' && value is Map) {
    return _coerceObjectValue(propertySchema, Map<String, Object?>.from(value));
  }
  if (type == 'array' && value is List) {
    return _coerceArrayValue(propertySchema, value);
  }

  return value;
}

Map<String, Object?> _coerceObjectValue(
  final Map<String, Object?> objectSchema,
  final Map<String, Object?> value,
) {
  if (objectSchema['type'] != 'object') {
    return value;
  }
  final properties = _propertySchemas(objectSchema);
  if (properties.isEmpty) {
    if (objectSchema['additionalProperties'] == true) {
      return _coerceOpenObjectMap(value);
    }
    return value;
  }

  final coerced = <String, Object?>{};
  for (final entry in value.entries) {
    final propertySchema = properties[entry.key];
    if (propertySchema == null) {
      coerced[entry.key] = entry.value;
      continue;
    }
    final coercedValue = _coercePropertyValue(propertySchema, entry.value);
    if (!identical(coercedValue, _omitProperty)) {
      coerced[entry.key] = coercedValue;
    }
  }
  return coerced;
}

/// Shallow coercion for object schemas with empty [properties] and
/// `additionalProperties: true` (e.g. [wait_for] predicate maps).
Map<String, Object?> _coerceOpenObjectMap(final Map<String, Object?> value) {
  final coerced = <String, Object?>{};
  for (final entry in value.entries) {
    coerced[entry.key] = _coerceOpenObjectEntryValue(entry.value);
  }
  return _coerceWaitPredicateFields(coerced);
}

Object? _coerceOpenObjectEntryValue(final Object? value) {
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      final parsed = _parseWireJsonMap(trimmed);
      if (parsed != null) {
        return _coerceOpenObjectMap(parsed);
      }
    }
    return value;
  }
  if (value is Map) {
    return _coerceOpenObjectMap(Map<String, Object?>.from(value));
  }
  return value;
}

Map<String, Object?> _coerceWaitPredicateFields(final Map<String, Object?> value) {
  final kind = value['kind'];
  if (kind is! String) {
    return value;
  }
  final out = Map<String, Object?>.from(value);
  switch (kind) {
    case 'time':
      _coerceIntField(out, 'ms');
    case 'text':
    case 'noText':
      _coerceStringField(out, 'text');
    case 'stable':
      _coerceIntField(out, 'stableWindowMs');
    case 'noError':
      break;
    default:
      break;
  }
  return out;
}

void _coerceIntField(final Map<String, Object?> map, final String key) {
  final raw = map[key];
  if (raw == null) {
    return;
  }
  if (raw is int) {
    return;
  }
  if (raw is num) {
    map[key] = raw.toInt();
    return;
  }
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      map.remove(key);
      return;
    }
    final parsed = int.tryParse(trimmed);
    if (parsed != null) {
      map[key] = parsed;
    }
  }
}

void _coerceStringField(final Map<String, Object?> map, final String key) {
  final raw = map[key];
  if (raw == null) {
    return;
  }
  if (raw is String) {
    return;
  }
  map[key] = raw.toString();
}

List<Object?> _coerceArrayValue(
  final Map<String, Object?> arraySchema,
  final List<dynamic> value,
) {
  final itemSchema = arraySchema['items'];
  if (itemSchema is! Map) {
    return value;
  }
  final normalizedItemSchema = Map<String, Object?>.from(itemSchema);
  return value
      .map((final item) => _coercePropertyValue(normalizedItemSchema, item))
      .where((final item) => !identical(item, _omitProperty))
      .toList();
}

List<Object?>? _parseWireJsonList(
  final String trimmed,
  final Map<String, Object?> arraySchema,
) {
  final decoded = jsonDecode(trimmed);
  if (decoded is! List) {
    return null;
  }
  return _coerceArrayValue(arraySchema, decoded);
}

Map<String, Object?>? _parseWireJsonMap(final String trimmed) {
  final decoded = jsonDecode(trimmed);
  if (decoded is Map<String, Object?>) {
    return decoded;
  }
  if (decoded is Map) {
    return Map<String, Object?>.from(decoded);
  }
  return null;
}

bool? _parseWireBool(final String normalized) {
  final lower = normalized.toLowerCase();
  if (lower == '1' || lower == 'true' || lower == 'yes') {
    return true;
  }
  if (lower == '0' || lower == 'false' || lower == 'no') {
    return false;
  }
  return null;
}

Map<String, Map<String, Object?>> _propertySchemas(final Map<String, Object?> schema) {
  final raw = schema['properties'];
  if (raw is! Map) {
    return const {};
  }
  final out = <String, Map<String, Object?>>{};
  for (final entry in raw.entries) {
    if (entry.key is! String) {
      continue;
    }
    final value = entry.value;
    if (value is Map) {
      out[entry.key as String] = Map<String, Object?>.from(value);
    }
  }
  return out;
}
