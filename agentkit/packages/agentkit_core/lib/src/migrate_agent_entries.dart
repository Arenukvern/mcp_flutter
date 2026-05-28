// Shared MCPCallEntry → AgentCallEntry text migrator (CLI + fmt_migrate_agent_entries).
import 'dart:io';

import 'package:path/path.dart' as p;

class MigrateAgentEntriesPathNotFound implements Exception {
  MigrateAgentEntriesPathNotFound(this.path);

  final String path;

  @override
  String toString() => 'Path not found: $path';
}

/// Result of migrating one Dart file from [MCPCallEntry] to [AgentCallEntry].
final class MigrateAgentEntriesFileResult {
  const MigrateAgentEntriesFileResult({
    required this.path,
    required this.changed,
    required this.migrated,
  });

  final String path;
  final bool changed;
  final String migrated;
}

/// Summary of a migrate run over a file or directory.
final class MigrateAgentEntriesReport {
  const MigrateAgentEntriesReport({
    required this.filesScanned,
    required this.filesChanged,
    required this.results,
  });

  final int filesScanned;
  final int filesChanged;
  final List<MigrateAgentEntriesFileResult> results;

  bool get wouldChange => filesChanged > 0;
}

/// Text migrator for MCPCallEntry → AgentCallEntry (Phase 6f).
///
/// Limitations (documented in migration_agentkit_phase6.md):
/// - Extension types wrapping MCPCallEntry need manual namespace/handler review.
/// - Nested [ObjectSchema] / array fields are only partially preserved; see
///   `TODO(migrate)` comments in generated `inputSchema` and refine manually.
/// - Does not remove MCPCallEntry bridge types (Phase 6b).
final class MigrateAgentEntriesMigrator {
  MigrateAgentEntriesMigrator({this.defaultNamespace = 'app'});

  final String defaultNamespace;

  bool wouldChange(final String source) => migrateSource(source) != source;

  String migrateSource(final String source) {
    if (!source.contains('MCPCallEntry')) {
      return source;
    }

    var output = source;
    output = _replaceTypeReferences(output);
    output = _transformFactoryCalls(output, kind: 'tool');
    output = _transformFactoryCalls(output, kind: 'resource');
    output = _fixImports(output);
    return output;
  }

  String _replaceTypeReferences(final String source) => source
      .replaceAll('Set<MCPCallEntry>', 'Set<AgentCallEntry>')
      .replaceAll('Iterable<MCPCallEntry>', 'Iterable<AgentCallEntry>')
      .replaceAll('List<MCPCallEntry>', 'List<AgentCallEntry>')
      .replaceAll('Future<Set<MCPCallEntry>>', 'Future<Set<AgentCallEntry>>')
      .replaceAll(
        'Future<void> Function({required Set<MCPCallEntry> entries})',
        'Future<void> Function({required Set<AgentCallEntry> entries})',
      )
      .replaceAll('implements MCPCallEntry', 'implements AgentCallEntry')
      .replaceAll('(MCPCallEntry entry)', '(AgentCallEntry entry)')
      .replaceAll('final MCPCallEntry ', 'final AgentCallEntry ')
      .replaceAll('const MCPCallEntry ', 'const AgentCallEntry ');

  String _transformFactoryCalls(
    final String source, {
    required final String kind,
  }) {
    final needle = 'MCPCallEntry.$kind(';
    var output = source;
    var searchFrom = 0;
    while (true) {
      final index = output.indexOf(needle, searchFrom);
      if (index == -1) {
        return output;
      }
      final openParen = index + needle.length - 1;
      final closeParen = _matchingParenIndex(output, openParen);
      if (closeParen == null) {
        searchFrom = index + needle.length;
        continue;
      }
      final original = output.substring(index, closeParen + 1);
      final migrated = _transformSingleFactory(original, kind: kind);
      output = output.replaceRange(index, closeParen + 1, migrated);
      searchFrom = index + migrated.length;
    }
  }

