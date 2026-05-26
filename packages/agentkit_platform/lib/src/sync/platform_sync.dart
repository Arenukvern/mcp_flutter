import 'dart:io';

import 'package:path/path.dart' as p;

import '../agent_manifest.dart';
import '../emitters/web_manifest_emitter.dart';
import '../emitters/web_mcp_js_emitter.dart';

/// Result of syncing web platform artifacts into a Flutter project.
final class PlatformSyncResult {
  const PlatformSyncResult({
    required this.manifestPath,
    required this.webManifestPath,
    required this.webMcpJsPath,
    required this.wroteManifest,
    required this.wroteWebMcpJs,
  });

  final String manifestPath;
  final String webManifestPath;
  final String webMcpJsPath;
  final bool wroteManifest;
  final bool wroteWebMcpJs;
}

/// Writes web manifest + WebMCP JS from [agent_manifest.json].
final class PlatformSync {
  const PlatformSync({
    this.manifestFileName = 'agent_manifest.json',
    this.webDirName = 'web',
    this.webManifestFileName = 'manifest.json',
    this.webMcpJsFileName = 'agentkit_webmcp.generated.js',
    this.webManifestEmitter = const WebManifestEmitter(),
    this.webMcpJsEmitter = const WebMcpJsEmitter(),
  });

  final String manifestFileName;
  final String webDirName;
  final String webManifestFileName;
  final String webMcpJsFileName;
  final WebManifestEmitter webManifestEmitter;
  final WebMcpJsEmitter webMcpJsEmitter;

  AgentManifest readManifest(final String projectRoot) {
    final manifestFile = _resolveManifestFile(projectRoot);
    if (!manifestFile.existsSync()) {
      throw StateError(
        'Missing $manifestFileName at ${manifestFile.path}. '
        'Generate it from registry descriptors first.',
      );
    }
    return AgentManifest.parse(manifestFile.readAsStringSync());
  }

  PlatformSyncResult syncWeb({
    required final String projectRoot,
    final bool dryRun = false,
  }) {
    final manifest = readManifest(projectRoot);
    final webDir = Directory(p.join(projectRoot, webDirName));
    if (!webDir.existsSync()) {
      throw StateError('Missing web/ directory under $projectRoot');
    }

    final webManifestFile = File(p.join(webDir.path, webManifestFileName));
    if (!webManifestFile.existsSync()) {
      throw StateError('Missing ${webManifestFile.path}');
    }

    final nextManifest = webManifestEmitter.emit(
      existingManifestJson: webManifestFile.readAsStringSync(),
      manifest: manifest,
    );
    final nextJs = webMcpJsEmitter.emit(manifest);
    final jsFile = File(p.join(webDir.path, webMcpJsFileName));

    var wroteManifest = false;
    var wroteJs = false;
    if (!dryRun) {
      if (webManifestFile.readAsStringSync() != nextManifest) {
        webManifestFile.writeAsStringSync('$nextManifest\n');
        wroteManifest = true;
      }
      if (!jsFile.existsSync() || jsFile.readAsStringSync() != nextJs) {
        jsFile.writeAsStringSync(nextJs);
        wroteJs = true;
      }
    }

    return PlatformSyncResult(
      manifestPath: _resolveManifestFile(projectRoot).path,
      webManifestPath: webManifestFile.path,
      webMcpJsPath: jsFile.path,
      wroteManifest: wroteManifest,
      wroteWebMcpJs: wroteJs,
    );
  }

  /// Returns `true` when generated outputs already match emitters.
  bool checkWeb(final String projectRoot) {
    final manifest = readManifest(projectRoot);
    final webDir = p.join(projectRoot, webDirName);
    final webManifestFile = File(p.join(webDir, webManifestFileName));
    final jsFile = File(p.join(webDir, webMcpJsFileName));
    final expectedManifest = webManifestEmitter.emit(
      existingManifestJson: webManifestFile.readAsStringSync(),
      manifest: manifest,
    );
    final expectedJs = webMcpJsEmitter.emit(manifest);
    final manifestOk =
        webManifestFile.existsSync() &&
        webManifestFile.readAsStringSync() == '$expectedManifest\n';
    final jsOk = jsFile.existsSync() && jsFile.readAsStringSync() == expectedJs;
    return manifestOk && jsOk;
  }

  File _resolveManifestFile(final String projectRoot) {
    final rootCandidate = File(p.join(projectRoot, manifestFileName));
    if (rootCandidate.existsSync()) {
      return rootCandidate;
    }
    return File(p.join(projectRoot, webDirName, manifestFileName));
  }
}

/// Snippet to inject into `web/index.html` once.
const kAgentkitWebIndexSnippet = '''
<!-- agentkit-platform: begin -->
<script src="agentkit_webmcp.generated.js" defer></script>
<!-- agentkit-platform: end -->
''';
