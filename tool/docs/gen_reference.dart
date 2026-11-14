#!/usr/bin/env dart
// Generates docs/reference/*.mdx from live MCP server + CLI help + skill frontmatter.
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

final _repoRoot = Directory(
  Platform.script.resolve('../..').toFilePath(),
);
final _serverDir = Directory('${_repoRoot.path}/mcp_server_dart');
final _outDir = Directory('${_repoRoot.path}/docs/reference');
final _skillsRoot = Directory('${_repoRoot.path}/plugin/skills');

const _cliHelpCommands = <List<String>>[
  [],
  ['exec'],
  ['batch'],
  ['schema'],
  ['capabilities'],
  ['serve'],
  ['snapshot'],
  ['snapshot', 'create'],
  ['snapshot', 'diff'],
  ['bundle'],
  ['bundle', 'create'],
  ['doctor'],
  ['permissions'],
  ['permissions', 'status'],
  ['validate-runtime'],
  ['init'],
  ['codegen-init'],
  ['migrate'],
  ['migrate', 'agent-entries'],
  ['codegen'],
  ['codegen', 'sync'],
  ['webmcp'],
  ['webmcp', 'chrome-args'],
  ['webmcp', 'verify'],
];

Future<void> main(List<String> args) async {
  await _outDir.create(recursive: true);

  final defaultTools = await _probeServerTools(dumps: false);
  final dumpsTools = await _probeServerTools(dumps: true);
  final defaultResources = await _probeServerResources(dumps: false);
  final templates = await _probeResourceTemplates();

  await File('${_outDir.path}/tools.mdx').writeAsString(
    _renderToolsMdx(defaultTools, dumpsTools),
  );
  await File('${_outDir.path}/resources.mdx').writeAsString(
    _renderResourcesMdx(defaultResources, templates),
  );
  await File('${_outDir.path}/cli.mdx').writeAsString(await _renderCliMdx());
  await File('${_outDir.path}/server-flags.mdx').writeAsString(
    await _renderServerFlagsMdx(),
  );
  await File('${_outDir.path}/skills.mdx').writeAsString(_renderSkillsMdx());
  await File('${_outDir.path}/errors.mdx').writeAsString(_renderErrorsMdx());

  print('OK: wrote ${_outDir.path} (${defaultTools.length} default tools, '
      '${dumpsTools.length} with --dumps)');
}

Future<List<Map<String, dynamic>>> _probeServerTools({
  required bool dumps,
}) async {
  final extraArgs = dumps ? <String>['--dumps'] : <String>[];
  final client = await _McpStdioClient.start(extraArgs: extraArgs);
  try {
    await client.initialize();
    final result = await client.request('tools/list', {});
    final tools = (result['tools'] as List?)?.cast<Map<String, dynamic>>() ??
        const [];
    tools.sort(
      (a, b) => '${a['name']}'.compareTo('${b['name']}'),
    );
    return tools;
  } finally {
    await client.close();
  }
}

Future<List<Map<String, dynamic>>> _probeServerResources({
  required bool dumps,
}) async {
  final extraArgs = dumps ? <String>['--dumps'] : <String>[];
  final client = await _McpStdioClient.start(extraArgs: extraArgs);
  try {
    await client.initialize();
    final result = await client.request('resources/list', {});
    final resources =
        (result['resources'] as List?)?.cast<Map<String, dynamic>>() ??
            const [];
    resources.sort(
      (a, b) => '${a['uri']}'.compareTo('${b['uri']}'),
    );
    return resources;
  } finally {
    await client.close();
  }
}