  String _transformSingleFactory(
    final String call, {
    required final String kind,
  }) {
    final definitionKind = kind == 'tool'
        ? 'MCPToolDefinition'
        : 'MCPResourceDefinition';
    final definitionMatch = RegExp(
      'definition:\\s*$definitionKind\\(',
    ).firstMatch(call);
    if (definitionMatch == null) {
      return call.replaceFirst('MCPCallEntry.$kind', 'AgentCallEntry.$kind');
    }

    final defOpen = definitionMatch.end - 1;
    final defClose = _matchingParenIndex(call, defOpen);
    if (defClose == null) {
      return call.replaceFirst('MCPCallEntry.$kind', 'AgentCallEntry.$kind');
    }

    final definitionBody = call.substring(defOpen + 1, defClose);
    final name = _extractStringField(definitionBody, 'name') ?? 'unknown_entry';
    final description =
        _extractStringField(definitionBody, 'description') ??
        'Migrated MCPCallEntry';
    final mimeType = kind == 'resource'
        ? (_extractStringField(definitionBody, 'mimeType') ??
              'application/json')
        : null;

    final handlerPrefix = call.substring(defClose + 1);
    final handlerMatch = RegExp(r'handler:\s*').firstMatch(handlerPrefix);
    if (handlerMatch == null) {
      return call.replaceFirst('MCPCallEntry.$kind', 'AgentCallEntry.$kind');
    }

    final handlerStartInCall = defClose + 1 + handlerMatch.end;
    var handlerSource = call.substring(handlerStartInCall).trim();
    if (handlerSource.endsWith(',')) {
      handlerSource = handlerSource
          .substring(0, handlerSource.length - 1)
          .trim();
    }
    final migratedHandler = _migrateHandler(handlerSource);

    final handlerLines = migratedHandler
        .split('\n')
        .asMap()
        .entries
        .map((final entry) {
          if (entry.key == 0) {
            return entry.value;
          }
          return '    ${entry.value}';
        })
        .join('\n');

    final buffer = StringBuffer('AgentCallEntry.$kind(\n')
      ..writeln("    namespace: '$defaultNamespace',")
      ..writeln("    name: '$name',")
      ..writeln("    description: '$description',");
    if (kind == 'tool') {
      _writeInputSchemaConst(buffer, definitionBody);
    }
    // Resources omit inputSchema — [AgentCallEntry.resource] defaults to uri-required.
    if (kind == 'resource') {
      buffer.writeln("    mimeType: '$mimeType',");
    }
    buffer
      ..writeln('    handler: $handlerLines,')
      ..write('  )');
    return buffer.toString();
  }

  String _migrateHandler(final String handler) {
    final arrowMcpResult = RegExp(
      r'^\(([^)]*)\)\s*=>\s*MCPCallResult\s*\(',
      dotAll: true,
    ).firstMatch(handler);
    if (arrowMcpResult != null) {
      final params = arrowMcpResult.group(1) ?? 'final request';
      final bodyStart = arrowMcpResult.end;
      final bodyClose = _matchingParenIndex(handler, bodyStart - 1);
      if (bodyClose != null) {
        final body = handler.substring(bodyStart, bodyClose);
        return _wrapHandlerBody(
          params,
          'final _result = MCPCallResult($body);',
        );
      }
    }

    final blockFn = RegExp(
      r'^\(([^)]*)\)\s*(async\s*)?\{',
      dotAll: true,
    ).firstMatch(handler);
    if (blockFn != null) {
      final params = blockFn.group(1) ?? 'final request';
      final openBrace = handler.indexOf('{', blockFn.start);
      final closeBrace = _matchingBraceIndex(handler, openBrace);
      if (closeBrace != null) {
        final body = handler.substring(openBrace + 1, closeBrace).trim();
        return _wrapHandlerBody(
          params,
          body,
          hasExistingReturn: body.contains('return '),
        );
      }
    }

    return "(final args) async => AgentResult.success(message: 'TODO migrate handler')";
  }

