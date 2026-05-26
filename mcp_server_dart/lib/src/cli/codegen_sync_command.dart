import 'dart:convert';
import 'dart:io';

import 'package:agentkit_platform/agentkit_platform.dart';

/// Runs `flutter-mcp-toolkit codegen sync --platform web`.
Future<int> runCodegenSync({
  required final String platform,
  required final String projectRoot,
  final bool checkOnly = false,
}) async {
  final platforms = platform
      .split(',')
      .map((final value) => value.trim())
      .where((final value) => value.isNotEmpty)
      .toList();
  if (platforms.length != 1 || platforms.single != 'web') {
    stderr.writeln(
      'Phase 6d-web supports only --platform web (got: ${platforms.join(',')})',
    );
    return 64;
  }

  const sync = PlatformSync();
  try {
    if (checkOnly) {
      final ok = sync.checkWeb(projectRoot);
      stdout.writeln(
        jsonEncode(<String, Object?>{
          'ok': ok,
          'platform': 'web',
          'projectRoot': projectRoot,
        }),
      );
      return ok ? 0 : 1;
    }

    final result = sync.syncWeb(projectRoot: projectRoot);
    stdout.writeln(
      jsonEncode(<String, Object?>{
        'ok': true,
        'platform': 'web',
        'projectRoot': projectRoot,
        'manifestPath': result.manifestPath,
        'webManifestPath': result.webManifestPath,
        'webMcpJsPath': result.webMcpJsPath,
        'wroteManifest': result.wroteManifest,
        'wroteWebMcpJs': result.wroteWebMcpJs,
        'indexHtmlSnippet': kAgentkitWebIndexSnippet,
      }),
    );
    return 0;
  } on Object catch (error) {
    stderr.writeln('codegen sync failed: $error');
    return 1;
  }
}
