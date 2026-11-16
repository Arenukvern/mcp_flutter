// Validates repo doc paths: relative md/mdx, docs.page absolute /…, docs.json hrefs,
// steward path literals, and docs/… backtick paths in Dart/shell/skills.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

final repoRoot = Directory.current;
var broken = 0;

class AllowEntry {
  AllowEntry({
    required this.target,
    required this.citingFile,
    required this.reason,
  });
  final String target;
  final String citingFile;
  final String reason;
  bool used = false;

  static List<AllowEntry> load() {
    final file = File('${repoRoot.path}/tool/contracts/check_docs_links_allowlist.json');
    if (!file.existsSync()) return [];
    final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final entries = raw['entries'];
    if (entries is! List) return [];
  final out = <AllowEntry>[];
    for (final item in entries) {
      final e = item as Map<String, dynamic>;
      final citing = e['citingFile'];
      if (citing is! String || citing.isEmpty) {
        stderr.writeln(
          'check_docs_links: allowlist entry missing citingFile for target ${e['target']}',
        );
        exit(2);
      }
      out.add(
        AllowEntry(
          target: '${e['target']}',
          citingFile: citing,
          reason: '${e['reason']}',
        ),
      );
    }
    return out;
  }
}

late final List<AllowEntry> allowlist;

String repoRelativePath(String path) {
  final root = repoRoot.path;
  if (path == root) return '';
  if (path.startsWith('$root/')) {
    return path.substring(root.length + 1);
  }
  return path.replaceAll('\\', '/');
}

bool allowlisted(String citingFile, String target) {
  final relCiting = repoRelativePath(citingFile);
  for (final e in allowlist) {
    if (e.target != target || e.citingFile != relCiting) continue;
    e.used = true;
    return true;
  }
  return false;
}

void report(String msg, {String? citingFile, String? target}) {
  if (target != null && citingFile != null) {
    if (allowlisted(citingFile, target)) {
      return;
    }
  }
  stderr.writeln('check_docs_links: $msg');
  broken++;
}

bool isExternal(String href) {
  return href.startsWith('http://') ||
      href.startsWith('https://') ||
      href.startsWith('mailto:') ||
      href.startsWith('#');
}

File? resolveSiteAbsolute(String href) {
  var path = href.split('#').first.split('?').first;
  if (!path.startsWith('/')) return null;
  path = path.replaceFirst(RegExp(r'^/'), '');
  if (path.isEmpty) {
    return _firstExisting(['docs/index.mdx', 'docs/index.md']);
  }
  if (path == 'decisions') {
    return _firstExisting([
      'docs/decisions/index.mdx',
      'decisions/index.mdx',
    ]);
  }
  if (path.startsWith('docs/')) {
    final stripped = path.substring('docs/'.length);
    return _firstExisting([
      'docs/$stripped.mdx',
      'docs/$stripped.md',
      'docs/$stripped/index.mdx',
      path,
      '$path.mdx',
      '$path.md',
    ]);
  }
  var base = path;
  if (base.startsWith('decisions/')) {
    base = base.substring('decisions/'.length);
  }
  final candidates = <String>[
    if (path.contains('.mdx') || path.contains('.md'))
      ...['decisions/$path', 'docs/decisions/$path', path]
    else ...[
      'docs/$path.mdx',
      'docs/$path.md',
      'decisions/$path.mdx',
      'decisions/$path.md',
      'docs/decisions/$base.mdx',
      'docs/decisions/$base.md',
    ],
  ];
  return _firstExisting(candidates);
}

File? _firstExisting(List<String> relative) {
  for (final rel in relative) {
    final f = File('${repoRoot.path}/$rel');
    if (f.existsSync()) return f;
    final d = Directory('${repoRoot.path}/$rel');
    if (d.existsSync()) return File(d.path);
  }
  return null;
}

File? resolveRelative(String fromFile, String href) {
  var path = href.split('#').first.split('?').first;
  if (path.isEmpty || isExternal(path) || path.startsWith('/')) {
    return path.startsWith('/') ? resolveSiteAbsolute(path) : null;
  }
  if (path.startsWith('dist/')) return File('${repoRoot.path}/$path');
  final from = File(fromFile).parent;
  final resolved = from.uri.resolve(path).toFilePath();
  final f = File(resolved);
  if (f.existsSync()) return f;
  if (Directory(resolved).existsSync()) return File(resolved);
  return null;
}