  String _wrapHandlerBody(
    final String params,
    final String body, {
    final bool hasExistingReturn = false,
  }) {
    final paramName = _primaryParamName(params);
    final bodyLines = body
        .split('\n')
        .map((final line) {
          if (line.trim().isEmpty) {
            return '';
          }
          return '  $line';
        })
        .join('\n');

    final buffer = StringBuffer('(final args) async {\n')
      ..writeln('  final $paramName = args.map(')
      ..writeln(
        "    (final key, final value) => MapEntry(key, value?.toString() ?? ''),",
      )
      ..writeln('  );');

    if (hasExistingReturn) {
      buffer
        ..writeln(bodyLines)
        ..writeln('  if (_result is Map<String, Object?>) {')
        ..writeln("    final message = _result['message'] as String? ?? '';")
        ..writeln(
          "    final data = Map<String, Object?>.from(_result)..remove('message');",
        )
        ..writeln(
          '    return AgentResult.success(message: message, data: data);',
        )
        ..writeln('  }')
        ..writeln(
          "  return AgentResult.success(message: '$paramName handled');",
        );
    } else {
      buffer
        ..writeln(bodyLines)
        ..writeln("  final message = _result['message'] as String? ?? '';")
        ..writeln(
          "  final data = Map<String, Object?>.from(_result)..remove('message');",
        )
        ..writeln(
          '  return AgentResult.success(message: message, data: data);',
        );
    }

    buffer.write('}');
    return buffer.toString();
  }

  String _primaryParamName(final String params) {
    final match = RegExp(r'final\s+(\w+)').firstMatch(params);
    return match?.group(1) ?? 'request';
  }

  String? _extractStringField(final String body, final String field) {
    final match = RegExp("$field:\\s*'([^']*)'").firstMatch(body);
    return match?.group(1);
  }

  void _writeInputSchemaConst(
    final StringBuffer buffer,
    final String definitionBody,
  ) {
    final schemaOpen = RegExp(
      r'inputSchema:\s*ObjectSchema\s*\(',
    ).firstMatch(definitionBody);
    if (schemaOpen == null) {
      buffer
        ..writeln('    inputSchema: const {')
        ..writeln("      'type': 'object',")
        ..writeln("      'properties': <String, Object?>{},")
        ..writeln('    },');
      return;
    }

    final openParen = schemaOpen.end - 1;
    final closeParen = _matchingParenIndex(definitionBody, openParen);
    if (closeParen == null) {
      buffer
        ..writeln('    inputSchema: const {')
        ..writeln("      'type': 'object',")
        ..writeln("      'properties': <String, Object?>{},")
        ..writeln('    },');
      return;
    }

    final schemaBody = definitionBody.substring(openParen + 1, closeParen);
    final additionalProperties = _extractAdditionalProperties(schemaBody);
    final required = _extractRequiredFieldNames(schemaBody);
    final properties = _extractTypedProperties(schemaBody);
    final detailedProperties = _extractDetailedPropertySchemas(schemaBody);
    final migrationTodo = _inputSchemaMigrationTodo(
      schemaBody,
      properties,
      detailedProperties,
    );
    if (migrationTodo != null) {
      buffer.writeln('    // $migrationTodo');
    }

    buffer..writeln('    inputSchema: const {')
    ..writeln("      'type': 'object',");
    if (additionalProperties != null) {
      buffer.writeln("      'additionalProperties': $additionalProperties,");
    }
    if (properties.isEmpty) {
      buffer.writeln("      'properties': <String, Object?>{},");
    } else {
      buffer.writeln("      'properties': <String, Object?>{");
      for (final name in properties.keys) {
        final detailed = detailedProperties[name];
        if (detailed != null && _jsonSchemaNeedsMultiline(detailed)) {
          _writePropertyJsonSchema(buffer, name, detailed);
        } else if (detailed != null) {
          buffer.writeln(
            "        '$name': ${_compactJsonSchemaLiteral(detailed)},",
          );
        } else {
          buffer.writeln("        '$name': {'type': '${properties[name]}'},");
        }
      }
      buffer.writeln('      },');
    }
    if (required.isNotEmpty) {
      buffer.writeln(
        "      'required': <String>[${required.map((final n) => "'$n'").join(', ')}],",
      );
    }
    buffer.writeln('    },');
  }

