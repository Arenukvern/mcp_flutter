/// Returns extracted `{param}` values when [uri] matches [uriTemplate].
///
/// Returns `null` when the scheme, host, or path segment count differ, or when
/// a literal segment does not match.
Map<String, String>? matchUriTemplate(
  final String uriTemplate,
  final String uri,
) {
  final templateUri = Uri.parse(uriTemplate);
  final instanceUri = Uri.parse(uri);
  if (templateUri.scheme != instanceUri.scheme) return null;
  if (templateUri.host != instanceUri.host) return null;

  final templateSegments = templateUri.pathSegments;
  final instanceSegments = instanceUri.pathSegments;
  if (templateSegments.length != instanceSegments.length) return null;

  final params = <String, String>{};
  for (var i = 0; i < templateSegments.length; i++) {
    final segment = templateSegments[i];
    if (segment.startsWith('{') && segment.endsWith('}')) {
      params[segment.substring(1, segment.length - 1)] = instanceSegments[i];
      continue;
    }
    if (segment != instanceSegments[i]) {
      return null;
    }
  }
  return params;
}
