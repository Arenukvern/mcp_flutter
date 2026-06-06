import 'dart:convert';
import 'dart:io';

import 'package:intentcall_platform/intentcall_platform.dart';

/// Runs `flutter-mcp-toolkit codegen sync --platform <targets>`.
Future<int> runCodegenSync({
  required final String platform,
  required final String projectRoot,
  final bool checkOnly = false,
}) async {
  final platforms = platform
      .split(',')
      .map((final value) => value.trim().toLowerCase())
      .where((final value) => value.isNotEmpty)
      .toList();
  if (platforms.isEmpty) {
    stderr.writeln('Missing --platform (e.g. web,android,ios)');
    return 64;
  }

  final unknown = platforms.toSet().difference(kPlatformSyncTargets);
  if (unknown.isNotEmpty) {
    stderr.writeln(
      'Unsupported platform(s): ${unknown.join(', ')}. '
      'Supported: ${kPlatformSyncTargets.join(', ')}',
    );
    return 64;
  }

  const sync = PlatformSync();
  try {
    if (checkOnly) {
      final ok = sync.checkPlatforms(projectRoot, platforms);
      stdout.writeln(
        jsonEncode(<String, Object?>{
          'ok': ok,
          'platforms': platforms,
          'projectRoot': projectRoot,
        }),
      );
      return ok ? 0 : 1;
    }

    final result = sync.syncPlatforms(
      projectRoot: projectRoot,
      platforms: platforms,
    );
    stdout.writeln(
      jsonEncode(<String, Object?>{
        'ok': true,
        'platforms': platforms,
        'projectRoot': projectRoot,
        'manifestPath': result.manifestPath,
        if (result.webManifestPath != null)
          'webManifestPath': result.webManifestPath,
        if (result.webMcpJsPath != null) 'webMcpJsPath': result.webMcpJsPath,
        if (result.androidShortcutsPath != null)
          'androidShortcutsPath': result.androidShortcutsPath,
        if (result.iosGeneratedSwiftPath != null)
          'iosGeneratedSwiftPath': result.iosGeneratedSwiftPath,
        if (result.macosGeneratedSwiftPath != null)
          'macosGeneratedSwiftPath': result.macosGeneratedSwiftPath,
        if (result.linuxDesktopPath != null)
          'linuxDesktopPath': result.linuxDesktopPath,
        if (result.windowsProtocolPath != null)
          'windowsProtocolPath': result.windowsProtocolPath,
        'wroteManifest': result.wroteManifest,
        'wroteWebMcpJs': result.wroteWebMcpJs,
        'wroteAndroidShortcuts': result.wroteAndroidShortcuts,
        'wroteIosGenerated': result.wroteIosGenerated,
        'wroteMacosGenerated': result.wroteMacosGenerated,
        'wroteLinuxDesktop': result.wroteLinuxDesktop,
        'wroteWindowsProtocol': result.wroteWindowsProtocol,
        if (platforms.contains('web'))
          'indexHtmlSnippet': kIntentCallWebIndexSnippet,
        if (platforms.contains('android'))
          'androidManifestSnippet': kAndroidShortcutsManifestSnippet,
        if (platforms.contains('android'))
          'androidGradleHook': kAndroidGradleCodegenHook,
        if (platforms.contains('ios') || platforms.contains('macos'))
          'xcodeRunScript': kAppleXcodeCodegenRunScript,
      }),
    );
    return 0;
  } on Object catch (error) {
    stderr.writeln('codegen sync failed: $error');
    return 1;
  }
}