  bool? _extractAdditionalProperties(final String objectBody) {
    for (final match
        in RegExp(r'additionalProperties:\s*(true|false)\b')
            .allMatches(objectBody)) {
      if (_braceDepthAt(objectBody, match.start) == 0) {
        return match.group(1) == 'true';
      }
    }
    return null;
  }

  List<String> _extractRequiredFieldNames(final String schemaBody) {
    for (final match in RegExp(r'required:\s*\[').allMatches(schemaBody)) {
      if (_braceDepthAt(schemaBody, match.start) != 0) {
        continue;
      }
      final openBracket = match.end - 1;
      final closeBracket = _matchingBracketIndex(schemaBody, openBracket);
      if (closeBracket == null) {
        continue;
      }
      final inner = schemaBody.substring(openBracket + 1, closeBracket);
      return RegExp(
        "'([^']+)'",
      ).allMatches(inner).map((final m) => m.group(1)!).toList();
    }
    return const [];
  }

  Map<String, String> _extractTypedProperties(final String schemaBody) {
    final section = _objectSchemaPropertiesInner(schemaBody);
    if (section == null) {
      return const {};
    }

    final properties = <String, String>{};
    final typePattern = RegExp(
      r"'([^']+)':\s*(?:const\s+)?"
      r'(StringSchema|IntegerSchema|BooleanSchema|NumberSchema|ObjectSchema|ArraySchema|'
      r'Schema\.string|Schema\.int|Schema\.bool|Schema\.num|Schema\.object|Schema\.array)\b',
    );
    for (final match in typePattern.allMatches(section)) {
      if (_braceDepthAt(section, match.start) != 0) {
        continue;
      }
      final name = match.group(1)!;
      final schemaType = match.group(2)!;
      properties[name] = switch (schemaType) {
        'ObjectSchema' || 'Schema.object' => 'object',
        'ArraySchema' || 'Schema.array' => 'array',
        _ => _jsonTypeForSchemaConstructor(schemaType),
      };
    }
    return properties;
  }

  String _jsonTypeForSchemaConstructor(final String schemaType) => switch (schemaType) {
        'StringSchema' || 'Schema.string' => 'string',
        'IntegerSchema' || 'Schema.int' => 'integer',
        'BooleanSchema' || 'Schema.bool' => 'boolean',
        'NumberSchema' || 'Schema.num' => 'number',
        _ => 'string',
      };

  String? _objectSchemaPropertiesInner(final String schemaBody) {
    final match = RegExp(r'properties:\s*\{').firstMatch(schemaBody);
    if (match == null) {
      return null;
    }
    final openBrace = match.end - 1;
    final closeBrace = _matchingBraceIndex(schemaBody, openBrace);
    if (closeBrace == null) {
      return null;
    }
    return schemaBody.substring(openBrace + 1, closeBrace);
  }

