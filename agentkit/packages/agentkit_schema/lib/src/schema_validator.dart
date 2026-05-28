import 'agent_result.dart';
import 'agent_validation_exception.dart';

/// Validates [arguments] against a JSON Schema–shaped [schema] subset.
///
/// **Supported:** root `type: object`; top-level `required`; top-level
/// `additionalProperties: false` (unknown keys); per-property `type` of
/// `string`, `integer`, `number`, `boolean`, `object`, or `array`; `enum` on
/// `string` properties (JSON Schema `enum` array of allowed strings); array
/// `items` when each item is `type: object` with `required` / `properties`;
/// `minimum` / `maximum` on numeric types.
///
/// **Not supported:** `pattern`, `format`, nested object property
/// validation (except array `items` when each item is `type: object` with
/// `required` / `properties`), `oneOf` / `anyOf`, or type coercion. Properties
/// without a `type` are skipped. Unknown keys are allowed when
/// `additionalProperties` is omitted or not `false`.
void validateAgainstSchema(final InputSchema schema, final AgentArguments arguments) {
  final rootType = schema['type'];
  if (rootType != 'object') {
    throw AgentValidationException('Root schema type must be "object".');
  }

  _validateObjectProperties('', schema, arguments);
}

void _validateObjectProperties(
  final String pathPrefix,
  final Map<String, Object?> schema,
  final Map<String, Object?> arguments,
) {
  final properties = _asStringObjectMap(schema['properties']);
  final additionalProperties = schema['additionalProperties'];
  if (additionalProperties == false) {
    for (final key in arguments.keys) {
      if (!properties.containsKey(key)) {
        final at = pathPrefix.isEmpty ? '' : ' at "$pathPrefix"';
        throw AgentValidationException('Unknown property "$key"$at.');
      }
    }
  }

  final required = _asStringList(schema['required']);
  for (final name in required) {
    if (!arguments.containsKey(name)) {
      final at = pathPrefix.isEmpty ? '' : ' at "$pathPrefix"';
      throw AgentValidationException('Missing required property "$name"$at.');
    }
  }

  for (final entry in arguments.entries) {
    final propertySchema = properties[entry.key];
    if (propertySchema == null) {
      continue;
    }
    final path = pathPrefix.isEmpty ? entry.key : '$pathPrefix.${entry.key}';
    _validateValue(path, propertySchema, entry.value);
  }
}

void _validateValue(
  final String path,
  final Map<String, Object?> schema,
  final Object? value,
) {
  final type = schema['type'];
  if (type is! String) {
    return;
  }
  switch (type) {
    case 'string':
      if (value is! String) {
        throw AgentValidationException('"$path" must be a string.');
      }
      _validateStringEnum(path, value, schema);
    case 'integer':
      if (value is! int) {
        throw AgentValidationException('"$path" must be an integer.');
      }
      _validateNumericBounds(path, value, schema);
    case 'number':
      if (value is! num) {
        throw AgentValidationException('"$path" must be a number.');
      }
      _validateNumericBounds(path, value, schema);
    case 'boolean':
      if (value is! bool) {
        throw AgentValidationException('"$path" must be a boolean.');
      }
    case 'object':
      if (value is! Map) {
        throw AgentValidationException('"$path" must be an object.');
      }
    case 'array':
      if (value is! List) {
        throw AgentValidationException('"$path" must be an array.');
      }
      _validateArrayItems(path, schema, value);
  }
}

void _validateArrayItems(
  final String path,
  final Map<String, Object?> schema,
  final List<Object?> value,
) {
  final rawItems = schema['items'];
  if (rawItems is! Map) {
    return;
  }
  final items = Map<String, Object?>.from(rawItems);
  if (items['type'] != 'object') {
    return;
  }
  final itemProperties = _asStringObjectMap(items['properties']);
  if (itemProperties.isEmpty && _asStringList(items['required']).isEmpty) {
    return;
  }

  for (var i = 0; i < value.length; i++) {
    final element = value[i];
    final elementPath = '$path[$i]';
    if (element is! Map) {
      throw AgentValidationException('"$elementPath" must be an object.');
    }
    _validateObjectProperties(
      elementPath,
      items,
      Map<String, Object?>.from(element),
    );
  }
}

void _validateStringEnum(
  final String path,
  final String value,
  final Map<String, Object?> schema,
) {
  final rawEnum = schema['enum'];
  if (rawEnum is! List || rawEnum.isEmpty) {
    return;
  }
  final allowed = rawEnum.whereType<String>().toList(growable: false);
  if (allowed.isEmpty) {
    return;
  }
  if (!allowed.contains(value)) {
    throw AgentValidationException(
      '"$path" must be one of: ${allowed.join(", ")}.',
    );
  }
}

void _validateNumericBounds(
  final String path,
  final num value,
  final Map<String, Object?> schema,
) {
  final minimum = _asNum(schema['minimum']);
  final maximum = _asNum(schema['maximum']);
  if (minimum != null && value < minimum) {
    throw AgentValidationException('"$path" must be at least $minimum.');
  }
  if (maximum != null && value > maximum) {
    throw AgentValidationException('"$path" must be at most $maximum.');
  }
}

num? _asNum(final Object? raw) {
  if (raw is num) {
    return raw;
  }
  return null;
}

Map<String, Map<String, Object?>> _asStringObjectMap(final Object? raw) {
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

List<String> _asStringList(final Object? raw) {
  if (raw is! List) {
    return const [];
  }
  return raw.whereType<String>().toList(growable: false);
}
