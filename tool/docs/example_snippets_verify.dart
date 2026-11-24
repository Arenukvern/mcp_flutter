// Shared verification for docs ↔ example snippet contract.
library;

import 'dart:io';

final class ExampleSnippetsResult {
  ExampleSnippetsResult({required this.errors, required this.snippetCount});

  final List<String> errors;
  final int snippetCount;

  bool get ok => errors.isEmpty;
}

ExampleSnippetsResult verifyExampleSnippets({
  required Directory repoRoot,
  String manifestPath = 'tool/docs/example_snippets.yaml',
  bool scanOrphanTags = true,
}) {
  final errors = <String>[];
  final manifestFile = File('${repoRoot.path}/$manifestPath');
  if (!manifestFile.existsSync()) {
    return ExampleSnippetsResult(
      errors: ['missing manifest $manifestPath'],
      snippetCount: 0,
    );
  }

  final load = _loadManifest(manifestFile.readAsStringSync());
  errors.addAll(load.manifestErrors);
  final entries = load.entries;

  if (entries.isEmpty && load.manifestErrors.isEmpty) {
    errors.add('example_snippets.yaml: no snippets');
  }

  final manifestIds = entries.map((e) => e.id).toSet();

  for (final entry in entries) {
    final docPath = '${repoRoot.path}/${entry.doc}';
    if (!File(docPath).existsSync()) {
      errors.add('${entry.id}: missing doc ${entry.doc}');
      continue;
    }
    final fence = _extractFence(
      File(docPath).readAsStringSync(),
      entry.id,
      entry.language,
    );
    if (fence == null) {
      errors.add(
        '${entry.id}: no fence after <!-- example-snippet: ${entry.id} -->',
      );
      continue;
    }
    final docLines = _normalizeLines(fence);
    final expected = _normalizeLines(entry.lines.join('\n'));
    if (docLines.join('\n') != expected.join('\n')) {
      errors.add('${entry.id}: doc fence drift in ${entry.doc}');
    }
    if (entry.source != null) {
      final sourceFile = File('${repoRoot.path}/${entry.source!}');
      if (!sourceFile.existsSync()) {
        errors.add('${entry.id}: missing source ${entry.source}');
        continue;
      }
      final sourceText = sourceFile.readAsStringSync();
      if (!sourceText.contains('example-snippet: ${entry.id}')) {
        errors.add('${entry.id}: source missing sentinel comment');
        continue;
      }
      final fromSource = _linesAfterSentinel(sourceText, entry.id);
      if (fromSource.join('\n') != expected.join('\n')) {
        errors.add('${entry.id}: source sentinel drift');
      }
    }
  }

  if (scanOrphanTags) {
    errors.addAll(_orphanSnippetTags(repoRoot, manifestIds));
  }

  return ExampleSnippetsResult(errors: errors, snippetCount: entries.length);
}

final class _ManifestLoad {
  _ManifestLoad({required this.entries, required this.manifestErrors});

  final List<_SnippetEntry> entries;
  final List<String> manifestErrors;
}

final class _SnippetEntry {
  _SnippetEntry({
    required this.id,
    required this.doc,
    required this.language,
    required this.lines,
    this.source,
  });

  final String id;
  final String doc;
  final String language;
  final List<String> lines;
  final String? source;
}

_ManifestLoad _loadManifest(String raw) {
  final entries = <_SnippetEntry>[];
  final manifestErrors = <String>[];
  String? id;
  String? doc;
  String? language;
  String? source;
  final lines = <String>[];
  var inLines = false;

  void flush() {
    if (id == null) {
      return;
    }
    final snippetId = id!;
    if (doc == null) {
      manifestErrors.add('snippet $snippetId: missing doc');
    } else if (lines.isEmpty) {
      manifestErrors.add('snippet $snippetId: missing lines');
    } else {
      entries.add(
        _SnippetEntry(
          id: snippetId,
          doc: doc!,
          language: language ?? 'bash',
          lines: List<String>.from(lines),
          source: source,
        ),
      );
    }
    id = null;
    doc = null;
    language = null;
    source = null;
    lines.clear();
    inLines = false;
  }

  for (final line in raw.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.startsWith('- id:')) {
      flush();
      id = trimmed.substring(5).trim();
      if (id!.isEmpty) {
        manifestErrors.add('snippet entry with empty id');
        id = null;
      }
    } else if (trimmed.startsWith('doc:')) {
      doc = trimmed.substring(4).trim();
    } else if (trimmed.startsWith('language:')) {
      language = trimmed.substring(9).trim();
    } else if (trimmed.startsWith('source:')) {
      source = trimmed.substring(7).trim();
    } else if (trimmed.startsWith('lines:')) {
      inLines = true;
    } else if (inLines && trimmed.startsWith('- ')) {
      var value = trimmed.substring(2).trim();
      if (value.startsWith('"') && value.endsWith('"')) {
        value = value.substring(1, value.length - 1);
      }
      lines.add(value);
    } else if (inLines && trimmed.isNotEmpty && !trimmed.startsWith('-')) {
      inLines = false;
    }
  }
  flush();
  return _ManifestLoad(entries: entries, manifestErrors: manifestErrors);
}

