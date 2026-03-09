import 'dart:convert';
import 'dart:io';

import 'package:flutter_inspector_mcp_server/src/core/core_types.dart';
import 'package:flutter_inspector_mcp_server/src/core/visual_capture.dart';
import 'package:path/path.dart' as path;

typedef RunProcessFn =
    Future<ProcessResult> Function(String executable, List<String> arguments);

abstract interface class DesktopWindowScreenshotService {
  Future<DesktopWindowScreenshotCapture?> capture({
    required String projectDir,
    required String device,
    required bool compress,
    String? cacheDir,
  });
}

final class DesktopWindowScreenshotCapture {
  const DesktopWindowScreenshotCapture({
    required this.images,
    required this.captureMode,
    this.metadata = const <String, Object?>{},
  });

  final List<String> images;
  final String captureMode;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson({
    required List<String> fileUrls,
    final bool includeImages = true,
  }) => <String, Object?>{
    'images': includeImages ? images : const <String>[],
    'fileUrls': fileUrls,
    'captureMode': captureMode,
    ...metadata,
  };
}

final class MacOsDesktopWindowScreenshotService
    implements DesktopWindowScreenshotService, VisualCapturePlatformAdapter {
  MacOsDesktopWindowScreenshotService({RunProcessFn? runProcess})
    : _runProcess = runProcess ?? _defaultRunProcess;

  final RunProcessFn _runProcess;

  @override
  String get backend => 'macos_host';

  @override
  Set<CaptureCapability> get capabilities => const <CaptureCapability>{
    CaptureCapability.desktopWindow,
    CaptureCapability.flutterLayer,
  };

  @override
  PermissionOwner get owner => PermissionOwner.host;

  @override
  Set<String> get supportedModes => const <String>{
    screenshotModeDesktopWindow,
    screenshotModeFlutterLayer,
  };

  @override
  String get truthMode => screenshotModeDesktopWindow;

  @override
  bool supportsPlatform(final String effectivePlatform) =>
      effectivePlatform == 'macos';

  @override
  Future<PermissionBrokerResult> status({
    required final PermissionKind kind,
    required final PermissionPolicy policy,
    required final CoreRuntimeConfiguration configuration,
  }) async {
    final payload = await _runHelper(
      command: 'status',
      cacheDir: _cacheDir(configuration.stateRootDir),
    );
    return _permissionResultFromHelperPayload(
      payload: payload,
      kind: kind,
      policy: policy,
      fallbackStatus: PermissionStatus.notDetermined,
    );
  }

  @override
  Future<PermissionBrokerResult> request({
    required final PermissionKind kind,
    required final PermissionPolicy policy,
    required final CoreRuntimeConfiguration configuration,
  }) async {
    final payload = await _runHelper(
      command: 'request',
      cacheDir: _cacheDir(configuration.stateRootDir),
    );
    return _permissionResultFromHelperPayload(
      payload: payload,
      kind: kind,
      policy: policy,
      fallbackStatus: PermissionStatus.denied,
    );
  }

  @override
  Future<PermissionBrokerResult> openSettings({
    required final PermissionKind kind,
    required final PermissionPolicy policy,
    required final CoreRuntimeConfiguration configuration,
  }) async {
    final payload = await _runHelper(
      command: 'open-settings',
      cacheDir: _cacheDir(configuration.stateRootDir),
    );
    return _permissionResultFromHelperPayload(
      payload: payload,
      kind: kind,
      policy: policy,
      fallbackStatus: PermissionStatus.denied,
    );
  }

  @override
  Future<DesktopWindowScreenshotCapture?> capture({
    required final String projectDir,
    required final String device,
    required final bool compress,
    final String? cacheDir,
  }) async {
    if (device != 'macos') {
      return null;
    }

    final appNames = inferMacOsAppCandidates(projectDir: projectDir);
    if (appNames.isEmpty) {
      return null;
    }

    final payload = await _runHelper(
      command: 'capture',
      cacheDir: cacheDir,
      trailing: <String>[...appNames],
    );
    if (payload['ok'] != true) {
      throw Exception(
        'macOS desktop window capture failed: ${payload['error'] ?? payload}',
      );
    }

    final pngBase64 = payload['pngBase64'];
    if (pngBase64 is! String || pngBase64.isEmpty) {
      return null;
    }

    return DesktopWindowScreenshotCapture(
      images: <String>[pngBase64],
      captureMode: screenshotModeDesktopWindow,
      metadata: <String, Object?>{
        'appName': payload['appName'],
        'windowId': payload['windowId'],
        'windowBounds': _asObject(payload['windowBounds']),
        'permissionStatus': payload['permissionStatus'],
        'requestedCompress': compress,
      },
    );
  }

  Future<Map<String, Object?>> _runHelper({
    required final String command,
    required final String? cacheDir,
    final List<String> trailing = const <String>[],
  }) async {
    final binaryPath = await _resolveHelperBinary(cacheDir: cacheDir);
    final result = await _runProcess(binaryPath, <String>[
      command,
      ...trailing,
    ]);
    if (result.exitCode != 0) {
      throw Exception(
        'macOS visual capture helper failed: ${result.stderr}'.trim(),
      );
    }
    return _parsePayload('${result.stdout}');
  }

  Future<String> _resolveHelperBinary({required final String? cacheDir}) async {
    final helperDir = Directory(
      path.join(cacheDir ?? _fallbackCacheDir(), 'cache', 'macos_helper'),
    )..createSync(recursive: true);
    final hash = helperSourceHash(_swiftVisualCaptureHelperSource);
    final sourceFile = File(
      path.join(helperDir.path, 'macos_visual_capture_$hash.swift'),
    );
    final binaryFile = File(
      path.join(helperDir.path, 'macos_visual_capture_$hash'),
    );
    if (binaryFile.existsSync()) {
      return binaryFile.path;
    }

    sourceFile.writeAsStringSync(_swiftVisualCaptureHelperSource);
    final compile = await _runProcess('swiftc', <String>[
      '-parse-as-library',
      sourceFile.path,
      '-O',
      '-o',
      binaryFile.path,
    ]);
    if (compile.exitCode != 0) {
      throw Exception(
        'Failed to compile macOS visual capture helper: ${compile.stderr}',
      );
    }
    return binaryFile.path;
  }

  PermissionBrokerResult _permissionResultFromHelperPayload({
    required final Map<String, Object?> payload,
    required final PermissionKind kind,
    required final PermissionPolicy policy,
    required final PermissionStatus fallbackStatus,
  }) {
    final status =
        _parseHelperPermissionStatus(payload['status']) ?? fallbackStatus;
    return PermissionBrokerResult(
      kind: kind,
      status: status,
      policy: policy,
      owner: owner,
      backend: backend,
      capabilities: capabilities,
      supportedModes: supportedModes,
      truthMode: truthMode,
      message: payload['message']?.toString(),
      details: _asObject(payload['details']),
      canRequest: payload['canRequest'] == true,
      canOpenSettings: payload['canOpenSettings'] == true,
    );
  }
}

