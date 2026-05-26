import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// Listens for `agentkit://invoke/<qualified_name>` and dispatches to [onQualifiedName].
///
/// Dogfood in `flutter_test_app` only; not published to pub.dev.
final class AgentkitInvokeLinkListener {
  AgentkitInvokeLinkListener({required this.onQualifiedName});

  final void Function(String qualifiedName) onQualifiedName;

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  /// Parses [uri] when scheme is `agentkit` and host is `invoke`.
  static String? qualifiedNameFromUri(final Uri uri) {
    if (uri.scheme != 'agentkit') {
      return null;
    }
    if (uri.host != 'invoke') {
      return null;
    }
    final raw = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> start() async {
    if (kIsWeb) {
      return;
    }
    final initial = await _appLinks.getInitialLink();
    if (initial != null) {
      _handle(initial);
    }
    _subscription = _appLinks.uriLinkStream.listen(_handle);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  void _handle(final Uri uri) {
    final name = qualifiedNameFromUri(uri);
    if (name != null) {
      onQualifiedName(name);
    }
  }
}
