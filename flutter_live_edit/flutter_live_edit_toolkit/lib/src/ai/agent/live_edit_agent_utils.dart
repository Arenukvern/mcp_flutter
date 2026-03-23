import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:path/path.dart' as p;

import '../../ui_selectors/shared/live_edit_selectors_shared.dart';

/// Package-private helpers for the live edit agent. Not exported.
///
/// **Paths** — Turn user-facing file strings into absolute workspace paths.
///
/// **JSON** — [jsonDecodeMapLoose] / [jsonDecodeMapListLoose] use
/// `from_json_to_json` for map/list coercion like the rest of the repo;
/// [compactJson] only shrinks blobs for model prompts (not wire codecs).

String? normalizeFilePath(final String rawPath) {
  final uri = Uri.tryParse(rawPath);
  if (uri != null && uri.scheme == 'file') return uri.toFilePath();
  if (jsonDecodeString(rawPath).trim().isEmpty) return null;
  return rawPath;
}

bool isWithinWorkspace(
  final String absolutePath,
  final String workingDirectory,
) {
  if (!p.isAbsolute(absolutePath)) return false;
  final normalizedFile = p.normalize(absolutePath);
  final normalizedWorkspace = p.normalize(workingDirectory);
  return normalizedFile == normalizedWorkspace ||
      p.isWithin(normalizedWorkspace, normalizedFile);
}

/// Absolute, normalized path under [workingDirectory], or null if
/// [normalizedPath] is missing or not usable.
String? absolutePathInWorkspace(
  final String? normalizedPath,
  final String workingDirectory,
) {
  if (!hasText(normalizedPath)) return null;
  final path = normalizedPath!;
  return p.isAbsolute(path)
      ? p.normalize(path)
      : p.normalize(p.join(workingDirectory, path));
}

/// Workspace-relative path when [absolutePath] lies inside the workspace.
String? workspaceRelativePathIfInside({
  required final String absolutePath,
  required final String workingDirectory,
}) {
  if (!isWithinWorkspace(absolutePath, workingDirectory)) return null;
  return p.relative(absolutePath, from: workingDirectory);
}

/// Coerces loose JSON [Map] keys to [String]; non-maps use
/// [jsonDecodeMapAs] (same role as the old `normalizeMap`).
Map<String, Object?> jsonDecodeMapLoose(final Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map(
      (final key, final nestedValue) => MapEntry('$key', nestedValue),
    );
  }
  return jsonDecodeMapAs<String, Object?>(value);
}

/// List of JSON object maps (skips non-map entries), using
/// [jsonDecodeMapLoose].
List<Map<String, Object?>> jsonDecodeMapListLoose(final Object? value) {
  if (value is! List) return const <Map<String, Object?>>[];
  return value.whereType<Map>().map(jsonDecodeMapLoose).toList(growable: false);
}

bool isLargePayloadKey(final String key) =>
    key.contains('base64') ||
    key.contains('bytes') ||
    key.contains('image') ||
    key.contains('screenshot') ||
    key.contains('png') ||
    key.contains('jpeg');

Object? compactJson(
  final Object? value, {
  final int depth = 0,
  final int maxDepth = 2,
  final int maxListItems = 8,
  final int maxStringChars = 240,
}) {
  if (value == null || value is num || value is bool) return value;
  if (value is String) {
    if (value.length <= maxStringChars) return value;
    final over = value.length - maxStringChars;
    return '${value.substring(0, maxStringChars)}...[truncated $over chars]';
  }
  if (value is Map) {
    final map = value.map(
      (final key, final nestedValue) => MapEntry('$key', nestedValue),
    );
    if (depth >= maxDepth) {
      return <String, Object?>{
        'truncated': true,
        'keys': map.keys.take(maxListItems).toList(growable: false),
      };
    }
    final result = <String, Object?>{};
    for (final entry in map.entries) {
      final lowerKey = entry.key.toLowerCase();
      if (isLargePayloadKey(lowerKey)) {
        result[entry.key] = '<omitted large payload>';
        continue;
      }
      result[entry.key] = compactJson(
        entry.value,
        depth: depth + 1,
        maxDepth: maxDepth,
        maxListItems: maxListItems,
        maxStringChars: maxStringChars,
      );
    }
    return result;
  }
  if (value is List) {
    final items = value
        .take(maxListItems)
        .map(
          (final item) => compactJson(
            item,
            depth: depth + 1,
            maxDepth: maxDepth,
            maxListItems: maxListItems,
            maxStringChars: maxStringChars,
          ),
        )
        .toList(growable: true);
    if (value.length > items.length) {
      items.add('<truncated ${value.length - items.length} items>');
    }
    return items;
  }
  return compactJson(
    '$value',
    depth: depth,
    maxDepth: maxDepth,
    maxListItems: maxListItems,
    maxStringChars: maxStringChars,
  );
}

Map<String, Object?> compactMap(
  final Map<String, Object?> value, {
  final int depth = 0,
  final int maxDepth = 2,
  final int maxListItems = 8,
  final int maxStringChars = 240,
}) {
  final compacted = compactJson(
    value,
    depth: depth,
    maxDepth: maxDepth,
    maxListItems: maxListItems,
    maxStringChars: maxStringChars,
  );
  return compacted is Map<String, Object?>
      ? compacted
      : const <String, Object?>{};
}
