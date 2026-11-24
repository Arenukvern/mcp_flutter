/// Default-surface MCP exec sweep for the showcase app.
/// Replaces `scripts/run_exec_sweep.sh` (no bash/python).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:path/path.dart' as p;

final String repoRoot = p.normalize(
  p.join(p.dirname(Platform.script.toFilePath()), '..', '..', '..'),
);

final String showcaseAppDefault =
    p.join(repoRoot, 'showcase', 'flutter_test_app');

String get appDir {
  final override = Platform.environment['SHOWCASE_APP_DIR']?.trim();
  if (override != null && override.isNotEmpty) {
    return p.isAbsolute(override)
        ? p.normalize(override)
        : p.join(repoRoot, override);
  }
  return showcaseAppDefault;
}

Future<void> main(List<String> arguments) async {
  final platform = Platform.environment['PLATFORM']?.trim() ?? 'macos';
  if (platform != 'macos' && platform != 'web') {
    stderr.writeln('Unsupported PLATFORM=$platform (use macos or web)');
    exit(64);
  }

  final wsUri = resolveWsUri();
  if (wsUri == null || wsUri.isEmpty) {
    stderr.writeln(
      'Set WS_URI or run a showcase that writes '
      '${p.join(appDir, ".flutter_mcp", "runner-session.json")}',
    );
    exit(64);
  }

  final legacyRoot = p.join(repoRoot, '.showcase', 'tool_verify', 'exec_sweep');
  final outdir = p.join(legacyRoot, platform);
  cleanupLegacyRootArtifacts(legacyRoot, outdir);
  Directory(outdir).createSync(recursive: true);

  final runner = ExecSweepRunner(
    platform: platform,
    wsUri: wsUri,
    outdir: outdir,
    showcaseProject: showcaseAppDefault,
  );

  stdout.writeln('[exec-sweep] platform=$platform ws=$wsUri out=$outdir');
  await runner.runSweep();
  await runner.writeSummary(
    platform: platform,
    wsUri: wsUri,
    outdir: outdir,
  );

  if (runner.fail > 0) {
    exit(1);
  }
}

void cleanupLegacyRootArtifacts(String legacyRoot, String outdir) {
  final root = Directory(legacyRoot);
  if (root.existsSync()) {
    for (final entity in root.listSync()) {
      final name = p.basename(entity.path);
      if (entity is File &&
          (name == 'sweep_summary.txt' ||
              name.endsWith('.json') ||
              name.endsWith('.stderr'))) {
        entity.deleteSync();
      }
    }
  }
  final platformDir = Directory(outdir);
  if (platformDir.existsSync()) {
    platformDir.deleteSync(recursive: true);
  }
}

/// WS_URI env, else `vm_service_uri` from runner-session under the showcase app.
String? resolveWsUri() {
  final fromEnv = Platform.environment['WS_URI']?.trim();
  if (fromEnv != null && fromEnv.isNotEmpty) {
    if (fromEnv.startsWith('http://')) {
      return canonicalVmServiceWsUri(Uri.parse(fromEnv)).toString();
    }
    return fromEnv;
  }
  final sessionFile = File(p.join(appDir, '.flutter_mcp', 'runner-session.json'));
  if (!sessionFile.existsSync()) return null;
  try {
    final map = jsonDecode(sessionFile.readAsStringSync()) as Map<String, dynamic>;
    final uri = map['vm_service_uri']?.toString().trim();
    if (uri == null || uri.isEmpty) return null;
    if (uri.startsWith('http://')) {
      return canonicalVmServiceWsUri(Uri.parse(uri)).toString();
    }
    return uri;
  } on Object {
    return null;
  }
}

final class ExecSweepRunner {
  ExecSweepRunner({
    required this.platform,
    required this.wsUri,
    required this.outdir,
    required this.showcaseProject,
  }) : webPort = Platform.environment['WEB_BROWSER_DEBUGGING_PORT']?.trim() ??
            '9222';

  final String platform;
  final String wsUri;
  final String outdir;
  final String showcaseProject;
  final String webPort;

  int pass = 0;
  int fail = 0;
  int skip = 0;
  final List<String> results = [];
  final String revealDownDirection = 'down';