final linkPatterns = [
  RegExp(r'\[[^\]]*\]\(([^)]+)\)'),
  RegExp(r'''<a\s+[^>]*href\s*=\s*["']([^"']+)["']''', caseSensitive: false),
  RegExp(r'\[[^\]]*\]:\s*(\S+)'),
];

void scanMarkdownFile(String path) {
  final relPath = repoRelativePath(path);
  final content = File(path).readAsStringSync();
  for (final re in linkPatterns) {
    for (final m in re.allMatches(content)) {
      final href = m.group(1)!.trim().replaceAll(RegExp(r'^<|>$'), '');
      if (isExternal(href)) continue;
      if (href.startsWith('/')) {
        if (resolveSiteAbsolute(href) == null) {
          report(
            '$relPath: broken site path -> $href',
            citingFile: relPath,
            target: href,
          );
        }
        continue;
      }
      if (resolveRelative(path, href) == null) {
        report(
          '$relPath: broken link -> $href',
          citingFile: relPath,
          target: href,
        );
      }
    }
  }
}

final docPathInSource = RegExp(
  r'''(?:(?:mcp_server_dart|packages/harness)/)?(?:docs/[a-zA-Z0-9_./-]+\.(?:mdx?|md)|maintainers/[a-zA-Z0-9_./-]+\.(?:mdx?|md|ya?ml)|decisions/[a-zA-Z0-9_./-]+\.mdx)''',
);

void scanDocPathLiterals(String path) {
  final relPath = repoRelativePath(path);
  final content = File(path)
      .readAsStringSync()
      .replaceAll(RegExp(r'https?://\S+'), ' ');
  for (final m in docPathInSource.allMatches(content)) {
    var p = m.group(0)!;
    final candidates = <String>[p];
    if (p.startsWith('docs/')) {
      candidates.add('mcp_server_dart/$p');
    }
    var found = false;
    for (final c in candidates) {
      final f = File('${repoRoot.path}/$c');
      final d = Directory('${repoRoot.path}/$c');
      if (f.existsSync() || d.existsSync()) {
        found = true;
        break;
      }
    }
    if (found) {
      if (allowlisted(relPath, p)) {
        report(
          '$relPath: stale allowlist entry (target exists) -> $p',
        );
      }
      continue;
    }
    if (allowlisted(relPath, p)) continue;
    report(
      '$relPath: broken doc path in source -> $p',
      citingFile: relPath,
      target: p,
    );
  }
}

void scanDocsJson() {
  final raw = File('${repoRoot.path}/docs.json').readAsStringSync();
  final json = jsonDecode(raw) as Map<String, dynamic>;
  void walk(dynamic node) {
    if (node is Map) {
      for (final e in node.entries) {
        if (e.key == 'href' && e.value is String) {
          final href = e.value as String;
          if (!isExternal(href) && href.startsWith('/')) {
            if (resolveSiteAbsolute(href) == null) {
              report('docs.json: broken href -> $href', target: href);
            }
          }
        } else {
          walk(e.value);
        }
      }
    } else if (node is List) {
      for (final item in node) {
        walk(item);
      }
    }
  }

  walk(json);
}

void scanStewardYaml() {
  final lines = File('${repoRoot.path}/steward.yaml').readAsLinesSync();
  for (final line in lines) {
    final m = RegExp(r'^\s+-\s+(.+)$').firstMatch(line);
    if (m == null) continue;
    final entry = m.group(1)!.trim();
    if (!entry.startsWith('docs/') &&
        !entry.startsWith('maintainers/') &&
        !entry.startsWith('decisions/') &&
        !entry.endsWith('.mdx') &&
        !entry.endsWith('.md')) {
      continue;
    }
    if (entry.contains('*')) continue;
    final f = File('${repoRoot.path}/$entry');
    final d = Directory('${repoRoot.path}/$entry');
    if (!f.existsSync() && !d.existsSync()) {
      report('steward.yaml: missing effects path -> $entry', target: entry);
    }
  }
}

