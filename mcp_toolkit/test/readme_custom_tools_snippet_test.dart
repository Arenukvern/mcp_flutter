import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String packageRoot() {
  final cwd = Directory.current.path;
  if (File('$cwd/pubspec.yaml').existsSync()) return cwd;
  return File(Platform.script.toFilePath()).parent.parent.path;
}

String extractDartFence(String contents, {String? mustContain}) {
  final re = RegExp(r'```dart[^\n]*\n([\s\S]*?)\n```', multiLine: true);
  for (final m in re.allMatches(contents)) {
    final block = m.group(1)!;
    if (mustContain == null || block.contains(mustContain)) return block;
  }
  throw StateError(
    'No ```dart fence found${mustContain != null ? ' containing $mustContain' : ''}',
  );
}

String stripImports(String block) {
  return block
      .split('\n')
      .where((line) => !line.trim().startsWith('import '))
      .join('\n');
}

String wrapForAnalyze(String block, {bool includeFlutterShell = false}) {
  var stripped = stripImports(block).trim();
  final String body;
  if (RegExp(r'Future<void>\s+main\s*\(\)\s*async').hasMatch(stripped)) {
    body = stripped.replaceFirst(
      RegExp(r'Future<void>\s+main\s*\(\)\s*async\s*'),
      'Future<void> probe() async ',
    );
  } else {
    body = '''
Future<void> probe() async {
  final binding = MCPToolkitBinding.instance;
$stripped
}
''';
  }
  final flutterShell = includeFlutterShell
      ? '''
import 'package:flutter/material.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox();
}

'''
      : '';
  return '''
import 'package:mcp_toolkit/mcp_toolkit.dart';
$flutterShell
$body
''';
}

Future<void> analyzeSnippet(String packageRoot, String wrapped) async {
  final dir = Directory('$packageRoot/.dart_tool/readme_snippet_probe');
  if (dir.existsSync()) {
    dir.deleteSync(recursive: true);
  }
  dir.createSync(recursive: true);
  final file = File('${dir.path}/snippet_probe.dart');
  file.writeAsStringSync(wrapped);
  final result = await Process.run(
    'dart',
    ['analyze', file.path],
    workingDirectory: packageRoot,
    environment: {...Platform.environment, 'DART_SUPPRESS_ANALYTICS': 'true'},
  );
  if (result.exitCode != 0) {
    throw TestFailure(
      'README snippet analyze failed (exit ${result.exitCode}):\n'
      '${result.stdout}\n${result.stderr}',
    );
  }
}

void main() {
  test('mcp_toolkit README custom-tools dart fence type-checks', () async {
    final root = packageRoot();
    final block = extractDartFence(
      File('$root/README.md').readAsStringSync(),
      mustContain: 'AgentCallEntry.tool',
    );
    await analyzeSnippet(
      root,
      wrapForAnalyze(block, includeFlutterShell: true),
    );
  });

  test('docs/use-cases/custom-tools.mdx dart fence type-checks', () async {
    final root = packageRoot();
    final repoRoot = Directory('$root/..').absolute.path;
    final block = extractDartFence(
      File('$repoRoot/docs/use-cases/custom-tools.mdx').readAsStringSync(),
      mustContain: 'inputSchema',
    );
    await analyzeSnippet(root, wrapForAnalyze(block, includeFlutterShell: true));
  });
}