  List<String> get _toolkitBase {
    final base = <String>[
      'run',
      p.join(repoRoot, 'mcp_server_dart', 'bin', 'flutter_mcp_toolkit.dart'),
      '--vm-service-uri',
      wsUri,
    ];
    if (platform == 'macos') {
      base.addAll([
        '--flutter-device',
        'macos',
        '--flutter-project-dir',
        showcaseProject,
      ]);
    } else {
      base.addAll([
        '--flutter-device',
        'chrome',
        '--web-browser-debugging-port',
        webPort,
      ]);
    }
    return base;
  }

  Future<ProcessResult> _toolkit(List<String> args) {
    return Process.run(
      'dart',
      [..._toolkitBase, ...args],
      workingDirectory: repoRoot,
    );
  }

  Future<void> runSweep() async {
    await runTool('status', '{}');
    await runTool('discover_debug_apps', '{}');
    await runTool('get_vm', '{}');
    await runTool('get_extension_rpcs', '{}');
    await runTool('dynamicRegistryStats', '{}');

    await runTool('get_app_errors', '{"count":5}');
    await runTool('get_view_details', '{}');
    await runTool('get_screenshots', '{"compress":true,"mode":"flutter_layer"}');
    await runTool('inspect_widget_at_point', '{"x":200,"y":300}');
    await runTool(
      'capture_ui_snapshot',
      '{"compress":true,"includeViewDetails":true,"includeErrors":true,"errorsCount":5}',
    );
    if (platform == 'macos') {
      await runTool('focus_window', '{}');
    } else {
      skipTool('focus_window', 'macOS host only');
    }

    await runTool('semantic_snapshot', '{}');

    await runTool(
      'reveal_search',
      '{"query":"greeting_input_field","matchBy":"identifier",'
      '"direction":"$revealDownDirection","maxAttempts":4,"distance":220}',
    );

    var revealRef = jsonField(
      File(p.join(outdir, 'reveal_search.json')),
      'data.ref',
    );
    var revealSnap = jsonField(
      File(p.join(outdir, 'reveal_search.json')),
      'data.snapshotId',
    );
    var revealVisible = jsonField(
      File(p.join(outdir, 'reveal_search.json')),
      'data.centerInViewport',
    );

    final greetingArgs = File(p.join(outdir, 'greeting_args.json'));
    if (revealRef.isEmpty) {
      if (await ensureVisibleIdentifierArgs(
        'greeting_input_field',
        greetingArgs,
        revealDownDirection,
      )) {
        revealRef = argsRef(greetingArgs) ?? '';
        revealSnap = argsSnapshotId(greetingArgs) ?? '';
      }
    } else if (revealVisible != 'True' && revealVisible != 'true') {
      if (await ensureVisibleIdentifierArgs(
        'greeting_input_field',
        greetingArgs,
        revealDownDirection,
      )) {
        revealRef = argsRef(greetingArgs) ?? '';
        revealSnap = argsSnapshotId(greetingArgs) ?? '';
      }
    }

    await runTool('evaluate_dart_expression', '{"expression":"AgentState.instance.greeting"}');
    if (revealRef.isNotEmpty && revealSnap.isNotEmpty) {
      await runTool(
        'enter_text',
        '{"ref":"$revealRef","snapshotId":$revealSnap,"text":"exec sweep"}',
      );
    } else {
      missingRequiredTool(
        'enter_text',
        'greeting_input_field ref not visible/discovered',
      );
    }

    final incrementTap = File(p.join(outdir, 'increment_tap_args.json'));
    if (await ensureVisibleIdentifierArgs(
      'stateful_counter_increment_button',
      incrementTap,
      'up',
    )) {
      await runTool('tap_widget', incrementTap.readAsStringSync().trim());
    } else {
      missingRequiredTool(
        'tap_widget',
        'stateful_counter_increment_button ref not visible/discovered',
      );
    }

    final incrementLongPress = File(p.join(outdir, 'increment_long_press_args.json'));
    if (await ensureVisibleIdentifierArgs(
      'stateful_counter_increment_button',
      incrementLongPress,
      'up',
    )) {
      if (platform == 'web') {
        skipTool(
          'long_press',
          'Flutter Web requires SemanticsAction.longPress on the target',
        );
      } else {
        await runTool('long_press', incrementLongPress.readAsStringSync().trim());
      }
    } else {
      missingRequiredTool(
        'long_press',
        'stateful_counter_increment_button ref not visible/discovered',
      );
    }

    final incrementDrag = File(p.join(outdir, 'increment_drag_args.json'));
    if (await ensureVisibleIdentifierArgs(
      'stateful_counter_increment_button',
      incrementDrag,
      'up',
    )) {
      if (platform == 'web') {
        skipTool('drag', 'Flutter Web does not support semantic drag synthesis');
      } else {
        final incrementRef = argsRef(incrementDrag);
        final incrementSnap = argsSnapshotId(incrementDrag);
        if (incrementRef != null && incrementSnap != null) {
          await runTool(
            'drag',
            '{"fromRef":"$incrementRef","toRef":"$incrementRef","snapshotId":$incrementSnap}',
          );
        }
      }
    } else {
      missingRequiredTool(
        'drag',
        'stateful_counter_increment_button ref not visible/discovered',
      );
    }

    final incrementHover = File(p.join(outdir, 'increment_hover_args.json'));
    if (await ensureVisibleIdentifierArgs(
      'stateful_counter_increment_button',
      incrementHover,
      'up',
    )) {
      await runTool('hover', incrementHover.readAsStringSync().trim());
    } else {
      missingRequiredTool(
        'hover',
        'stateful_counter_increment_button ref not visible/discovered',
      );
    }

    await _scrollAndSwipeChain();

    if (platform == 'web') {
      skipTool(
        'press_key',
        'Flutter Web browser focus can terminate or detach the VM service after synthetic key input',
      );
    } else {
      await runTool('press_key', '{"key":"Tab"}');
    }
    await runTool('get_recent_logs', '{"count":10}');
    await runTool(
      'wait_for',
      '{"predicate":{"kind":"time","ms":300},"timeoutMs":2000}',
    );

    await runTool('navigate', '{"action":"push","route":"/visual-reconstruct"}');
    if (platform == 'web') {
      await runTool('navigate', '{"action":"push","route":"/"}');
    } else {
      await runTool('navigate', '{"action":"pop"}');
    }

    await _dialogChain();

    final greetingFill = File(p.join(outdir, 'greeting_fill_args.json'));
    if (await ensureVisibleIdentifierArgs(
      'greeting_input_field',
      greetingFill,
      'up',
      requireVisible: false,
    )) {
      final greetingRef = argsRef(greetingFill);
      if (greetingRef != null) {
        await runFillFormTool(greetingRef, 'fill form ok');
      }
    } else if (revealRef.isNotEmpty) {
      await runFillFormTool(revealRef, 'fill form ok');
    } else if (platform == 'web') {
      skipTool(
        'fill_form',
        'Flutter Web: greeting_input_field not visible/discovered',
      );
    } else {
      missingRequiredTool(
        'fill_form',
        'greeting_input_field ref not visible/discovered',
      );
    }

    await runTool('hot_reload_flutter', '{}');
    await runTool(
      'hot_reload_and_capture',
      '{"compress":true,"errorsCount":5}',
    );

    await runTool('fmt_list_client_tools_and_resources', '{}');
    await runTool(
      'fmt_client_tool',
      '{"toolName":"dogfood_ping","arguments":{}}',
    );
    await runTool(
      'fmt_client_tool',
      '{"toolName":"intentcall_bridge_ping","arguments":{"echo":"vm-service-proof"}}',
    );

    stdout.writeln('=== migrate agent-entries ===');
    final migrateLog = File(p.join(outdir, 'migrate_agent_entries.log'));
    final migrate = await Process.run(
      'dart',
      [
        'run',
        p.join(repoRoot, 'mcp_server_dart', 'bin', 'flutter_mcp_toolkit.dart'),
        'migrate',
        'agent-entries',
        '--check',
        p.join(showcaseProject, 'lib'),
      ],
      workingDirectory: repoRoot,
    );
    await migrateLog.writeAsString('${migrate.stdout}\n${migrate.stderr}');
    if (migrate.exitCode == 0) {
      stdout.writeln('PASS: migrate agent-entries');
      pass++;
      results.add('PASS migrate agent-entries');
    } else {
      stdout.writeln('FAIL: migrate agent-entries');
      fail++;
      results.add('FAIL migrate agent-entries');
    }

    await runTool('hot_restart_flutter', '{}');
  }

