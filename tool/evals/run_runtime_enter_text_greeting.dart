// Reproduce the bounded runtime text-input adoption proof.
// Requires a running showcase app and its VM websocket URI.
// Replaces `tool/evals/run_runtime_enter_text_greeting.sh` (no bash, jq or python).
//
// Usage (from repository root):
//   dart run packages/harness/tool/showcase.dart   # or --web --detach
//   WS_URI='ws://127.0.0.1:<port>/<token>/ws' \
//     dart run tool/evals/run_runtime_enter_text_greeting.dart
library;

import 'dart:convert';
import 'dart:io';

const _usage = '''
Usage: dart run tool/evals/run_runtime_enter_text_greeting.dart [options]

Options:
  --ws-uri URI       VM websocket URI for a running showcase/flutter_test_app showcase
  --output PATH      Evidence JSON path
  --text TEXT        Text to enter (default: steward runtime proof)
  --platform NAME    Runtime platform label (default: macos)
  --launch-command   Launch command recorded in evidence
                     (default: dart run packages/harness/tool/showcase.dart)
  -h, --help         Show this help

Environment: WS_URI (or MACOS_WS_URI), RUNTIME_PLATFORM, RUNTIME_LAUNCH_COMMAND,
WEB_BROWSER_DEBUGGING_PORT (web only, default 9222).

Example:
  dart run packages/harness/tool/showcase.dart
  WS_URI='ws://127.0.0.1:<port>/<token>/ws' \\
    dart run tool/evals/run_runtime_enter_text_greeting.dart
''';

const _identifier = 'greeting_input_field';
const _expression = 'AgentState.instance.greeting';

final String _repoRoot = File(Platform.script.toFilePath())
    .parent
    .parent
    .parent
    .absolute
    .path;

late final String _wsUri;
late final String _platform;
late final Directory _workDir;

Future<void> main(List<String> args) async {
  final env = Platform.environment;
  var wsUri = env['WS_URI'] ?? env['MACOS_WS_URI'] ?? '';
  var output =
      '$_repoRoot/maintainers/evidence/generated/mcp_flutter.runtime-enter-text-greeting.redacted.json';
  var text = 'steward runtime proof';
  var platform = env['RUNTIME_PLATFORM'] ?? 'macos';
  var launchCommand =
      env['RUNTIME_LAUNCH_COMMAND'] ??
      'dart run packages/harness/tool/showcase.dart';

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    String value() {
      if (i + 1 >= args.length) {
        stderr
          ..writeln('Missing value for $arg')
          ..write(_usage);
        exit(64);
      }
      return args[++i];
    }

    switch (arg) {
      case '--ws-uri':
        wsUri = value();
      case '--output':
        output = value();
      case '--text':
        text = value();
      case '--platform':
        platform = value();
      case '--launch-command':
        launchCommand = value();
      case '-h' || '--help':
        stdout.write(_usage);
        exit(0);
      default:
        stderr
          ..writeln('Unknown option: $arg')
          ..write(_usage);
        exit(64);
    }
  }

  if (wsUri.isEmpty) {
    stderr.writeln(
      'Set WS_URI or pass --ws-uri for the running showcase VM websocket.',
    );
    exit(64);
  }
  _wsUri = wsUri;
  _platform = platform;
  _workDir = Directory.systemTemp.createTempSync('runtime_enter_text_');

  try {
    exitCode = await _run(
      output: output,
      text: text,
      launchCommand: launchCommand,
    );
  } finally {
    _workDir.deleteSync(recursive: true);
  }
}

