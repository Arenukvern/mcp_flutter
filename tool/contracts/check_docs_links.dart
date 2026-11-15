// Validates repo doc paths: relative md/mdx, docs.page absolute /…, docs.json hrefs,
// steward path literals, and docs/… backtick paths in Dart/shell/skills.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

final repoRoot = Directory.current;
var broken = 0;

void report(String msg) {
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
    return _firstExisting(['$path.mdx', '$path.md', path]);
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
  ],
  ];
  return _firstExisting(candidates);
}

File? _firstExisting(List<String> relative) {
  for (final rel in relative) {
    final f = File('${repoRoot.path}/$rel');
    if (f.existsSync()) return f;
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
  final content = File(path).readAsStringSync();
  for (final re in linkPatterns) {
    for (final m in re.allMatches(content)) {
      final href = m.group(1)!.trim().replaceAll(RegExp(r'^<|>$'), '');
      if (isExternal(href)) continue;
      if (href.startsWith('/')) {
        if (resolveSiteAbsolute(href) == null) {
          report('$path: broken site path -> $href');
        }
        continue;
      }
      if (resolveRelative(path, href) == null) {
        report('$path: broken link -> $href');
      }
    }
  }
}

final docPathInSource = RegExp(
  r'''(?:docs/[a-zA-Z0-9_./-]+\.(?:mdx?|md)|maintainers/[a-zA-Z0-9_./-]+\.(?:mdx?|md|ya?ml)|decisions/[a-zA-Z0-9_./-]+\.mdx)''',
);

void scanDocPathLiterals(String path) {
  final content = File(path).readAsStringSync();
  for (final m in docPathInSource.allMatches(content)) {
    final p = m.group(0)!;
    if (!File('${repoRoot.path}/$p').existsSync()) {
      report('$path: broken doc path in source -> $p');
    }
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
              report('docs.json: broken href -> $href');
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
      report('steward.yaml: missing effects path -> $entry');
    }
  }
}

Future<void> main() async {
  final mdRoots = <String>[
    'docs',
    'plugin',
    'skills',
    '.agents',
    '.cursor',
    'maintainers',
    'README.md',
    'AGENTS.md',
    'CONTRIBUTING.md',
    'mcp_toolkit/README.md',
    'llms.txt',
    'docs/llms.txt',
  ];

  void walkDir(String dir) {
    final d = Directory('${repoRoot.path}/$dir');
    if (!d.existsSync()) return;
    for (final entity in d.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final p = entity.path;
      if (p.contains('/.git/') || p.contains('node_modules')) continue;
      if (p.endsWith('.md') || p.endsWith('.mdx')) {
        scanMarkdownFile(p);
      }
    }
  }

  for (final root in ['docs', 'plugin', 'skills', 'maintainers']) {
    walkDir(root);
  }
  for (final f in ['README.md', 'AGENTS.md', 'CONTRIBUTING.md', 'mcp_toolkit/README.md']) {
    final file = File('${repoRoot.path}/$f');
    if (file.existsSync()) scanMarkdownFile(file.path);
  }

  final literalGlobs = [
    'mcp_toolkit/lib',
    'mcp_toolkit/README.md',
    'mcp_server_dart/bin',
    'mcp_server_dart/lib',
    'mcp_server_dart/test',
    'mcp_server_dart/tool',
    'tool',
    'plugin/skills',
    'skills',
    '.agents/skills',
    'steward.yaml',
    'showcase',
  ];

  for (final dir in literalGlobs) {
    final target = File('${repoRoot.path}/$dir');
    if (target.existsSync() && target is File) {
      scanDocPathLiterals(target.path);
      continue;
    }
    if (!target.existsSync()) continue;
    for (final entity in Directory(target.path).listSync(recursive: true)) {
      if (entity is! File) continue;
      final name = entity.path;
      if (name.endsWith('.dart') ||
          name.endsWith('.sh') ||
          name.endsWith('.md') ||
          name.endsWith('.mdx') ||
          name.endsWith('.yaml') ||
          name.endsWith('.yml')) {
        scanDocPathLiterals(name);
      }
    }
  }

  if (File('${repoRoot.path}/steward.yaml').existsSync()) {
    scanStewardYaml();
  }
  if (File('${repoRoot.path}/docs.json').existsSync()) {
    scanDocsJson();
  }

  if (broken > 0) {
    stderr.writeln('check_docs_links: $broken problem(s)');
    exit(1);
  }
  print('check_docs_links: OK');
}