  Future<void> _scrollAndSwipeChain() async {
    var scrollRef = '';
    var scrollSnapId = '';
    final scrollableArgs = File(p.join(outdir, 'scrollable_args.json'));

    if (await revealIdentifierArgs(
      'scroll_demo_list',
      scrollableArgs,
      revealDownDirection,
      maxAttempts: 5,
      distance: 260,
    )) {
      if (scrollableArgs.existsSync() && scrollableArgs.lengthSync() > 0) {
        scrollRef = argsRef(scrollableArgs) ?? '';
        scrollSnapId = argsSnapshotId(scrollableArgs) ?? '';
      }
      await _runScrollTool(scrollRef, scrollSnapId, 120, 'scroll');
    } else if (await resolveScrollableArgs(
      scrollableArgs,
      'semantic_before_scroll',
    )) {
      scrollRef = argsRef(scrollableArgs) ?? '';
      scrollSnapId = argsSnapshotId(scrollableArgs) ?? '';
      await _runScrollTool(scrollRef, scrollSnapId, 120, 'scroll');
    } else {
      await _scrollMissing('scroll');
    }

    scrollRef = '';
    scrollSnapId = '';
    final swipeArgs = File(p.join(outdir, 'scrollable_swipe_args.json'));
    if (await revealIdentifierArgs(
      'scroll_demo_list',
      swipeArgs,
      revealDownDirection,
      maxAttempts: 5,
      distance: 260,
    )) {
      if (swipeArgs.existsSync() && swipeArgs.lengthSync() > 0) {
        scrollRef = argsRef(swipeArgs) ?? '';
        scrollSnapId = argsSnapshotId(swipeArgs) ?? '';
      }
      await _runScrollTool(scrollRef, scrollSnapId, 80, 'swipe');
    } else if (await resolveScrollableArgs(
      swipeArgs,
      'semantic_before_swipe',
    )) {
      scrollRef = argsRef(swipeArgs) ?? '';
      scrollSnapId = argsSnapshotId(swipeArgs) ?? '';
      await _runScrollTool(scrollRef, scrollSnapId, 80, 'swipe');
    } else {
      await _scrollMissing('swipe');
    }
  }