Future<ProcessResult> _defaultRunProcess(
  final String executable,
  final List<String> arguments,
) => Process.run(executable, arguments);

String helperSourceHash(final String source) {
  var hash = 0xcbf29ce484222325;
  for (final codeUnit in source.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

String _fallbackCacheDir() =>
    path.join(Directory.systemTemp.path, 'flutter_mcp_visual_capture');

String? _cacheDir(final String? stateRootDir) {
  final value = stateRootDir?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

List<String> inferMacOsAppCandidates({required final String projectDir}) {
  final candidates = <String>{};

  final debugProductsDir = Directory(
    path.join(projectDir, 'build', 'macos', 'Build', 'Products', 'Debug'),
  );
  if (debugProductsDir.existsSync()) {
    final bundles = debugProductsDir
        .listSync(followLinks: false)
        .whereType<Directory>()
        .where((final entry) => entry.path.endsWith('.app'));
    for (final bundle in bundles) {
      candidates.add(path.basenameWithoutExtension(bundle.path));
      final executableDir = Directory(
        path.join(bundle.path, 'Contents', 'MacOS'),
      );
      if (!executableDir.existsSync()) {
        continue;
      }
      for (final entity in executableDir.listSync(followLinks: false)) {
        if (entity is File) {
          candidates.add(path.basename(entity.path));
        }
      }
    }
  }

  final appInfo = File(
    path.join(projectDir, 'macos', 'Runner', 'Configs', 'AppInfo.xcconfig'),
  );
  if (appInfo.existsSync()) {
    for (final line in appInfo.readAsLinesSync()) {
      final match = RegExp(
        r'^\s*PRODUCT_NAME\s*=\s*(.+?)\s*$',
      ).firstMatch(line);
      if (match != null) {
        candidates.add(match.group(1)!.trim());
      }
    }
  }

  final sorted = candidates.where((final value) => value.isNotEmpty).toList()
    ..sort();
  return sorted;
}

Map<String, Object?> _parsePayload(final String stdoutText) {
  final trimmed = stdoutText.trim();
  if (trimmed.isEmpty) {
    return const <String, Object?>{};
  }
  final decoded = jsonDecode(trimmed);
  return _asObject(decoded);
}

Map<String, Object?> _asObject(final Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  return const <String, Object?>{};
}

PermissionStatus? _parseHelperPermissionStatus(final Object? value) {
  final normalized = '$value'.trim().toLowerCase();
  for (final candidate in PermissionStatus.values) {
    if (candidate.wireName == normalized) {
      return candidate;
    }
  }
  return null;
}

const String _swiftVisualCaptureHelperSource = r'''
import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit

func emit(_ payload: [String: Any]) {
    let data = try! JSONSerialization.data(withJSONObject: payload)
    print(String(data: data, encoding: .utf8)!)
}

func matchesOwner(_ owner: String, candidates: Set<String>) -> Bool {
    if candidates.isEmpty {
        return true
    }
    let normalized = owner.lowercased()
    for candidate in candidates {
        if normalized == candidate || normalized.contains(candidate) || candidate.contains(normalized) {
            return true
        }
    }
    return false
}

func permissionStatusPayload(_ status: String, message: String) {
    emit([
        "ok": true,
        "status": status,
        "message": message,
        "canRequest": true,
        "canOpenSettings": true,
        "details": [:],
    ])
}

func openSettings() {
    guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
        emit([
            "ok": false,
            "error": "settings_url_invalid",
        ])
        return
    }
    NSWorkspace.shared.open(url)
    emit([
        "ok": true,
        "status": "denied",
        "message": "Opened Screen Recording settings.",
        "canRequest": true,
        "canOpenSettings": true,
        "details": ["opened": true],
    ])
}

func capture(candidates: Set<String>) async {
    guard CGPreflightScreenCaptureAccess() else {
        emit([
            "ok": false,
            "error": "screen_recording_not_granted",
            "permissionStatus": "not_determined",
            "details": [
                "action": "request_permission_or_open_settings"
            ],
        ])
        return
    }

    do {
        let shareableContent = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        var selectedWindow: SCWindow?
        var selectedArea: CGFloat = -1

        for window in shareableContent.windows {
            let owner = window.owningApplication?.applicationName ?? ""
            let frame = window.frame
            guard matchesOwner(owner, candidates: candidates),
                  frame.width > 8,
                  frame.height > 8 else {
                continue
            }

            let area = frame.width * frame.height
            if area > selectedArea {
                selectedWindow = window
                selectedArea = area
            }
        }

        guard let window = selectedWindow else {
            emit([
                "ok": false,
                "error": "window_not_found",
                "details": ["candidates": Array(candidates)],
            ])
            return
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = false
        let pointPixelScale = CGFloat(filter.pointPixelScale)
        configuration.width = Int(filter.contentRect.width * pointPixelScale)
        configuration.height = Int(filter.contentRect.height * pointPixelScale)

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            emit([
                "ok": false,
                "error": "png_encoding_failed",
                "details": ["windowId": window.windowID],
            ])
            return
        }

        emit([
            "ok": true,
            "permissionStatus": "granted",
            "appName": window.owningApplication?.applicationName ?? "",
            "windowId": Int(window.windowID),
            "windowBounds": [
                "x": window.frame.origin.x,
                "y": window.frame.origin.y,
                "width": window.frame.size.width,
                "height": window.frame.size.height,
            ],
            "pngBase64": pngData.base64EncodedString(),
        ])
    } catch {
        emit([
            "ok": false,
            "error": "capture_failed",
            "details": ["message": "\(error)"],
        ])
    }
}

@main
struct VisualCaptureHelper {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let command = args.first else {
            emit([
                "ok": false,
                "error": "missing_command",
            ])
            return
        }

        switch command {
        case "status":
            permissionStatusPayload(
                CGPreflightScreenCaptureAccess() ? "granted" : "not_determined",
                message: "macOS Screen Recording preflight completed."
            )
        case "request":
            let granted = CGRequestScreenCaptureAccess()
            permissionStatusPayload(
                granted ? "granted" : "denied",
                message: granted
                    ? "Screen Recording permission granted."
                    : "Screen Recording permission not granted."
            )
        case "open-settings":
            openSettings()
        case "capture":
            let candidates = Set(args.dropFirst().map { $0.lowercased() })
            await capture(candidates: candidates)
        default:
            emit([
                "ok": false,
                "error": "unknown_command",
                "details": ["command": command],
            ])
        }
    }
}
''';
