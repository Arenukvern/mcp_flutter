import 'agent_result.dart';
import 'agent_validation_exception.dart';

void validateAgainstSchema(final InputSchema schema, final AgentArguments arguments) {
  final rootType = schema['type'];
  if (rootType != 'object') {
    throw AgentValidationException('Root schema type must be "object".');
  }

  final properties = _asStringObjectMap(schema['properties']);
  final additionalProperties = schema['additionalProperties'];
  if (additionalProperties == false) {
    for (final key in arguments.keys) {
      if (!properties.containsKey(key)) {
        throw AgentValidationException('Unknown property "$key".');
      }
    }
  }

  final required = _asStringList(schema['required']);
  for (final name in required) {
    if (!arguments.containsKey(name)) {
      throw AgentValidationException('Missing required property "$name".');
    }
  }

  for (final entry in arguments.entries) {
    final propertySchema = properties[entry.key];
    if (propertySchema == null) {
      continue;
    }
    _validateValue(entry.key, propertySchema, entry.value);
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
    case 'integer':
      if (value is! int) {
        throw AgentValidationException('"$path" must be an integer.');
      }
    case 'number':
      if (value is! num) {
        throw AgentValidationException('"$path" must be a number.');
      }
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
  }
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
