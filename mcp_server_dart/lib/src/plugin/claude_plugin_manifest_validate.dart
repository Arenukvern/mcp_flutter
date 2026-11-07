import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

const _policyPrefix = 'repository policy (mcp_flutter plugin packaging):';
const _claudeAgentsHint =
    'Claude Code plugin validate rejects directory paths for agents';

/// Targeted checks for this repo's Claude marketplace packaging policy and
/// known Claude install failure modes (PR #151). Not a full upstream schema.
List<String> validateClaudePluginManifest({
  required String manifestJson,
  required String pluginRootPath,
}) {
  final errors = <String>[];
  final pluginRoot = p.normalize(p.absolute(pluginRootPath));

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
    errors.addAll(_validateAgentsField(agents, pluginRoot: pluginRoot));
  }

  final mcpServers = manifest['mcpServers'];
  if (mcpServers == null) {
    errors.add(
      '$_policyPrefix mcpServers is required — marketplace installs must '
      'reference ./mcp.json explicitly',
    );
  } else {
    errors.addAll(
      _validateMcpServersField(
        mcpServers,
        pluginRoot: pluginRoot,
      ),
    );
  }

  return errors;
}

List<String> _validateAgentsField(
  Object agents, {
  required String pluginRoot,
}) {
  final errors = <String>[];
  void checkPath(String value, String label) {
    final resolved = _resolveRelativePluginPath(
      pluginRoot: pluginRoot,
      rawPath: value,
      field: label,
    );
    if (resolved.error != null) {
      errors.add(resolved.error!);
      return;
    }
    final target = resolved.path!;
    if (!target.endsWith('.md')) {
      errors.add(
        '$label must reference an agent .md file (got "$value"; '
        '$_claudeAgentsHint)',
      );
      return;
    }
    if (!File(target).existsSync()) {
      errors.add('$label target does not exist: $value (resolved $target)');
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
  required String pluginRoot,
}) {
  final errors = <String>[];
  if (mcpServers is! String || mcpServers.trim().isEmpty) {
    errors.add('mcpServers must be a non-empty string path');
    return errors;
  }

  final resolved = _resolveRelativePluginPath(
    pluginRoot: pluginRoot,
    rawPath: mcpServers,
    field: 'mcpServers',
  );
  if (resolved.error != null) {
    errors.add(resolved.error!);
    return errors;
  }
  final file = File(resolved.path!);
  if (!file.existsSync()) {
    errors.add(
      'mcpServers target does not exist: $mcpServers (resolved ${resolved.path})',
    );
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

class _ResolvedPath {
  _ResolvedPath({this.path, this.error});
  final String? path;
  final String? error;
}

bool _hasParentPathSegment(String relativePath) {
  for (final segment in p.split(relativePath)) {
    if (segment == '..') return true;
  }
  return false;
}

String _realPath(String path) {
  final absolute = p.normalize(p.absolute(path));
  try {
    final type = FileSystemEntity.typeSync(absolute, followLinks: false);
    if (type == FileSystemEntityType.notFound) return absolute;
    if (type == FileSystemEntityType.directory) {
      return p.normalize(Directory(absolute).resolveSymbolicLinksSync());
    }
    return p.normalize(File(absolute).resolveSymbolicLinksSync());
  } catch (_) {
    return absolute;
  }
}

bool _isInsidePluginRoot(String pluginRoot, String candidate) {
  final rootReal = _realPath(pluginRoot);
  final candidateReal = _realPath(candidate);
  return p.isWithin(rootReal, candidateReal) || candidateReal == rootReal;
}

_ResolvedPath _resolveRelativePluginPath({
  required String pluginRoot,
  required String rawPath,
  required String field,
}) {
  final trimmed = rawPath.trim();
  if (trimmed.isEmpty) {
    return _ResolvedPath(error: '$field must be a non-empty path');
  }
  if (p.isAbsolute(trimmed)) {
    return _ResolvedPath(
      error: '$_policyPrefix $field must be relative (./...), not absolute',
    );
  }
  if (_hasParentPathSegment(trimmed)) {
    return _ResolvedPath(
      error: '$_policyPrefix $field must not contain ".." path segments',
    );
  }
  if (!trimmed.startsWith('./')) {
    return _ResolvedPath(
      error:
          '$_policyPrefix $field paths must start with ./ (got "$trimmed")',
    );
  }
  final joined = p.normalize(p.join(pluginRoot, trimmed));
  if (!_isInsidePluginRoot(pluginRoot, joined)) {
    return _ResolvedPath(
      error:
          '$_policyPrefix $field must resolve inside plugin root (symlink escape rejected)',
    );
  }
  return _ResolvedPath(path: joined);
}
