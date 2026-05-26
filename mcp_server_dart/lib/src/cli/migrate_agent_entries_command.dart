// mcp_server_dart/lib/src/cli/migrate_agent_entries_command.dart
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
/// - Complex [ObjectSchema] trees become empty object schemas; refine manually.
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

  String _transformFactoryCalls(final String source, {required final String kind}) {
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

  String _transformSingleFactory(final String call, {required final String kind}) {
    final definitionKind = kind == 'tool' ? 'MCPToolDefinition' : 'MCPResourceDefinition';
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
        _extractStringField(definitionBody, 'description') ?? 'Migrated MCPCallEntry';
    final mimeType = kind == 'resource'
        ? (_extractStringField(definitionBody, 'mimeType') ?? 'application/json')
        : null;

    final handlerPrefix = call.substring(defClose + 1);
    final handlerMatch = RegExp(r'handler:\s*').firstMatch(handlerPrefix);
    if (handlerMatch == null) {
      return call.replaceFirst('MCPCallEntry.$kind', 'AgentCallEntry.$kind');
    }

    final handlerStartInCall = defClose + 1 + handlerMatch.end;
    var handlerSource = call.substring(handlerStartInCall).trim();
    if (handlerSource.endsWith(',')) {
      handlerSource = handlerSource.substring(0, handlerSource.length - 1).trim();
    }
    final migratedHandler = _migrateHandler(handlerSource);

    final handlerLines = migratedHandler.split('\n').asMap().entries.map((final entry) {
      if (entry.key == 0) {
        return entry.value;
      }
      return '    ${entry.value}';
    }).join('\n');

    final buffer = StringBuffer('AgentCallEntry.$kind(\n')
      ..writeln("    namespace: '$defaultNamespace',")
      ..writeln("    name: '$name',")
      ..writeln("    description: '$description',")
      ..writeln('    inputSchema: const {')
      ..writeln("      'type': 'object',")
      ..writeln("      'properties': <String, Object?>{},");
    if (kind == 'resource') {
      buffer
        ..writeln('    },')
        ..writeln("    mimeType: '$mimeType',");
    } else {
      buffer.writeln('    },');
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

    final blockFn = RegExp(r'^\(([^)]*)\)\s*(async\s*)?\{', dotAll: true).firstMatch(handler);
    if (blockFn != null) {
      final params = blockFn.group(1) ?? 'final request';
      final openBrace = handler.indexOf('{', blockFn.start);
      final closeBrace = _matchingBraceIndex(handler, openBrace);
      if (closeBrace != null) {
        final body = handler.substring(openBrace + 1, closeBrace).trim();
        return _wrapHandlerBody(params, body, hasExistingReturn: body.contains('return '));
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
    final bodyLines = body.split('\n').map((final line) {
      if (line.trim().isEmpty) {
        return '';
      }
      return '  $line';
    }).join('\n');

    final buffer = StringBuffer('(final args) async {\n')
      ..writeln('  final $paramName = args.map(')
      ..writeln(
        "    (final key, final value) => MapEntry(key, value?.toString() ?? ''),",
      )
      ..writeln('  );');

    if (hasExistingReturn) {
      buffer.writeln(bodyLines);
      buffer.writeln('  if (_result is Map<String, Object?>) {');
      buffer.writeln("    final message = _result['message'] as String? ?? '';");
      buffer.writeln(
        "    final data = Map<String, Object?>.from(_result)..remove('message');",
      );
      buffer.writeln('    return AgentResult.success(message: message, data: data);');
      buffer.writeln('  }');
      buffer.writeln("  return AgentResult.success(message: '$paramName handled');");
    } else {
      buffer
        ..writeln(bodyLines)
        ..writeln("  final message = _result['message'] as String? ?? '';")
        ..writeln("  final data = Map<String, Object?>.from(_result)..remove('message');")
        ..writeln('  return AgentResult.success(message: message, data: data);');
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

  String _fixImports(final String source) {
    if (!source.contains('AgentCallEntry') && !source.contains('AgentResult')) {
      return source;
    }

    var output = source;
    final hasAgentkitCore = output.contains("import 'package:agentkit_core/agentkit_core.dart';");
    final hasAgentkitSchema =
        output.contains("import 'package:agentkit_schema/agentkit_schema.dart';");

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
        imports.writeln("import 'package:agentkit_schema/agentkit_schema.dart';");
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

  final migrator = MigrateAgentEntriesMigrator(defaultNamespace: defaultNamespace);
  final dartFiles = <File>[];
  if (target == FileSystemEntityType.file) {
    if (p.extension(path) == '.dart') {
      dartFiles.add(File(path));
    }
  } else {
    await for (final entity in Directory(path).list(recursive: true, followLinks: false)) {
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
