// mcp_server_dart/lib/src/cli/init_command.dart
import 'dart:io';
import 'init_mode.dart';
import 'init_target.dart';
import 'init_writers.dart';
import 'init_mode_detector.dart';

Future<int> runInit({
  required final InitTarget target,
  required final InitMode modeOverride,
  required final String outputRoot,
  required final bool scopeIsUserHome,
}) async {
  final mode = modeOverride == InitMode.auto
      ? detectMode(
          binaryOnPath: _binaryOnPath('flutter-mcp-toolkit'),
          mcpServerRegistered: _isMcpServerRegistered(target, outputRoot),
        )
      : modeOverride;
  stdout.writeln('Mode: ${mode.name}');
  InitWriters.writeFor(
    target: target,
    mode: mode,
    outputRoot: outputRoot,
    scopeIsUserHome: scopeIsUserHome,
  );
  stdout.writeln('OK: skills written for ${target.canonicalName}');
  return 0;
}

bool _binaryOnPath(final String name) {
  final result = Process.runSync(
    Platform.isWindows ? 'where' : 'which',
    [name],
  );
  return result.exitCode == 0;
}

bool _isMcpServerRegistered(final InitTarget target, final String outputRoot) {
  // Heuristic: existing `mcp.json`/`claude_desktop_config.json` mentions
  // `flutter-mcp-toolkit`. Per-target detection details deferred to follow-up.
  switch (target) {
    case InitTarget.claudeCode:
      final f = File('$outputRoot/.claude/mcp.json');
      return f.existsSync() && f.readAsStringSync().contains('flutter-mcp-toolkit');
    case InitTarget.cursor:
    case InitTarget.codex:
    case InitTarget.cline:
    case InitTarget.agentsSkills:
    case InitTarget.all:
      return false;
  }
}
