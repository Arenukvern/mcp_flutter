import 'dart:io';

import 'package:path/path.dart' as p;

import '../agent_manifest.dart';
import '../emitters/android_shortcuts_xml_emitter.dart';
import '../emitters/apple_swift_app_intents_emitter.dart';
import '../emitters/linux_desktop_entry_emitter.dart';
import '../emitters/web_manifest_emitter.dart';
import '../emitters/web_mcp_js_emitter.dart';
import '../emitters/windows_protocol_emitter.dart';

/// Supported `codegen sync --platform` values.
const kPlatformSyncTargets = <String>{
  'web',
  'android',
  'ios',
  'macos',
  'linux',
  'windows',
};

/// Result of syncing platform artifacts into a Flutter project.
final class PlatformSyncResult {
  const PlatformSyncResult({
    required this.manifestPath,
    this.webManifestPath,
    this.webMcpJsPath,
    this.androidShortcutsPath,
    this.iosGeneratedSwiftPath,
    this.macosGeneratedSwiftPath,
    this.linuxDesktopPath,
    this.windowsProtocolPath,
    this.windowsMsixFragmentPath,
    this.wroteManifest = false,
    this.wroteWebMcpJs = false,
    this.wroteAndroidShortcuts = false,
    this.wroteIosGenerated = false,
    this.wroteMacosGenerated = false,
    this.wroteLinuxDesktop = false,
    this.wroteWindowsProtocol = false,
    this.wroteWindowsMsixFragment = false,
  });

  final String manifestPath;
  final String? webManifestPath;
  final String? webMcpJsPath;
  final String? androidShortcutsPath;
  final String? iosGeneratedSwiftPath;
  final String? macosGeneratedSwiftPath;
  final String? linuxDesktopPath;
  final String? windowsProtocolPath;
  final String? windowsMsixFragmentPath;
  final bool wroteManifest;
  final bool wroteWebMcpJs;
  final bool wroteAndroidShortcuts;
  final bool wroteIosGenerated;
  final bool wroteMacosGenerated;
  final bool wroteLinuxDesktop;
  final bool wroteWindowsProtocol;
  final bool wroteWindowsMsixFragment;
}

/// Writes platform artifacts from [agent_manifest.json].
final class PlatformSync {
  const PlatformSync({
    this.manifestFileName = 'agent_manifest.json',
    this.webDirName = 'web',
    this.androidDirName = 'android',
    this.iosDirName = 'ios',
    this.macosDirName = 'macos',
    this.linuxDirName = 'linux',
    this.windowsDirName = 'windows',
    this.webManifestFileName = 'manifest.json',
    this.webMcpJsFileName = 'agentkit_webmcp.generated.js',
    this.androidShortcutsFileName = 'agentkit_shortcuts.xml',
    this.appleGeneratedFileName = 'AgentKitGenerated.swift',
    this.linuxDesktopFileName = 'agentkit_protocol.desktop',
    this.windowsProtocolFileName = 'agentkit_protocol.reg',
    this.windowsMsixFragmentFileName = 'agentkit_protocol_msix.xml',
    this.webManifestEmitter = const WebManifestEmitter(),
    this.webMcpJsEmitter = const WebMcpJsEmitter(),
    this.androidShortcutsEmitter = const AndroidShortcutsXmlEmitter(),
    this.appleSwiftEmitter = const AppleSwiftAppIntentsEmitter(),
    this.linuxDesktopEmitter = const LinuxDesktopEntryEmitter(),
    this.windowsProtocolEmitter = const WindowsProtocolEmitter(),
  });

  final String manifestFileName;
  final String webDirName;
  final String androidDirName;
  final String iosDirName;
  final String macosDirName;
  final String linuxDirName;
  final String windowsDirName;
  final String webManifestFileName;
  final String webMcpJsFileName;
  final String androidShortcutsFileName;
  final String appleGeneratedFileName;
  final String linuxDesktopFileName;
  final String windowsProtocolFileName;
  final String windowsMsixFragmentFileName;
  final WebManifestEmitter webManifestEmitter;
  final WebMcpJsEmitter webMcpJsEmitter;
  final AndroidShortcutsXmlEmitter androidShortcutsEmitter;
  final AppleSwiftAppIntentsEmitter appleSwiftEmitter;
  final LinuxDesktopEntryEmitter linuxDesktopEmitter;
  final WindowsProtocolEmitter windowsProtocolEmitter;