Future<List<Map<String, dynamic>>> _probeResourceTemplates() async {
  final client = await _McpStdioClient.start();
  try {
    await client.initialize();
    final result = await client.request('resources/templates/list', {});
    return (result['resourceTemplates'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        const [];
  } finally {
    await client.close();
  }
}

String _renderToolsMdx(
  List<Map<String, dynamic>> defaultTools,
  List<Map<String, dynamic>> dumpsTools,
) {
  final dumpsOnly = dumpsTools
      .where((t) => !defaultTools.any((d) => d['name'] == t['name']))
      .toList();
  final buf = StringBuffer()
    ..writeln('---')
    ..writeln('title: MCP tools (generated)')
    ..writeln('description: Live tools/list from flutter-mcp-toolkit-server.')
    ..writeln('---')
    ..writeln()
    ..writeln(
      '> **Generated.** Regenerate with `make docs-reference`. Do not edit by hand.',
    )
    ..writeln()
    ..writeln(
      'Default server exposes **${defaultTools.length}** `fmt_*` tools. '
      'With `--dumps`, **${dumpsTools.length}** tools (adds ${dumpsOnly.length} debug dump tools).',
    )
  ..writeln()
    ..writeln('## Default tools')
    ..writeln();
  for (final tool in defaultTools) {
    _appendTool(buf, tool);
  }
  if (dumpsOnly.isNotEmpty) {
    buf
      ..writeln('## Additional tools with `--dumps`')
      ..writeln();
    for (final tool in dumpsOnly) {
      _appendTool(buf, tool);
    }
  }
  return buf.toString();
}

void _appendTool(StringBuffer buf, Map<String, dynamic> tool) {
  final name = tool['name'];
  final description = tool['description'] ?? '';
  buf
    ..writeln('### `$name`')
    ..writeln()
    ..writeln(description)
    ..writeln();
  final schema = tool['inputSchema'];
  if (schema is Map && schema.isNotEmpty) {
    buf
      ..writeln('```json')
      ..writeln(const JsonEncoder.withIndent('  ').convert(schema))
      ..writeln('```')
      ..writeln();
  }
}

String _renderResourcesMdx(
  List<Map<String, dynamic>> resources,
  List<Map<String, dynamic>> templates,
) {
  final buf = StringBuffer()
    ..writeln('---')
    ..writeln('title: MCP resources (generated)')
    ..writeln('---')
    ..writeln()
    ..writeln('> Generated by `make docs-reference`.')
    ..writeln()
    ..writeln('## Static resources (${resources.length})')
    ..writeln();
  for (final r in resources) {
    buf
      ..writeln('- `${r['uri']}` — ${r['name'] ?? r['description'] ?? ''}')
      ..writeln();
  }
  if (templates.isNotEmpty) {
    buf
      ..writeln('## Resource templates (${templates.length})')
      ..writeln();
    for (final t in templates) {
      buf
        ..writeln('- `${t['uriTemplate']}` — ${t['name'] ?? ''}')
        ..writeln();
    }
  }
  return buf.toString();
}

Future<String> _renderServerFlagsMdx() async {
  final help = await _cliRun(
    <String>['run', 'bin/flutter_mcp_toolkit_server.dart', '--help'],
    dir: _serverDir,
  );
  return '''
---
title: Server flags (generated)
---

> Generated by \`make docs-reference\`.

\`\`\`text
${help.trim()}
\`\`\`
''';
}

Future<String> _renderCliMdx() async {
  final sections = <String>[];
  for (final path in _cliHelpCommands) {
    final args = <String>['run', 'bin/flutter_mcp_toolkit.dart'];
  if (path.isNotEmpty) {
      args.addAll(path);
    }
    args.add('--help');
    final help = await _cliRun(args, dir: _serverDir);
    final title =
        path.isEmpty ? 'Global help' : 'flutter-mcp-toolkit ${path.join(' ')}';
    sections.add('## $title\n\n```text\n${help.trim()}\n```\n');
  }
  return '''
---
title: CLI reference (generated)
---

> Generated by \`make docs-reference\` from live \`--help\` output.

${sections.join('\n')}
''';
}

Future<String> _cliRun(List<String> args, {required Directory dir}) async {
  final result = await Process.run(
    'dart',
    args,
    workingDirectory: dir.path,
    environment: {'HOME': '/tmp', 'DART_SUPPRESS_ANALYTICS': 'true'},
  );
  if (result.exitCode != 0) {
    stderr.writeln(result.stderr);
    throw StateError('dart ${args.join(" ")} failed (${result.exitCode})');
  }
  return '${result.stdout}';
}

String _renderSkillsMdx() {
  final skills = <Map<String, String>>[];
  if (_skillsRoot.existsSync()) {
    for (final entity in _skillsRoot.listSync()) {
      if (entity is! Directory) continue;
      final skillFile = File('${entity.path}/SKILL.md');
      if (!skillFile.existsSync()) continue;
      final content = skillFile.readAsStringSync();
      final meta = _parseYamlFrontmatter(content);
      skills.add({
        'id': entity.path.split(Platform.pathSeparator).last,
        'name': meta['name'] ?? entity.path.split(Platform.pathSeparator).last,
        'description': meta['description'] ?? '',
      });
    }
  }
  skills.sort((a, b) => a['id']!.compareTo(b['id']!));
  final buf = StringBuffer()
    ..writeln('---')
    ..writeln('title: Bundled skills (generated)')
    ..writeln('---')
    ..writeln()
    ..writeln('> Generated by `make docs-reference`. Installed via `flutter-mcp-toolkit init`.')
    ..writeln();
  for (final s in skills) {
    buf
      ..writeln('### `${s['id']}`')
      ..writeln()
      ..writeln(s['description'])
      ..writeln();
  }
  return buf.toString();
}

Map<String, String> _parseYamlFrontmatter(String content) {
  if (!content.startsWith('---')) return {};
  final end = content.indexOf('---', 3);
  if (end < 0) return {};
  final block = content.substring(3, end).trim();
  final map = <String, String>{};
  for (final line in block.split('\n')) {
    final idx = line.indexOf(':');
    if (idx <= 0) continue;
    final key = line.substring(0, idx).trim();
    var value = line.substring(idx + 1).trim();
    if (value.startsWith('"') && value.endsWith('"')) {
      value = value.substring(1, value.length - 1);
    }
    map[key] = value;
  }
  return map;
}

String _renderErrorsMdx() {
  return '''
---
title: Structured errors
---

Toolkit MCP tools return JSON envelopes with `ok`, `errorCode`, and retry hints.
Common codes:

| Code | Typical cause | Fix |
| --- | --- | --- |
| `connection_selection_required` | Multiple debug targets | Pass `connection.uri` or `connection.targetId` from `discover_debug_apps` |
| `target_not_found` | Stale VM URI | Re-run app; paste fresh `ws://…/ws` from Flutter machine output |
| `connect_failed` | App not in debug / wrong port | `flutter run --debug`; confirm `mcp_toolkit` bootstrap in `main()` |
| `invalid_command` | Bad CLI args | `flutter-mcp-toolkit <cmd> --help` |
| `missing_extension` | App missing `mcp_toolkit` init | Run `codegen-init`, paste snippet, hot **restart** |

Full catalogs live in installed skills (`flutter-mcp-toolkit-debug`, `flutter-mcp-toolkit-control`) and in server responses.
''';
}

class _McpStdioClient {
  _McpStdioClient._(this._process, this._responses);

  final Process _process;
  final Stream<Map<String, dynamic>> _responses;
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  var _nextId = 1;
  late final StreamSubscription<void> _sub;

  static Future<_McpStdioClient> start({List<String> extraArgs = const []}) async {
    final process = await Process.start(
      'dart',
      [
        'run',
        'bin/flutter_mcp_toolkit_server.dart',
        ...extraArgs,
      ],
      workingDirectory: _serverDir.path,
      environment: {'HOME': '/tmp', 'DART_SUPPRESS_ANALYTICS': 'true'},
    );
    final stream = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((line) => line.trim().isNotEmpty)
        .map((line) => jsonDecode(line) as Map<String, dynamic>)
        .asBroadcastStream();

    final client = _McpStdioClient._(process, stream);
    client._sub = stream.listen(client._onMessage);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    return client;
  }

  void _onMessage(Map<String, dynamic> message) {
    final id = message['id'];
    if (id is int && _pending.containsKey(id)) {
      _pending.remove(id)!.complete(message);
    }
  }

  Future<void> initialize() async {
    await request('initialize', {
      'protocolVersion': '2024-11-05',
      'capabilities': {},
      'clientInfo': {'name': 'docs-gen', 'version': '1.0.0'},
    });
    _process.stdin.writeln(jsonEncode({
      'jsonrpc': '2.0',
      'method': 'notifications/initialized',
    }));
  }

  Future<Map<String, dynamic>> request(
    String method,
    Map<String, dynamic> params,
  ) async {
    final id = _nextId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _process.stdin.writeln(jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    }));
    final response = await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('MCP $method timed out'),
    );
    if (response.containsKey('error')) {
      throw StateError('$method error: ${response['error']}');
    }
    return response['result'] as Map<String, dynamic>;
  }

  Future<void> close() async {
    await _sub.cancel();
    _process.kill();
    try {
      await _process.exitCode.timeout(const Duration(seconds: 5));
    } catch (_) {
      _process.kill(ProcessSignal.sigkill);
    }
  }
}