  Future<void> _runScrollTool(
    String scrollRef,
    String scrollSnapId,
    int distance,
    String toolName,
  ) async {
    if (scrollRef.isNotEmpty && scrollSnapId.isNotEmpty) {
      await runToolAllowWebNoMovementSkip(
        toolName,
        '{"ref":"$scrollRef","direction":"down","distance":$distance,"snapshotId":$scrollSnapId}',
      );
    } else if (platform == 'web') {
      skipTool(toolName, 'Flutter Web: scrollable ref not visible/discovered');
    } else {
      missingRequiredTool(toolName, 'scrollable ref not visible/discovered');
    }
  }

  Future<void> _scrollMissing(String toolName) async {
    if (platform == 'web') {
      skipTool(toolName, 'Flutter Web: scrollable ref not visible/discovered');
    } else {
      missingRequiredTool(toolName, 'scrollable ref not visible/discovered');
    }
  }

  Future<void> _dialogChain() async {
    final dialogArgs = File(p.join(outdir, 'dialog_args.json'));
    final revealed = await revealIdentifierArgs(
      'show_test_dialog_button',
      dialogArgs,
      revealDownDirection,
      maxAttempts: 8,
      distance: 320,
    );
    final ensured = revealed ||
        await ensureVisibleIdentifierArgs(
          'show_test_dialog_button',
          dialogArgs,
          revealDownDirection,
        );

    if (ensured &&
        dialogArgs.existsSync() &&
        dialogArgs.lengthSync() > 0) {
      final dialogRef = argsRef(dialogArgs);
      if (dialogRef != null && dialogRef.isNotEmpty) {
        await runTool('tap_widget', dialogArgs.readAsStringSync().trim());
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await runTool('handle_dialog', '{"action":"dismiss"}');
        return;
      }
    }

    if (platform == 'web') {
      skipTool(
        'tap_widget',
        'Flutter Web: show_test_dialog_button not visible/discovered',
      );
      skipTool('handle_dialog', 'Flutter Web: dialog action not available');
    } else if (!ensured) {
      missingRequiredTool(
        'handle_dialog',
        'show_test_dialog_button ref not visible/discovered',
      );
    } else {
      missingRequiredTool(
        'tap_widget',
        'show_test_dialog_button ref not visible/discovered',
      );
      missingRequiredTool(
        'handle_dialog',
        'show_test_dialog_button ref not visible/discovered',
      );
    }
  }