  int _braceDepthAt(final String source, final int index) {
    var depth = 0;
    for (var i = 0; i < index && i < source.length; i++) {
      final char = source[i];
      if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;
      }
    }
    return depth;
  }

  Map<String, Map<String, Object?>> _extractDetailedPropertySchemas(
    final String schemaBody,
  ) {
    final section = _objectSchemaPropertiesInner(schemaBody);
    if (section == null) {
      return const {};
    }

    final detailed = <String, Map<String, Object?>>{};
    final pattern = RegExp(
      r"'([^']+)':\s*(?:const\s+)?"
      r'(ObjectSchema|ArraySchema|Schema\.object|Schema\.array)\s*\(',
    );
    for (final match in pattern.allMatches(section)) {
      if (_braceDepthAt(section, match.start) != 0) {
        continue;
      }
      final name = match.group(1)!;
      final constructor = match.group(2)!;
      final openParen = match.end - 1;
      final closeParen = _matchingParenIndex(section, openParen);
      if (closeParen == null) {
        continue;
      }
      final body = section.substring(openParen + 1, closeParen);
      final json = switch (constructor) {
        'ObjectSchema' || 'Schema.object' => _objectSchemaBodyToJsonMap(body),
        'ArraySchema' || 'Schema.array' => _arraySchemaBodyToJsonMap(body),
        _ => null,
      };
      if (json != null) {
        detailed[name] = json;
      }
    }
    return detailed;
  }

  Map<String, Object?>? _arraySchemaBodyToJsonMap(final String arrayBody) {
    final primitiveItem = _extractPrimitiveArrayItemType(arrayBody);
    if (primitiveItem != null) {
      return <String, Object?>{
        'type': 'array',
        'items': <String, Object?>{'type': primitiveItem},
      };
    }

    final objectItems = _extractObjectSchemaItemsBody(arrayBody);
    if (objectItems == null) {
      return RegExp(r'items\s*:').hasMatch(arrayBody) ? null : <String, Object?>{'type': 'array'};
    }

    final itemsJson = _objectSchemaBodyToJsonMap(objectItems);
    if (itemsJson == null) {
      return null;
    }
    return <String, Object?>{
      'type': 'array',
      'items': itemsJson,
    };
  }

  String? _topLevelArrayItemsTail(final String arrayBody) {
    for (final match in RegExp(r'\bitems\s*:').allMatches(arrayBody)) {
      if (_braceDepthAt(arrayBody, match.start) == 0) {
        return arrayBody.substring(match.end).trim();
      }
    }
    return null;
  }

  String? _extractPrimitiveArrayItemType(final String arrayBody) {
    final itemsTail = _topLevelArrayItemsTail(arrayBody);
    if (itemsTail == null) {
      return null;
    }
    final match = RegExp(
      r'^(?:const\s+)?'
      r'(StringSchema|IntegerSchema|BooleanSchema|NumberSchema|'
      r'Schema\.string|Schema\.int|Schema\.bool|Schema\.num)\b',
    ).firstMatch(itemsTail);
    if (match == null) {
      return null;
    }
    return _jsonTypeForSchemaConstructor(match.group(1)!);
  }

  String? _extractObjectSchemaItemsBody(final String arrayBody) {
    final itemsTail = _topLevelArrayItemsTail(arrayBody);
    if (itemsTail == null) {
      return null;
    }
    final match = RegExp(
      r'^(?:const\s+)?(?:ObjectSchema|Schema\.object)\s*\(',
    ).firstMatch(itemsTail);
    if (match == null) {
      return null;
    }
    final openParen = match.end - 1;
    final closeParen = _matchingParenIndex(itemsTail, openParen);
    if (closeParen == null) {
      return null;
    }
    return itemsTail.substring(openParen + 1, closeParen);
  }

  Map<String, Object?>? _objectSchemaBodyToJsonMap(final String objectBody) {
    final hasPropertiesBlock = RegExp(r'properties:\s*\{').hasMatch(objectBody);
    final properties = _extractTypedProperties(objectBody);
    final required = _extractRequiredFieldNames(objectBody);
    final additionalProperties = _extractAdditionalProperties(objectBody);
    final nestedDetailed = _extractDetailedPropertySchemas(objectBody);

    if (hasPropertiesBlock && properties.isEmpty) {
      return null;
    }

    final json = <String, Object?>{'type': 'object'};
    if (additionalProperties != null) {
      json['additionalProperties'] = additionalProperties;
    }
    if (properties.isNotEmpty) {
      final jsonProperties = <String, Object?>{};
      for (final name in properties.keys) {
        final detailed = nestedDetailed[name];
        jsonProperties[name] = detailed ?? <String, Object?>{'type': properties[name]};
      }
      json['properties'] = jsonProperties;
    }
    if (required.isNotEmpty) {
      json['required'] = required;
    }
    return json;
  }

  bool _jsonSchemaNeedsMultiline(final Map<String, Object?> schema) {
    final properties = schema['properties'];
    if (properties is Map && properties.isNotEmpty) {
      return true;
    }
    final required = schema['required'];
    if (required is List && required.isNotEmpty) {
      return true;
    }
    final items = schema['items'];
    if (items is Map<String, Object?>) {
      return _jsonSchemaNeedsMultiline(items);
    }
    return false;
  }

  String _compactJsonSchemaLiteral(final Map<String, Object?> schema) {
    final buffer = StringBuffer('{');
    var first = true;
    for (final key in _jsonSchemaKeyOrder(schema.keys)) {
      if (!first) {
        buffer.write(', ');
      }
      first = false;
      final value = schema[key];
      switch (value) {
        case final Map<String, Object?> map:
          buffer.write("'$key': ${_compactJsonSchemaLiteral(map)}");
        case final List<String> list:
          buffer.write(
            "'$key': <String>[${list.map((final item) => "'$item'").join(', ')}]",
          );
        case final bool boolean:
          buffer.write("'$key': $boolean");
        case final String string:
          buffer.write("'$key': '$string'");
        default:
          break;
      }
    }
    buffer.write('}');
    return buffer.toString();
  }

  void _writePropertyJsonSchema(
    final StringBuffer buffer,
    final String name,
    final Map<String, Object?> schema,
  ) {
    buffer.writeln("        '$name': {");
    _writeJsonSchemaMapEntries(buffer, '          ', schema);
    buffer.writeln('        },');
  }

  void _writeJsonSchemaMapEntries(
    final StringBuffer buffer,
    final String indent,
    final Map<String, Object?> map,
  ) {
    for (final key in _jsonSchemaKeyOrder(map.keys)) {
      _writeJsonSchemaEntry(buffer, indent, key, map[key]);
    }
  }

  Iterable<String> _jsonSchemaKeyOrder(final Iterable<String> keys) sync* {
    const preferred = [
      'type',
      'additionalProperties',
      'properties',
      'required',
      'items',
    ];
    for (final key in preferred) {
      if (keys.contains(key)) {
        yield key;
      }
    }
    for (final key in keys) {
      if (!preferred.contains(key)) {
        yield key;
      }
    }
  }

  void _writeJsonSchemaEntry(
    final StringBuffer buffer,
    final String indent,
    final String key,
    final Object? value,
  ) {
    switch (value) {
      case final Map<String, Object?> map:
        buffer.writeln("$indent'$key': {");
        _writeJsonSchemaMapEntries(buffer, '$indent  ', map);
        buffer.writeln('$indent},');
      case final List<String> list:
        buffer.writeln(
          "$indent'$key': <String>[${list.map((final item) => "'$item'").join(', ')}],",
        );
      case final bool boolean:
        buffer.writeln("$indent'$key': $boolean,");
      case final String string:
        buffer.writeln("$indent'$key': '$string',");
      default:
        break;
    }
  }

  String? _inputSchemaMigrationTodo(
    final String schemaBody,
    final Map<String, String> properties,
    final Map<String, Map<String, Object?>> detailedProperties,
  ) {
    final reasons = <String>[];
    if (_hasUnpreservedNestedArraySchemaItems(schemaBody, detailedProperties)) {
      reasons.add('nested ArraySchema items');
    }
    if (_hasUnpreservedNestedObjectSchemaProperties(
      schemaBody,
      detailedProperties,
    )) {
      reasons.add('nested ObjectSchema properties');
    }
    final inner = _objectSchemaPropertiesInner(schemaBody);
    if (inner != null && inner.trim().isNotEmpty && properties.isEmpty) {
      reasons.add('unparsed property entries');
    }
    if (reasons.isEmpty) {
      return null;
    }
    return 'TODO(migrate): inputSchema preserved partially (${reasons.join(', ')}); '
        'refine manually from the original ObjectSchema.';
  }

  bool _hasUnpreservedNestedArraySchemaItems(
    final String schemaBody,
    final Map<String, Map<String, Object?>> detailedProperties,
  ) {
    final section = _objectSchemaPropertiesInner(schemaBody);
    if (section == null) {
      return false;
    }

    const arrayCtor = r'(?:ArraySchema|Schema\.array)\s*\(';
    const complexItem = r'(?:ObjectSchema|ArraySchema|Schema\.object|Schema\.array)\s*\(';
    final pattern = RegExp(
      "'([^']+)':\\s*(?:const\\s+)?$arrayCtor",
    );
    for (final match in pattern.allMatches(section)) {
      if (_braceDepthAt(section, match.start) != 0) {
        continue;
      }
      final name = match.group(1)!;
      final openParen = match.end - 1;
      final closeParen = _matchingParenIndex(section, openParen);
      if (closeParen == null) {
        continue;
      }
      final arrayBody = section.substring(openParen + 1, closeParen);
      if (!RegExp('items\\s*:\\s*(?:const\\s+)?$complexItem').hasMatch(arrayBody)) {
        continue;
      }
      final detailed = detailedProperties[name];
      final items = detailed?['items'];
      if (items is! Map<String, Object?> ||
          items['properties'] is! Map<String, Object?>) {
        return true;
      }
    }
    return false;
  }

  bool _hasUnpreservedNestedObjectSchemaProperties(
    final String schemaBody,
    final Map<String, Map<String, Object?>> detailedProperties,
  ) {
    final section = _objectSchemaPropertiesInner(schemaBody);
    if (section == null) {
      return false;
    }

    final pattern = RegExp(
      r"'([^']+)':\s*(?:const\s+)?(?:ObjectSchema|Schema\.object)\s*\(",
    );
    for (final match in pattern.allMatches(section)) {
      if (_braceDepthAt(section, match.start) != 0) {
        continue;
      }
      final name = match.group(1)!;
      final openParen = match.end - 1;
      final closeParen = _matchingParenIndex(section, openParen);
      if (closeParen == null) {
        continue;
      }
      final body = section.substring(openParen + 1, closeParen);
      if (!RegExp(r'properties:\s*\{').hasMatch(body)) {
        continue;
      }
      final detailed = detailedProperties[name];
      final properties = detailed?['properties'];
      if (properties is! Map<String, Object?> || properties.isEmpty) {
        return true;
      }
    }
    return false;
  }

  String _fixImports(final String source) {
    if (!source.contains('AgentCallEntry') && !source.contains('AgentResult')) {
      return source;
    }

    var output = source;
    final hasAgentkitCore = output.contains(
      "import 'package:agentkit_core/agentkit_core.dart';",
    );
    final hasAgentkitSchema = output.contains(
      "import 'package:agentkit_schema/agentkit_schema.dart';",
    );

    if (!hasAgentkitCore || !hasAgentkitSchema) {
      final mcpImport = RegExp(
        "import 'package:mcp_toolkit/mcp_toolkit.dart';",
      ).firstMatch(output);
      final insertAt = mcpImport?.start ?? 0;
      final imports = StringBuffer();
      if (!hasAgentkitCore) {
        imports.writeln("import 'package:agentkit_core/agentkit_core.dart';");
      }
      if (!hasAgentkitSchema) {
        imports.writeln(
          "import 'package:agentkit_schema/agentkit_schema.dart';",
        );
      }
      output = output.replaceRange(insertAt, insertAt, imports.toString());
    }

    return output;
  }
}

