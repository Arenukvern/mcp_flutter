import 'package:path/path.dart' as p;

/// Package-private helpers for the live edit agent. Not exported.

bool hasText(final String? value) => value != null && value.trim().isNotEmpty;

String? normalizeFilePath(final String rawPath) {
  final uri = Uri.tryParse(rawPath);
  if (uri != null && uri.scheme == 'file') return uri.toFilePath();
  if (rawPath.trim().isEmpty) return null;
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

Map<String, Object?> normalizeMap(final Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map(
      (final key, final nestedValue) => MapEntry('$key', nestedValue),
    );
  }
  return const <String, Object?>{};
}

List<Map<String, Object?>> asMapList(final Object? value) {
  if (value is! List) return const <Map<String, Object?>>[];
  return value.whereType<Map>().map(normalizeMap).toList(growable: false);
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
    return '${value.substring(0, maxStringChars)}...[truncated ${value.length - maxStringChars} chars]';
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