  Future<void> writeSummary({
    required String platform,
    required String wsUri,
    required String outdir,
  }) async {
    final summaryFile = File(p.join(outdir, 'sweep_summary.txt'));
    final buffer = StringBuffer()
      ..writeln('platform=$platform')
      ..writeln('generatedAt=${DateTime.now().toUtc().toIso8601String()}')
      ..writeln('script=packages/harness/tool/exec_sweep.dart')
      ..writeln('outdir=$outdir')
      ..writeln('WS_URI=$wsUri')
      ..writeln('PASS=$pass FAIL=$fail SKIP=$skip')
      ..writeln()
      ..writeln('Results:');
    for (final line in results) {
      buffer.writeln(line);
    }
    final text = buffer.toString();
    stdout.write(text);
    await summaryFile.writeAsString(text);
  }

  Future<bool> runTool(String name, String args) async {
    stdout.writeln('=== $name ===');
    final outfile = File(p.join(outdir, '$name.json'));
    final stderrFile = File(p.join(outdir, '$name.stderr'));
    final result = await _toolkit([
      'exec',
      '--name',
      name,
      '--args',
      args,
    ]);
    await outfile.writeAsString(result.stdout);
    await stderrFile.writeAsString(result.stderr);
    if (result.exitCode == 0 && jsonOk(outfile)) {
      stdout.writeln('PASS: $name');
      pass++;
      results.add('PASS $name');
      return true;
    }
    stdout.writeln('FAIL: $name');
    _printJsonError(outfile);
    fail++;
    results.add('FAIL $name');
    return false;
  }