int? _matchingParenIndex(final String source, final int openIndex) {
  if (openIndex < 0 || openIndex >= source.length || source[openIndex] != '(') {
    return null;
  }
  var depth = 0;
  for (var i = openIndex; i < source.length; i++) {
    final char = source[i];
    if (char == '(') {
      depth++;
    } else if (char == ')') {
      depth--;
      if (depth == 0) {
        return i;
      }
    }
  }
  return null;
}

int? _matchingBraceIndex(final String source, final int openIndex) {
  if (openIndex < 0 || openIndex >= source.length || source[openIndex] != '{') {
    return null;
  }
  var depth = 0;
  for (var i = openIndex; i < source.length; i++) {
    final char = source[i];
    if (char == '{') {
      depth++;
    } else if (char == '}') {
      depth--;
      if (depth == 0) {
        return i;
      }
    }
  }
  return null;
}

int? _matchingBracketIndex(final String source, final int openIndex) {
  if (openIndex < 0 || openIndex >= source.length || source[openIndex] != '[') {
    return null;
  }
  var depth = 0;
  for (var i = openIndex; i < source.length; i++) {
    final char = source[i];
    if (char == '[') {
      depth++;
    } else if (char == ']') {
      depth--;
      if (depth == 0) {
        return i;
      }
    }
  }
  return null;
}

