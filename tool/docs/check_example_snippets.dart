// Verifies docs fences tagged with <!-- example-snippet: id --> match
// tool/docs/example_snippets.yaml (and optional source sentinel comments).
//
//   dart run tool/docs/check_example_snippets.dart
library;

import 'dart:io';

void main() {
  final repoRoot = Directory.current;
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('run from repository root');
    exit(1);
  }

  final entries = _loadManifest(
    File('tool/docs/example_snippets.yaml').readAsStringSync(),
  );
  if (entries.isEmpty) {
    stderr.writeln('example_snippets.yaml: no snippets');
    exit(1);
  }

  var failures = 0;
  for (final entry in entries) {
    final docPath = entry.doc;
    if (!File(docPath).existsSync()) {
      stderr.writeln('${entry.id}: missing doc ${entry.doc}');
      failures++;
      continue;
    }
    final fence = _extractFence(
      File(docPath).readAsStringSync(),
      entry.id,
      entry.language,
    );
    if (fence == null) {
      stderr.writeln(
        '${entry.id}: no fence after <!-- example-snippet: ${entry.id} -->',
      );
      failures++;
      continue;
    }
    final docLines = _normalizeLines(fence);
    final expected = _normalizeLines(entry.lines.join('\n'));
    if (docLines.join('\n') != expected.join('\n')) {
      stderr.writeln('${entry.id}: doc fence drift in ${entry.doc}');
      failures++;
    }
    if (entry.source != null) {
      final sourceFile = File(entry.source!);
      if (!sourceFile.existsSync()) {
        stderr.writeln('${entry.id}: missing source ${entry.source}');
        failures++;
        continue;
      }
      final sourceText = sourceFile.readAsStringSync();
      if (!sourceText.contains('example-snippet: ${entry.id}')) {
        stderr.writeln('${entry.id}: source missing sentinel comment');
        failures++;
        continue;
      }
      final fromSource = _linesAfterSentinel(sourceText, entry.id);
      if (fromSource.join('\n') != expected.join('\n')) {
        stderr.writeln('${entry.id}: source sentinel drift');
        failures++;
      }
    }
  }

  if (failures > 0) {
    stderr.writeln('check_example_snippets: $failures failure(s)');
    exit(1);
  }
  stdout.writeln('check_example_snippets: OK (${entries.length} snippets)');
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

List<_SnippetEntry> _loadManifest(String raw) {
  final entries = <_SnippetEntry>[];
  String? id;
  String? doc;
  String? language;
  String? source;
  final lines = <String>[];
  var inLines = false;

  void flush() {
    if (id != null && doc != null && lines.isNotEmpty) {
      entries.add(
        _SnippetEntry(
          id: id!,
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
  return entries;
}

List<String> _normalizeLines(String text) =>
    text.split('\n').map((l) => l.trimRight()).where((l) => l.isNotEmpty).toList();

String? _extractFence(String doc, String id, String lang) {
  final marker = '<!-- example-snippet: $id -->';
  final idx = doc.indexOf(marker);
  if (idx < 0) return null;
  final tail = doc.substring(idx + marker.length);
  final fenceStart = '```$lang';
  final openIdx = tail.indexOf(fenceStart);
  if (openIdx < 0) return null;
  var contentStart = openIdx + fenceStart.length;
  if (tail.length > contentStart && tail[contentStart] == '\n') {
    contentStart++;
  } else if (tail.length > contentStart + 1 &&
      tail[contentStart] == '\r' &&
      tail[contentStart + 1] == '\n') {
    contentStart += 2;
  }
  final afterOpen = tail.substring(contentStart);
  final close = afterOpen.indexOf('```');
  if (close < 0) return null;
  return afterOpen.substring(0, close).trimRight();
}

List<String> _linesAfterSentinel(String source, String id) {
  final lines = source.split('\n');
  final sentinel = 'example-snippet: $id';
  for (var i = 0; i < lines.length; i++) {
    if (!lines[i].contains(sentinel)) continue;
    final collected = <String>[];
    for (var j = i + 1; j < lines.length; j++) {
      final line = lines[j].trim();
      if (line.startsWith('///')) {
        collected.add(line.substring(3).trim());
        continue;
      }
      if (line.startsWith('//') && line.contains('dart run')) {
        collected.add(line.substring(2).trim());
        continue;
      }
      if (collected.isNotEmpty) break;
    }
    return _normalizeLines(collected.join('\n'));
  }
  return const [];
}