void walkDir(String dir, void Function(String path) onFile) {
  final d = Directory('${repoRoot.path}/$dir');
  if (!d.existsSync()) return;
  for (final entity in d.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final p = entity.path;
    if (p.contains('/.git/') || p.contains('node_modules')) continue;
    onFile(p);
  }
}

void scanTreeForLiterals(String rel) {
  final entity = FileSystemEntity.typeSync('${repoRoot.path}/$rel');
  if (entity == FileSystemEntityType.notFound) return;
  if (entity == FileSystemEntityType.file) {
    scanDocPathLiterals(rel);
    if (rel.endsWith('.md') || rel.endsWith('.mdx')) {
      scanMarkdownFile('${repoRoot.path}/$rel');
    }
    return;
  }
  for (final f in Directory('${repoRoot.path}/$rel').listSync(recursive: true)) {
    if (f is! File) continue;
    final name = f.path;
    if (name.contains('/.git/') || name.contains('node_modules')) continue;
    if (name.contains('/tool/contracts/check_docs_links.dart')) continue;
    final relPath = name.replaceFirst('${repoRoot.path}/', '');
    if (relPath.contains('tool/contracts/fixtures/')) continue;
    if (relPath.endsWith('tool/contracts/test_docs_links_fixtures.sh')) continue;
    if (name.endsWith('.dart') ||
        name.endsWith('.sh') ||
        name.endsWith('.md') ||
        name.endsWith('.mdx') ||
        name.endsWith('.yaml') ||
        name.endsWith('.yml')) {
      scanDocPathLiterals(relPath);
    }
    if (name.endsWith('.md') || name.endsWith('.mdx')) {
      scanMarkdownFile(name);
    }
  }
}

Future<void> main() async {
  allowlist = AllowEntry.load();

  for (final root in ['docs', 'plugin', 'skills', 'maintainers', 'decisions']) {
    walkDir(root, (p) {
      if (p.endsWith('.md') || p.endsWith('.mdx')) scanMarkdownFile(p);
    });
  }

  for (final sub in ['.cursor']) {
    walkDir(sub, (p) {
      if (p.endsWith('.md') || p.endsWith('.mdx')) scanMarkdownFile(p);
    });
  }

  for (final f in [
    'README.md',
    'AGENTS.md',
    'CONTRIBUTING.md',
    'mcp_toolkit/README.md',
    'mcp_server_dart/README.md',
    'llms.txt',
    'docs/llms.txt',
  ]) {
    final file = File('${repoRoot.path}/$f');
    if (file.existsSync()) {
      if (f.endsWith('.md') || f.endsWith('.mdx')) {
        scanMarkdownFile(file.path);
      } else {
        scanDocPathLiterals(f);
      }
    }
  }

  if (Directory('${repoRoot.path}/packages').existsSync()) {
    for (final pkg in Directory('${repoRoot.path}/packages').listSync()) {
      if (pkg is! Directory) continue;
      final readme = File('${pkg.path}/README.md');
      if (readme.existsSync()) scanMarkdownFile(readme.path);
    }
  }

  for (final dir in [
    'mcp_toolkit/lib',
    'mcp_server_dart/bin',
    'mcp_server_dart/lib',
    'mcp_server_dart/test',
    'mcp_server_dart/tool',
    'tool',
    'plugin/skills',
    'skills',
    'showcase',
  ]) {
    scanTreeForLiterals(dir);
  }

  if (File('${repoRoot.path}/steward.yaml').existsSync()) {
    scanStewardYaml();
    scanDocPathLiterals('steward.yaml');
  }
  if (File('${repoRoot.path}/docs.json').existsSync()) {
    scanDocsJson();
  }

  for (final e in allowlist) {
    if (!e.used) {
      report(
        'allowlist: unused entry target=${e.target}'
        ' citingFile=${e.citingFile} (${e.reason})',
      );
    }
  }

  if (broken > 0) {
    stderr.writeln('check_docs_links: $broken problem(s)');
    exit(1);
  }
  print('check_docs_links: OK');
}