Future<int> _run({
  required String output,
  required String text,
  required String launchCommand,
}) async {
  final branch = await _git(['branch', '--show-current']);
  final baseCommit = await _git(['rev-parse', 'HEAD']);

  final doctor = await _requireTool('doctor', ['doctor', '--json']);

  // Canonical showcase boots `/`; interaction fixtures live at `/qa` (ADR-0025).
  final navigate = await _tool('navigate_qa', [
    'exec',
    '--name',
    'navigate',
    '--args',
    jsonEncode({'action': 'push', 'route': '/qa'}),
  ]);
  if (navigate.exitCode != 0 || !_jsonOk(navigate.json)) {
    stderr
      ..writeln(
        'navigate push /qa failed; cannot reach $_identifier on canonical home.',
      )
      ..write(navigate.stderr);
    return 1;
  }

  var reveal = await _revealSearch('down');
  if (!_revealSucceeded(reveal) && _platform == 'web') {
    reveal = await _revealSearch('up');
  }
  if (!_revealSucceeded(reveal)) {
    final fallback = await _ensureVisibleIdentifier(_identifier, 'down');
    if (fallback == null) {
      stderr
        ..writeln(
          'Could not reveal semantics identifier $_identifier with '
          'reveal_search or semantic snapshot fallback.',
        )
        ..writeln(const JsonEncoder.withIndent('  ').convert(_data(reveal)));
      return 1;
    }
    reveal = _revealFallbackJson(fallback.args, fallback.match);
  }

  final revealData = _data(reveal);
  final ref = revealData['ref'];
  final snapshotId = revealData['snapshotId'];

  final before = await _requireTool('before', [
    'exec',
    '--name',
    'evaluate_dart_expression',
    '--args',
    jsonEncode({'expression': _expression}),
  ]);
  final enter = await _requireTool('enter_text', [
    'exec',
    '--name',
    'enter_text',
    '--args',
    jsonEncode({'ref': ref, 'snapshotId': snapshotId, 'text': text}),
  ]);
  final after = await _requireTool('after', [
    'exec',
    '--name',
    'evaluate_dart_expression',
    '--args',
    jsonEncode({'expression': _expression}),
  ]);

  final doctorData = _data(doctor);
  final summary = _map(doctorData['summary']);
  final enterData = _data(enter);
  final actual = _data(after)['result'];
  final match = _map(revealData['match']);
  final passed = actual == text;

  final evidence = <String, Object?>{
    'schema': 'steward-adoption-runtime-proof/v1',
    'capabilityId': 'mcp_flutter.runtime.enter-text-greeting',
    'status': 'adoption_run_passed_capability_candidate',
    'recordedAt': _isoNowSeconds(),
    'subject': {
      'repo': 'mcp_flutter',
      'branch': branch,
      'baseCommit': baseCommit,
      'dirtyState': 'caller must inspect git status; this script does not assert clean checkout',
    },
    'runtime': {
      'platform': _platform,
      'launchCommand': launchCommand,
      'vmServiceUri': 'ws://127.0.0.1:<redacted-port>/<redacted-token>/ws',
    },
    'proof': {
      'doctor': {
        'ok': doctor['ok'],
        'total': summary['total'],
        'pass': summary['pass'],
        'warn': summary['warn'],
        'fail': summary['fail'],
      },
      'discovery': {
        'snapshotId': snapshotId,
        'selector': {
          'identifier': _identifier,
          'ref': ref,
          'type': match['type'],
        },
      },
      'reveal': {
        'strategy': 'reveal_search',
        'tool': 'reveal_search',
        'targetIdentifier': _identifier,
        'attempts': revealData['attempts'],
        'match': revealData['match'],
        'success': revealData['success'],
      },
      'falsifier': {
        'expression': _expression,
        'before': _data(before)['result'],
      },
      'interaction': {
        'tool': 'enter_text',
        'ref': ref,
        'snapshotId': snapshotId,
        'text': text,
        'success': enterData['success'],
        'via': enterData['via'],
      },
      'acceptance': {
        'expression': _expression,
        'expected': text,
        'actual': actual,
        'passed': passed,
      },
    },
    'caveats': [
      'This proves one adoption run, not full H5 capability or repo-wide adoption.',
      'Promote only after a held-out fresh checkout or second-agent repeat.',
    ],
  };

  final outFile = File(output);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(evidence)}\n',
  );

  if (!passed) {
    stderr.writeln('Acceptance failed; evidence written to $output');
    return 1;
  }
  stdout.writeln('OK: runtime enter-text proof evidence written to $output');
  return 0;
}

class _ToolResult {
  _ToolResult(this.exitCode, this.json, this.stderr);
  final int exitCode;
  final Map<String, Object?> json;
  final String stderr;
}

Future<_ToolResult> _tool(String label, List<String> toolArgs) async {
  final command = <String>[
    'run',
    '$_repoRoot/mcp_server_dart/bin/flutter_mcp_toolkit.dart',
    if (_platform == 'web') ...[
      '--flutter-device',
      'chrome',
      '--web-browser-debugging-port',
      Platform.environment['WEB_BROWSER_DEBUGGING_PORT'] ?? '9222',
    ],
    '--vm-service-uri',
    _wsUri,
    ...toolArgs,
  ];
  final r = await Process.run(Platform.resolvedExecutable, command);
  final out = r.stdout as String;
  final err = r.stderr as String;
  File('${_workDir.path}/$label.json').writeAsStringSync(out);
  File('${_workDir.path}/$label.stderr').writeAsStringSync(err);
  Map<String, Object?> json;
  try {
    final decoded = jsonDecode(out);
    json = decoded is Map<String, Object?> ? decoded : <String, Object?>{};
  } on FormatException {
    json = <String, Object?>{};
  }
  return _ToolResult(r.exitCode, json, err);
}