  AgentManifest readManifest(final String projectRoot) {
    final manifestFile = _resolveManifestFile(projectRoot);
    if (!manifestFile.existsSync()) {
      throw StateError(
        'Missing $manifestFileName at ${manifestFile.path}. '
        'Maintain web/agent_manifest.json (or project-root copy) from your '
        'agent descriptor list, or run `flutter-mcp-toolkit codegen sync`.',
      );
    }
    return AgentManifest.parse(manifestFile.readAsStringSync());
  }

  /// Syncs one or more platforms; returns merged [PlatformSyncResult].
  PlatformSyncResult syncPlatforms({
    required final String projectRoot,
    required final Iterable<String> platforms,
    final bool dryRun = false,
  }) {
    final normalized = platforms
        .map((final value) => value.trim().toLowerCase())
        .where((final value) => value.isNotEmpty)
        .toSet();
    final unknown = normalized.difference(kPlatformSyncTargets);
    if (unknown.isNotEmpty) {
      throw ArgumentError('Unsupported platform(s): ${unknown.join(', ')}');
    }

    var result = PlatformSyncResult(
      manifestPath: _resolveManifestFile(projectRoot).path,
    );
    for (final platform in normalized) {
      result = _mergeResults(
        result,
        switch (platform) {
          'web' => syncWeb(projectRoot: projectRoot, dryRun: dryRun),
          'android' => syncAndroid(projectRoot: projectRoot, dryRun: dryRun),
          'ios' => syncIos(projectRoot: projectRoot, dryRun: dryRun),
          'macos' => syncMacos(projectRoot: projectRoot, dryRun: dryRun),
          'linux' => syncLinux(projectRoot: projectRoot, dryRun: dryRun),
          'windows' => syncWindows(projectRoot: projectRoot, dryRun: dryRun),
          _ => throw StateError('unreachable'),
        },
      );
    }
    return result;
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
      if (webManifestFile.readAsStringSync() != '$nextManifest\n') {
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

  PlatformSyncResult syncAndroid({
    required final String projectRoot,
    final bool dryRun = false,
  }) {
    final manifest = readManifest(projectRoot);
    final outFile = _androidShortcutsFile(projectRoot);
    final next = '${androidShortcutsEmitter.emit(manifest)}\n';
    var wrote = false;
    if (!dryRun) {
      outFile.parent.createSync(recursive: true);
      if (!outFile.existsSync() || outFile.readAsStringSync() != next) {
        outFile.writeAsStringSync(next);
        wrote = true;
      }
    }
    return PlatformSyncResult(
      manifestPath: _resolveManifestFile(projectRoot).path,
      androidShortcutsPath: outFile.path,
      wroteAndroidShortcuts: wrote,
    );
  }

  PlatformSyncResult syncIos({
    required final String projectRoot,
    final bool dryRun = false,
  }) => _syncApple(
    projectRoot: projectRoot,
    appleRoot: p.join(projectRoot, iosDirName),
    isMacos: false,
    dryRun: dryRun,
  );

  PlatformSyncResult syncMacos({
    required final String projectRoot,
    final bool dryRun = false,
  }) => _syncApple(
    projectRoot: projectRoot,
    appleRoot: p.join(projectRoot, macosDirName),
    isMacos: true,
    dryRun: dryRun,
  );

  PlatformSyncResult syncLinux({
    required final String projectRoot,
    final bool dryRun = false,
  }) {
    final manifest = readManifest(projectRoot);
    final linuxDir = Directory(p.join(projectRoot, linuxDirName));
    if (!linuxDir.existsSync()) {
      throw StateError('Missing linux/ directory under $projectRoot');
    }
    final outFile = File(p.join(linuxDir.path, linuxDesktopFileName));
    final next = linuxDesktopEmitter.emit(manifest);
    var wrote = false;
    if (!dryRun) {
      if (!outFile.existsSync() || outFile.readAsStringSync() != next) {
        outFile.writeAsStringSync(next);
        wrote = true;
      }
    }
    return PlatformSyncResult(
      manifestPath: _resolveManifestFile(projectRoot).path,
      linuxDesktopPath: outFile.path,
      wroteLinuxDesktop: wrote,
    );
  }

  PlatformSyncResult syncWindows({
    required final String projectRoot,
    final bool dryRun = false,
  }) {
    final manifest = readManifest(projectRoot);
    final windowsDir = Directory(p.join(projectRoot, windowsDirName));
    if (!windowsDir.existsSync()) {
      throw StateError('Missing windows/ directory under $projectRoot');
    }
    final regFile = File(p.join(windowsDir.path, windowsProtocolFileName));
    final msixFile = File(p.join(windowsDir.path, windowsMsixFragmentFileName));
    final nextReg = windowsProtocolEmitter.emit(manifest);
    final nextMsix = windowsProtocolEmitter.emitMsixFragment(manifest);
    var wroteReg = false;
    var wroteMsix = false;
    if (!dryRun) {
      if (!regFile.existsSync() || regFile.readAsStringSync() != nextReg) {
        regFile.writeAsStringSync(nextReg);
        wroteReg = true;
      }
      if (!msixFile.existsSync() || msixFile.readAsStringSync() != nextMsix) {
        msixFile.writeAsStringSync(nextMsix);
        wroteMsix = true;
      }
    }
    return PlatformSyncResult(
      manifestPath: _resolveManifestFile(projectRoot).path,
      windowsProtocolPath: regFile.path,
      windowsMsixFragmentPath: msixFile.path,
      wroteWindowsProtocol: wroteReg,
      wroteWindowsMsixFragment: wroteMsix,
    );
  }

  bool checkPlatforms(
    final String projectRoot,
    final Iterable<String> platforms,
  ) {
    for (final platform in platforms) {
      final ok = switch (platform.trim().toLowerCase()) {
        'web' => checkWeb(projectRoot),
        'android' => checkAndroid(projectRoot),
        'ios' => checkIos(projectRoot),
        'macos' => checkMacos(projectRoot),
        'linux' => checkLinux(projectRoot),
        'windows' => checkWindows(projectRoot),
        _ => false,
      };
      if (!ok) {
        return false;
      }
    }
    return true;
  }

  /// Returns `true` when generated web outputs already match emitters.
  bool checkWeb(final String projectRoot) {
    final manifest = readManifest(projectRoot);
    final webDir = p.join(projectRoot, webDirName);
    final webManifestFile = File(p.join(webDir, webManifestFileName));
    final jsFile = File(p.join(webDir, webMcpJsFileName));
    if (!webManifestFile.existsSync() || !jsFile.existsSync()) {
      return false;
    }
    final expectedManifest = webManifestEmitter.emit(
      existingManifestJson: webManifestFile.readAsStringSync(),
      manifest: manifest,
    );
    final expectedJs = webMcpJsEmitter.emit(manifest);
    return webManifestFile.readAsStringSync() == '$expectedManifest\n' &&
        jsFile.readAsStringSync() == expectedJs;
  }

  bool checkAndroid(final String projectRoot) {
    final manifest = readManifest(projectRoot);
    final file = _androidShortcutsFile(projectRoot);
    if (!file.existsSync()) {
      return false;
    }
    return file.readAsStringSync() ==
        '${androidShortcutsEmitter.emit(manifest)}\n';
  }

  bool checkIos(final String projectRoot) =>
      _checkApple(projectRoot: projectRoot, appleRoot: iosDirName);

  bool checkMacos(final String projectRoot) =>
      _checkApple(projectRoot: projectRoot, appleRoot: macosDirName);

  bool checkLinux(final String projectRoot) {
    final manifest = readManifest(projectRoot);
    final file = File(
      p.join(projectRoot, linuxDirName, linuxDesktopFileName),
    );
    if (!file.existsSync()) {
      return false;
    }
    return file.readAsStringSync() == linuxDesktopEmitter.emit(manifest);
  }

  bool checkWindows(final String projectRoot) {
    final manifest = readManifest(projectRoot);
    final reg = File(
      p.join(projectRoot, windowsDirName, windowsProtocolFileName),
    );
    final msix = File(
      p.join(projectRoot, windowsDirName, windowsMsixFragmentFileName),
    );
    if (!reg.existsSync() || !msix.existsSync()) {
      return false;
    }
    return reg.readAsStringSync() ==
            windowsProtocolEmitter.emit(manifest) &&
        msix.readAsStringSync() ==
            windowsProtocolEmitter.emitMsixFragment(manifest);
  }

  PlatformSyncResult _syncApple({
    required final String projectRoot,
    required final String appleRoot,
    required final bool isMacos,
    required final bool dryRun,
  }) {
    final manifest = readManifest(projectRoot);
    final rootDir = Directory(appleRoot);
    if (!rootDir.existsSync()) {
      throw StateError('Missing $appleRoot directory under $projectRoot');
    }
    final generatedDir = Directory(p.join(appleRoot, 'Runner', 'Generated'))
      ..createSync(recursive: true);
    final outFile = File(p.join(generatedDir.path, appleGeneratedFileName));
    final next = '${appleSwiftEmitter.emit(manifest)}\n';
    var wrote = false;
    if (!dryRun) {
      if (!outFile.existsSync() || outFile.readAsStringSync() != next) {
        outFile.writeAsStringSync(next);
        wrote = true;
      }
    }
    return PlatformSyncResult(
      manifestPath: _resolveManifestFile(projectRoot).path,
      iosGeneratedSwiftPath: isMacos ? null : outFile.path,
      macosGeneratedSwiftPath: isMacos ? outFile.path : null,
      wroteIosGenerated: !isMacos && wrote,
      wroteMacosGenerated: isMacos && wrote,
    );
  }

  bool _checkApple({
    required final String projectRoot,
    required final String appleRoot,
  }) {
    final manifest = readManifest(projectRoot);
    final file = File(
      p.join(
        projectRoot,
        appleRoot,
        'Runner',
        'Generated',
        appleGeneratedFileName,
      ),
    );
    if (!file.existsSync()) {
      return false;
    }
    return file.readAsStringSync() == '${appleSwiftEmitter.emit(manifest)}\n';
  }

  File _androidShortcutsFile(final String projectRoot) => File(
    p.join(
      projectRoot,
      androidDirName,
      'app',
      'src',
      'main',
      'res',
      'xml',
      androidShortcutsFileName,
    ),
  );

  PlatformSyncResult _mergeResults(
    final PlatformSyncResult left,
    final PlatformSyncResult right,
  ) =>
      PlatformSyncResult(
        manifestPath: left.manifestPath,
        webManifestPath: right.webManifestPath ?? left.webManifestPath,
        webMcpJsPath: right.webMcpJsPath ?? left.webMcpJsPath,
        androidShortcutsPath:
            right.androidShortcutsPath ?? left.androidShortcutsPath,
        iosGeneratedSwiftPath:
            right.iosGeneratedSwiftPath ?? left.iosGeneratedSwiftPath,
        macosGeneratedSwiftPath:
            right.macosGeneratedSwiftPath ?? left.macosGeneratedSwiftPath,
        linuxDesktopPath: right.linuxDesktopPath ?? left.linuxDesktopPath,
        windowsProtocolPath:
            right.windowsProtocolPath ?? left.windowsProtocolPath,
        windowsMsixFragmentPath:
            right.windowsMsixFragmentPath ?? left.windowsMsixFragmentPath,
        wroteManifest: left.wroteManifest || right.wroteManifest,
        wroteWebMcpJs: left.wroteWebMcpJs || right.wroteWebMcpJs,
        wroteAndroidShortcuts:
            left.wroteAndroidShortcuts || right.wroteAndroidShortcuts,
        wroteIosGenerated: left.wroteIosGenerated || right.wroteIosGenerated,
        wroteMacosGenerated:
            left.wroteMacosGenerated || right.wroteMacosGenerated,
        wroteLinuxDesktop: left.wroteLinuxDesktop || right.wroteLinuxDesktop,
        wroteWindowsProtocol:
            left.wroteWindowsProtocol || right.wroteWindowsProtocol,
        wroteWindowsMsixFragment:
            left.wroteWindowsMsixFragment || right.wroteWindowsMsixFragment,
      );

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