  Future<bool> runFillFormTool(String ref, String text) async {
    const name = 'fill_form';
    final args =
        '{"fields":[{"ref":"$ref","text":"${text.replaceAll('"', r'\"')}"}]}';
    stdout.writeln('=== $name ===');
    final outfile = File(p.join(outdir, '$name.json'));
    final stderrFile = File(p.join(outdir, '$name.stderr'));
    final result = await _toolkit([
      'exec',
      '--name',
      name,
      '--args',
      args,
    ]);
    await outfile.writeAsString(result.stdout);
    await stderrFile.writeAsString(result.stderr);
    if (result.exitCode == 0 && jsonOk(outfile)) {
      stdout.writeln('PASS: $name');
      pass++;
      results.add('PASS $name');
      return true;
    }
    if (platform == 'web') {
      final errU = jsonField(outfile, 'error.details.underlyingError');
      final dataU = jsonField(outfile, 'data.details.underlyingError');
      if (errU == 'no_editable_state' || dataU == 'no_editable_state') {
        skipTool(name, 'Flutter Web: greeting input field does not expose editable state');
        return true;
      }
    }
    stdout.writeln('FAIL: $name');
    _printJsonError(outfile);
    fail++;
    results.add('FAIL $name');
    return false;
  }

  Future<bool> runToolAllowWebNoMovementSkip(String name, String args) async {
    stdout.writeln('=== $name ===');
    final outfile = File(p.join(outdir, '$name.json'));
    var argsWithoutSnapshot = args;
    final result = await _toolkit([
      'exec',
      '--name',
      name,
      '--args',
      args,
    ]);
    await outfile.writeAsString(result.stdout);
    await File(p.join(outdir, '$name.stderr')).writeAsString(result.stderr);
    if (result.exitCode == 0 && jsonOk(outfile)) {
      stdout.writeln('PASS: $name');
      pass++;
      results.add('PASS $name');
      return true;
    }

    if (platform == 'web' &&
        jsonField(outfile, 'data.error') == 'stale_snapshot') {
      try {
        final parsed = jsonDecode(args) as Map<String, dynamic>;
        parsed.remove('snapshotId');
        argsWithoutSnapshot = jsonEncode(parsed);
      } on Object {
        argsWithoutSnapshot = args;
      }
    }

    if (platform == 'web' && argsWithoutSnapshot != args) {
      final retry = await _toolkit([
        'exec',
        '--name',
        name,
        '--args',
        argsWithoutSnapshot,
      ]);
      await outfile.writeAsString(retry.stdout);
      await File(p.join(outdir, '$name.stderr')).writeAsString(retry.stderr);
      if (retry.exitCode == 0 && jsonOk(outfile)) {
        stdout.writeln('PASS: $name (retry without stale snapshot)');
        pass++;
        results.add('PASS $name (retry without stale snapshot)');
        return true;
      }
    }

    if (platform == 'web' &&
        jsonField(outfile, 'data.error') == 'no_scroll_movement') {
      skipTool(
        name,
        'Flutter Web semantic gesture dispatched but no movement was verified',
      );
      return true;
    }

    stdout.writeln('FAIL: $name');
    _printJsonError(outfile);
    fail++;
    results.add('FAIL $name');
    return false;
  }

  void skipTool(String name, String reason) {
    stdout.writeln('SKIP: $name ($reason)');
    skip++;
    results.add('SKIP $name ($reason)');
  }

  void missingRequiredTool(String name, String reason) {
    stdout.writeln('FAIL: $name ($reason)');
    fail++;
    results.add('FAIL $name ($reason)');
  }

  Future<String?> captureSnapshot(String label) async {
    final outfile = File(p.join(outdir, '$label.json'));
    final result = await _toolkit([
      'exec',
      '--name',
      'semantic_snapshot',
      '--args',
      '{}',
    ]);
    await outfile.writeAsString(result.stdout);
    await File(p.join(outdir, '$label.stderr')).writeAsString(result.stderr);
    if (result.exitCode == 0 && jsonOk(outfile)) {
      return outfile.path;
    }
    return null;
  }

  Future<bool> resolveScrollableArgs(File outfile, String fallbackLabel) async {
    final initialSnap = File(p.join(outdir, 'semantic_snapshot.json'));
    if (initialSnap.existsSync()) {
      try {
        if (writeRefArgsForType(initialSnap, 'scrollable', outfile)) {
          return true;
        }
      } on Object {
        // fall through
      }
    }
    final fresh = await captureSnapshot(fallbackLabel);
    if (fresh == null) return false;
    try {
      return writeRefArgsForType(File(fresh), 'scrollable', outfile);
    } on Object {
      return false;
    }
  }

  Future<bool> ensureVisibleIdentifierArgs(
    String identifier,
    File outfile,
    String direction, {
    bool requireVisible = true,
  }) async {
    final directions = <String>[direction];
    if (platform == 'web') {
      directions.add(direction == 'down' ? 'up' : 'down');
    }
    for (var attempt = 0; attempt < 7; attempt++) {
      for (final dir in directions) {
        final snap = await captureSnapshot('semantic_${identifier}_${attempt}_$dir');
        if (snap == null) continue;
        final visibility =
            File(p.join(outdir, '${identifier}_${attempt}_$dir.visibility'));
        try {
          if (writeRefArgsForIdentifier(
            File(snap),
            identifier,
            outfile,
            requireVisible: requireVisible,
          )) {
            return true;
          }
        } on Object catch (e) {
          await visibility.writeAsString('$e\n');
        }
        await _toolkit([
          'exec',
          '--name',
          'scroll',
          '--args',
          '{"direction":"$dir","distance":420}',
        ]);
      }
    }
    return false;
  }

  Future<bool> revealIdentifierArgs(
    String identifier,
    File outfile,
    String direction, {
    int maxAttempts = 6,
    int distance = 320,
  }) async {
    final directions = <String>[direction];
    if (platform == 'web') {
      directions.add(direction == 'down' ? 'up' : 'down');
    }
    for (final dir in directions) {
      final revealFile = File(p.join(outdir, 'reveal_${identifier}_$dir.json'));
      final result = await _toolkit([
        'exec',
        '--name',
        'reveal_search',
        '--args',
        '{"query":"$identifier","matchBy":"identifier","direction":"$dir",'
        '"maxAttempts":$maxAttempts,"distance":$distance}',
      ]);
      await revealFile.writeAsString(result.stdout);
      await File(p.join(outdir, 'reveal_${identifier}_$dir.stderr'))
          .writeAsString(result.stderr);
      if (result.exitCode != 0) continue;
      if (writeRevealRefs(revealFile, outfile)) return true;
    }
    return false;
  }
}