Future<MigrateAgentEntriesReport> migrateAgentEntriesAtPath({
  required final String path,
  required final bool write,
  required final bool checkOnly,
  final String defaultNamespace = 'app',
}) async {
  final target = FileSystemEntity.typeSync(path);
  if (target == FileSystemEntityType.notFound) {
    throw MigrateAgentEntriesPathNotFound(path);
  }

  final migrator = MigrateAgentEntriesMigrator(
    defaultNamespace: defaultNamespace,
  );
  final dartFiles = <File>[];
  if (target == FileSystemEntityType.file) {
    if (p.extension(path) == '.dart') {
      dartFiles.add(File(path));
    }
  } else {
    await for (final entity in Directory(
      path,
    ).list(recursive: true, followLinks: false)) {
      if (entity is File && p.extension(entity.path) == '.dart') {
        dartFiles.add(entity);
      }
    }
  }

  final results = <MigrateAgentEntriesFileResult>[];
  for (final file in dartFiles) {
    final original = await file.readAsString();
    if (!original.contains('MCPCallEntry')) {
      continue;
    }
    final migrated = migrator.migrateSource(original);
    final changed = migrated != original;
    results.add(
      MigrateAgentEntriesFileResult(
        path: file.path,
        changed: changed,
        migrated: migrated,
      ),
    );
    if (changed && write && !checkOnly) {
      await file.writeAsString(migrated);
    }
  }

  return MigrateAgentEntriesReport(
    filesScanned: dartFiles.length,
    filesChanged: results.where((final r) => r.changed).length,
    results: results,
  );
}