List<String> _orphanSnippetTags(Directory repoRoot, Set<String> manifestIds) {
  final errors = <String>[];
  final docsDir = Directory('${repoRoot.path}/docs');
  if (!docsDir.existsSync()) {
    return errors;
  }
  final tagRe = RegExp(r'<!--\s*example-snippet:\s*([^\s>]+)\s*-->');
  for (final entity in docsDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.mdx')) {
      continue;
    }
    final rel = entity.path
        .substring(repoRoot.path.length + 1)
        .replaceAll('\\', '/');
    final content = entity.readAsStringSync();
    for (final match in tagRe.allMatches(content)) {
      final tagId = match.group(1)!;
      if (!manifestIds.contains(tagId)) {
        errors.add('orphan snippet tag $tagId in $rel (not in manifest)');
      }
    }
  }
  return errors;
}

List<String> _normalizeLines(String text) => text
    .split('\n')
    .map((l) => l.trimRight())
    .where((l) => l.isNotEmpty)
    .toList();

String? _extractFence(String doc, String id, String lang) {
  final marker = '<!-- example-snippet: $id -->';
  final idx = doc.indexOf(marker);
  if (idx < 0) {
    return null;
  }
  final tail = doc.substring(idx + marker.length);
  final fenceStart = '```$lang';
  final openIdx = tail.indexOf(fenceStart);
  if (openIdx < 0) {
    return null;
  }
  var contentStart = openIdx + fenceStart.length;
  if (tail.length > contentStart && tail[contentStart] == '\n') {
    contentStart++;
  } else if (tail.length > contentStart + 1 &&
      tail[contentStart] == '\r' &&
      tail[contentStart + 1] == '\n') {
    contentStart += 2;
  }
  final afterOpen = tail.substring(contentStart);
  final bodyLines = <String>[];
  for (final line in afterOpen.split('\n')) {
    if (_isMarkdownClosingFence(line)) {
      return bodyLines.join('\n').trimRight();
    }
    bodyLines.add(line);
  }
  return null;
}

bool _isMarkdownClosingFence(String line) {
  final trimmed = line.trimRight();
  if (trimmed.length < 3 || !trimmed.startsWith('```')) {
    return false;
  }
  final afterMarker = trimmed.substring(3);
  return afterMarker.isEmpty || RegExp(r'^[ \t]*$').hasMatch(afterMarker);
}

List<String> _linesAfterSentinel(String source, String id) {
  final lines = source.split('\n');
  final startToken = 'example-snippet: $id';
  final endToken = 'example-snippet-end: $id';
  for (var i = 0; i < lines.length; i++) {
    if (!lines[i].contains(startToken)) {
      continue;
    }
    final collected = <String>[];
    for (var j = i + 1; j < lines.length; j++) {
      final trimmed = lines[j].trim();
      if (trimmed.contains(endToken)) {
        break;
      }
      if (trimmed.startsWith('///')) {
        final body = trimmed.substring(3).trim();
        if (body.isEmpty) {
          continue;
        }
        if (body.contains('example-snippet-end:')) {
          break;
        }
        collected.add(body);
        continue;
      }
      if (collected.isNotEmpty) {
        break;
      }
    }
    return _normalizeLines(collected.join('\n'));
  }
  return const [];
}

/// Test hook: load manifest only.
ExampleSnippetsResult verifyManifestText(String yaml) {
  final load = _loadManifest(yaml);
  if (load.manifestErrors.isNotEmpty) {
    return ExampleSnippetsResult(
      errors: List.from(load.manifestErrors),
      snippetCount: load.entries.length,
    );
  }
  return ExampleSnippetsResult(errors: [], snippetCount: load.entries.length);
}