/// Mirrors the bash `set -e` contract: a failing call aborts the proof.
Future<Map<String, Object?>> _requireTool(
  String label,
  List<String> toolArgs,
) async {
  final r = await _tool(label, toolArgs);
  if (r.exitCode != 0) {
    stderr
      ..writeln('$label failed (exit ${r.exitCode})')
      ..write(r.stderr);
    exit(r.exitCode);
  }
  return r.json;
}

Future<Map<String, Object?>> _revealSearch(String direction) async {
  final r = await _tool('reveal_search_$direction', [
    'exec',
    '--name',
    'reveal_search',
    '--args',
    jsonEncode({
      'query': _identifier,
      'matchBy': 'identifier',
      'direction': direction,
      'maxAttempts': 4,
      'distance': 220,
    }),
  ]);
  return r.json;
}

bool _revealSucceeded(Map<String, Object?> reveal) =>
    _data(reveal)['success'] == true;

bool _jsonOk(Map<String, Object?> json) {
  if (json['ok'] != true) return false;
  final data = json['data'];
  if (data is Map && (data['success'] == false || data['ok'] == false)) {
    return false;
  }
  return true;
}

Map<String, Object?> _data(Map<String, Object?> json) => _map(json['data']);

Map<String, Object?> _map(Object? value) =>
    value is Map ? value.cast<String, Object?>() : <String, Object?>{};

class _Visible {
  _Visible(this.args, this.match);
  final Map<String, Object?> args;
  final Map<String, Object?> match;
}

Future<_Visible?> _ensureVisibleIdentifier(
  String identifier,
  String direction,
) async {
  final directions = <String>[
    direction,
    if (_platform == 'web') direction == 'down' ? 'up' : 'down',
  ];
  for (var attempt = 0; attempt <= 6; attempt++) {
    for (final dir in directions) {
      final label = 'semantic_${identifier}_${attempt}_$dir';
      final snap = await _tool(label, [
        'exec',
        '--name',
        'semantic_snapshot',
        '--args',
        '{}',
      ]);
      if (snap.exitCode != 0 || !_jsonOk(snap.json)) return null;
      final found = _visibleRef(snap.json, identifier);
      if (found != null) return found;
      await _tool('scroll_to_${identifier}_${attempt}_$dir', [
        'exec',
        '--name',
        'scroll',
        '--args',
        jsonEncode({'direction': dir, 'distance': 420}),
      ]);
    }
  }
  return null;
}

_Visible? _visibleRef(Map<String, Object?> snapshot, String identifier) {
  final data = _data(snapshot);
  final nodes = data['nodes'];
  if (nodes is! List) return null;
  for (final raw in nodes) {
    final node = _map(raw);
    final ref = node['ref'];
    if (node['identifier'] != identifier || ref == null || ref == '') continue;
    if (node['centerInViewport'] != true) {
      // Found but off-screen: keep scrolling, like the bash original.
      return null;
    }
    return _Visible({'ref': ref, 'snapshotId': data['snapshot_id']}, node);
  }
  return null;
}

Map<String, Object?> _revealFallbackJson(
  Map<String, Object?> args,
  Map<String, Object?> match,
) => {
  'ok': true,
  'data': {
    'message': 'Revealed target with semantic snapshot fallback.',
    'success': true,
    'error': null,
    'query': _identifier,
    'matchBy': 'identifier',
    'direction': 'down',
    'snapshotId': args['snapshotId'],
    'ref': args['ref'],
    'match': match,
    'attempts': [
      {
        'strategy': 'semantic_snapshot_scroll_fallback',
        'reason': 'reveal_search could not verify web scroll movement',
      },
    ],
    'fallbackUsed': true,
  },
  'meta': <String, Object?>{},
};

Future<String> _git(List<String> args) async {
  try {
    final r = await Process.run('git', ['-C', _repoRoot, ...args]);
    return r.exitCode == 0 ? (r.stdout as String).trim() : '';
  } on ProcessException {
    return '';
  }
}

String _isoNowSeconds() {
  final now = DateTime.now().toUtc();
  final s = now.toIso8601String();
  return '${s.substring(0, s.indexOf('.'))}Z';
}