Future<int> runMigrateAgentEntries({
  required final String path,
  required final bool checkOnly,
  required final bool write,
  final String defaultNamespace = 'app',
}) async {
  if (checkOnly && write) {
    stderr.writeln('Use either --check or --write, not both.');
    return 64;
  }

  late final MigrateAgentEntriesReport report;
  try {
    report = await migrateAgentEntriesAtPath(
      path: path,
      write: write,
      checkOnly: checkOnly,
      defaultNamespace: defaultNamespace,
    );
  } on MigrateAgentEntriesPathNotFound catch (error) {
    stderr.writeln(error);
    return 66;
  }

  for (final result in report.results.where((final r) => r.changed)) {
    stdout.writeln('would migrate: ${result.path}');
    if (write && !checkOnly) {
      stdout.writeln('  wrote: ${result.path}');
    }
  }

  if (report.filesChanged == 0) {
    stdout.writeln(
      'OK: no MCPCallEntry migrations needed (${report.filesScanned} dart files scanned)',
    );
  } else {
    stdout.writeln(
      '${report.filesChanged} file(s) ${checkOnly || !write ? 'would change' : 'migrated'} '
      '(${report.filesScanned} dart files scanned)',
    );
  }

  if (checkOnly && report.wouldChange) {
    return 1;
  }
  return 0;
}