bool jsonOk(File file) {
  try {
    final d = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final data = d['data'];
    if (d['ok'] != true) return false;
    if (data is Map<String, dynamic>) {
      if (data['success'] == false || data['ok'] == false) return false;
    }
    return true;
  } on Object {
    return false;
  }
}

String jsonField(File file, String dotPath) {
  try {
    final d = jsonDecode(file.readAsStringSync());
    Object? cur = d;
    for (final part in dotPath.split('.')) {
      if (part.isEmpty) continue;
      if (cur is Map<String, dynamic>) {
        cur = cur[part];
      } else {
        return '';
      }
    }
    if (cur == null) return '';
    return cur.toString();
  } on Object {
    return '';
  }
}

String? argsRef(File file) {
  try {
    final d = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return d['ref']?.toString();
  } on Object {
    return null;
  }
}

String? argsSnapshotId(File file) {
  try {
    final d = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final sid = d['snapshotId'];
    if (sid == null) return null;
    return sid.toString();
  } on Object {
    return null;
  }
}

bool writeRevealRefs(File revealFile, File outFile) {
  try {
    final d = jsonDecode(revealFile.readAsStringSync()) as Map<String, dynamic>;
    final data = d['data'];
    if (data is! Map<String, dynamic>) return false;
    final ref = data['ref'];
    final sid = data['snapshotId'];
    if (d['ok'] != true || data['success'] != true || ref == null || sid == null) {
      return false;
    }
    outFile.writeAsStringSync(
      jsonEncode(<String, Object?>{'ref': ref, 'snapshotId': sid}),
    );
    return true;
  } on Object {
    return false;
  }
}

bool writeRefArgsForIdentifier(
  File snapFile,
  String identifier,
  File outFile, {
  bool requireVisible = true,
}) {
  final d = jsonDecode(snapFile.readAsStringSync()) as Map<String, dynamic>;
  final data = d['data'];
  if (data is! Map<String, dynamic>) return false;
  final sid = data['snapshot_id'];
  final nodes = data['nodes'];
  if (nodes is! List) return false;
  for (final node in nodes) {
    if (node is! Map<String, dynamic>) continue;
    if (node['identifier'] != identifier) continue;
    final ref = node['ref'];
    if (ref == null) continue;
    if (requireVisible && node['centerInViewport'] != true) {
      throw StateError(
        '$identifier found but center is outside viewport: ${node['bounds']}',
      );
    }
    outFile.writeAsStringSync(
      jsonEncode(<String, Object?>{'ref': ref, 'snapshotId': sid}),
    );
    return true;
  }
  throw StateError('$identifier not found');
}

bool writeRefArgsForType(File snapFile, String typeName, File outFile) {
  final d = jsonDecode(snapFile.readAsStringSync()) as Map<String, dynamic>;
  final data = d['data'];
  if (data is! Map<String, dynamic>) return false;
  final sid = data['snapshot_id'];
  final nodes = data['nodes'];
  if (nodes is! List) return false;
  for (final node in nodes) {
    if (node is! Map<String, dynamic>) continue;
    if (node['type'] == typeName && node['ref'] != null) {
      outFile.writeAsStringSync(
        jsonEncode(<String, Object?>{'ref': node['ref'], 'snapshotId': sid}),
      );
      return true;
    }
  }
  throw StateError('$typeName not found');
}

void _printJsonError(File outfile) {
  try {
    final d = jsonDecode(outfile.readAsStringSync());
    if (d is Map<String, dynamic>) {
      stdout.writeln(d['error'] ?? d);
    } else {
      stdout.writeln(d);
    }
  } on Object catch (e) {
    stdout.writeln(e);
  }
}