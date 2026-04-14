import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Result of attempting to write an ephemeral Claude Code MCP config file
/// that wires the `flutter_inspector_mcp` binary as a stdio MCP server.
final class ClaudeMcpConfigHandle {
  const ClaudeMcpConfigHandle({
    required this.configPath,
    required this.cleanup,
    this.warning,
  });

  /// Absolute path to the generated JSON file, or `null` when the config
  /// could not be produced (see [warning]).
  final String? configPath;

  /// Best-effort cleanup closure; always safe to call.
  final void Function() cleanup;

  /// Non-fatal explanation when [configPath] is `null`. Callers should fall
  /// back to running Claude without MCP access.
  final String? warning;
}

/// Writes a temp JSON file with the shape expected by Claude Code's
/// `--mcp-config` flag, registering the `flutter_inspector_mcp` binary as a
/// stdio MCP server named `flutter_inspector`.
///
/// Resolves the binary path by walking upward from [workingDirectory] until a
/// `mcp_server_dart/build/flutter_inspector_mcp` file is found. When the
/// binary cannot be located, returns a handle with `configPath: null` and a
/// diagnostic warning rather than throwing; callers should degrade to
/// running Claude without MCP access.
ClaudeMcpConfigHandle writeClaudeMcpConfig({
  required final String workingDirectory,
  final int dartVmPort = 8181,
  final String serverName = 'flutter_inspector',
}) {
  final binaryPath = _resolveInspectorBinary(workingDirectory);
  if (binaryPath == null) {
    return ClaudeMcpConfigHandle(
      configPath: null,
      cleanup: () {},
      warning:
          'flutter_inspector_mcp binary not found; searched upward from '
          '"$workingDirectory" for mcp_server_dart/build/flutter_inspector_mcp. '
          'Run `cd mcp_server_dart && make compile` to build it.',
    );
  }

  final tempDir = Directory.systemTemp.createTempSync(
    'flutter_live_edit_claude_mcp_',
  );
  final configFile = File(p.join(tempDir.path, 'mcp.json'));
  final payload = <String, Object?>{
    'mcpServers': <String, Object?>{
      serverName: <String, Object?>{
        'command': binaryPath,
        'args': <String>['--dart-vm-port', '$dartVmPort'],
      },
    },
  };
  configFile.writeAsStringSync(jsonEncode(payload));

  return ClaudeMcpConfigHandle(
    configPath: configFile.path,
    cleanup: () {
      try {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      } on FileSystemException {
        // best-effort cleanup; temp dir will be reaped by the OS.
      }
    },
  );
}

String? _resolveInspectorBinary(final String workingDirectory) {
  final suffix = p.join('mcp_server_dart', 'build', 'flutter_inspector_mcp');
  var current = Directory(workingDirectory).absolute;
  // Walk upward with a hard cap in case of symlink loops.
  for (var depth = 0; depth < 24; depth++) {
    final candidate = File(p.join(current.path, suffix));
    if (candidate.existsSync()) return candidate.path;
    final parent = current.parent;
    if (parent.path == current.path) return null;
    current = parent;
  }
  return null;
}
