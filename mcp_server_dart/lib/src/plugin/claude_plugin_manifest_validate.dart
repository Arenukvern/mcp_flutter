import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Targeted checks aligned with Claude Code plugin install failures seen in
/// https://github.com/Arenukvern/mcp_flutter/pull/151 — not a full upstream
/// schema implementation.
List<String> validateClaudePluginManifest({
  required String manifestJson,
  required String pluginRootPath,
}) {
  final errors = <String>[];

  late final Map<String, dynamic> manifest;
  try {
    final decoded = jsonDecode(manifestJson);
    if (decoded is! Map<String, dynamic>) {
      errors.add('manifest root must be a JSON object');
      return errors;
    }
    manifest = decoded;
  } catch (e) {
    errors.add('manifest is not valid JSON: $e');
    return errors;
  }

  final agents = manifest['agents'];
  if (agents != null) {
    errors.addAll(_validateAgentsField(agents));
  }

  final mcpServers = manifest['mcpServers'];
  if (mcpServers == null) {
    errors.add(
      'mcpServers is required (Claude Code does not load plugin/mcp.json '
      'unless explicitly referenced)',
    );
  } else {
    errors.addAll(
      _validateMcpServersField(
        mcpServers,
        pluginRootPath: pluginRootPath,
      ),
    );
  }

  return errors;
}

List<String> _validateAgentsField(Object agents) {
  final errors = <String>[];
  void checkPath(String value, String label) {
    final trimmed = value.trim();
    if (!trimmed.endsWith('.md')) {
      errors.add(
        '$label must be a path to an agent .md file (got "$value"; '
        'directories are rejected by Claude plugin validate)',
      );
    }
  }

  if (agents is String) {
    checkPath(agents, 'agents');
  } else if (agents is List) {
    for (var i = 0; i < agents.length; i++) {
      final entry = agents[i];
      if (entry is! String) {
        errors.add('agents[$i] must be a string path');
        continue;
      }
      checkPath(entry, 'agents[$i]');
    }
  } else {
    errors.add('agents must be a string or array of strings');
  }
  return errors;
}

List<String> _validateMcpServersField(
  Object mcpServers, {
  required String pluginRootPath,
}) {
  final errors = <String>[];
  if (mcpServers is! String || mcpServers.trim().isEmpty) {
    errors.add('mcpServers must be a non-empty string path');
    return errors;
  }

  final resolved = p.normalize(p.join(pluginRootPath, mcpServers));
  final file = File(resolved);
  if (!file.existsSync()) {
    errors.add('mcpServers target does not exist: $mcpServers (resolved $resolved)');
    return errors;
  }

  try {
    final content = file.readAsStringSync();
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      errors.add('mcpServers file must be a JSON object: $mcpServers');
      return errors;
    }
    if (!decoded.containsKey('mcpServers')) {
      errors.add(
        'mcpServers file must contain top-level "mcpServers" object: $mcpServers',
      );
    }
  } catch (e) {
    errors.add('mcpServers file is not valid JSON ($mcpServers): $e');
  }
  return errors;
}
