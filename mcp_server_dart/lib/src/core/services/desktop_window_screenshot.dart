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
    int? targetPid,
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

final class DesktopWindowCaptureException implements Exception {
  const DesktopWindowCaptureException({
    required this.message,
    this.details = const <String, Object?>{},
  });

  final String message;
  final Map<String, Object?> details;

  @override
  String toString() => message;
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
    final int? targetPid,
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
      trailing: <String>[
        if (targetPid != null) ...<String>['--pid', '$targetPid'],
        ...appNames,
      ],
    );
    if (payload['ok'] != true) {
      throw DesktopWindowCaptureException(
        message:
            'macOS desktop window capture failed: ${payload['error'] ?? payload}',
        details: _asObject(payload['details']),
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
        'windowOwnerPid': payload['windowOwnerPid'],
        'windowId': payload['windowId'],
        'windowTitle': payload['windowTitle'],
        'windowBounds': _asObject(payload['windowBounds']),
        'windowSelectionSource': payload['windowSelectionSource'],
        'windowCaptureVisibility': payload['windowCaptureVisibility'],
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
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data([0x0A]))
    Foundation.exit(0)
}

func normalizeOwnerName(_ value: String) -> String {
    return value.lowercased().replacingOccurrences(
        of: "[^a-z0-9]+",
        with: "",
        options: .regularExpression
    )
}

func matchesCandidate(_ value: String, candidates: Set<String>) -> Bool {
    let normalized = normalizeOwnerName(value)
    if normalized.isEmpty {
        return false
    }
    for candidate in candidates {
        let normalizedCandidate = normalizeOwnerName(candidate)
        if normalizedCandidate.isEmpty {
            continue
        }
        if normalized == normalizedCandidate ||
            normalized.contains(normalizedCandidate) ||
            normalizedCandidate.contains(normalized) {
            return true
        }
    }
    return false
}

func matchesOwner(_ owner: String, candidates: Set<String>) -> Bool {
    if candidates.isEmpty {
        return true
    }
    return matchesCandidate(owner, candidates: candidates)
}

func matchesWindow(
    _ window: SCWindow,
    candidates: Set<String>,
    expectedPid: Int32?
) -> Bool {
    if let expectedPid {
        return window.owningApplication?.processID == expectedPid
    }
    if candidates.isEmpty {
        return true
    }
    let owner = window.owningApplication?.applicationName ?? ""
    let title = window.title ?? ""
    return matchesCandidate(owner, candidates: candidates) ||
        matchesCandidate(title, candidates: candidates)
}

func eligibleWindows(
    _ windows: [SCWindow],
    candidates: Set<String>,
    expectedPid: Int32?
) -> [SCWindow] {
    return windows.filter { window in
        let frame = window.frame
        return matchesWindow(
            window,
            candidates: candidates,
            expectedPid: expectedPid
        ) &&
            frame.width > 8 &&
            frame.height > 8
    }
}

func largestWindow(_ windows: [SCWindow]) -> SCWindow? {
    return windows.max { lhs, rhs in
        lhs.frame.width * lhs.frame.height < rhs.frame.width * rhs.frame.height
    }
}

func windowSummary(_ window: SCWindow) -> [String: Any] {
    [
        "owner": window.owningApplication?.applicationName ?? "",
        "ownerPid": Int(window.owningApplication?.processID ?? 0),
        "title": window.title ?? "",
        "width": window.frame.size.width,
        "height": window.frame.size.height,
        "windowId": Int(window.windowID),
    ]
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

@MainActor
func capture(candidates: Set<String>, expectedPid: Int32?) async {
    _ = NSApplication.shared

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
        let onScreenContent = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        let onScreenMatches = eligibleWindows(
            onScreenContent.windows,
            candidates: candidates,
            expectedPid: expectedPid
        )
        var selectionSource = "on_screen"
        var captureVisibility = "on_screen"
        var selectedWindow = largestWindow(onScreenMatches)
        var allWindowsContent: SCShareableContent?

        if selectedWindow == nil {
            let anyContent = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: false
            )
            allWindowsContent = anyContent
            let allMatches = eligibleWindows(
                anyContent.windows,
                candidates: candidates,
                expectedPid: expectedPid
            )
            selectedWindow = largestWindow(allMatches)
            if selectedWindow != nil {
                selectionSource = "all_windows_fallback"
                captureVisibility = "offscreen_or_hidden"
            }
        }

        guard let window = selectedWindow else {
            let visibleOwners = Array(Set(onScreenContent.windows.compactMap {
                let owner = $0.owningApplication?.applicationName ?? ""
                return owner.isEmpty ? nil : owner
            })).sorted()
            let visibleWindows = onScreenContent.windows.prefix(20).map(windowSummary)
            let allOwners = Array(Set((allWindowsContent?.windows ?? []).compactMap {
                let owner = $0.owningApplication?.applicationName ?? ""
                return owner.isEmpty ? nil : owner
            })).sorted()
            let allCandidateWindows = eligibleWindows(
                allWindowsContent?.windows ?? [],
                candidates: candidates,
                expectedPid: expectedPid
            ).prefix(20).map(windowSummary)
            var details: [String: Any] = [
                "candidates": Array(candidates).sorted(),
                "visibleOwners": visibleOwners,
                "visibleWindows": Array(visibleWindows),
                "allOwners": allOwners,
                "allCandidateWindows": Array(allCandidateWindows),
            ]
            if let expectedPid {
                details["expectedPid"] = Int(expectedPid)
            }
            emit([
                "ok": false,
                "error": "window_not_found",
                "details": details,
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
            "windowOwnerPid": Int(window.owningApplication?.processID ?? 0),
            "windowId": Int(window.windowID),
            "windowTitle": window.title ?? "",
            "windowSelectionSource": selectionSource,
            "windowCaptureVisibility": captureVisibility,
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
            var expectedPid: Int32?
            var candidates = Set<String>()
            var index = 1
            while index < args.count {
                let argument = args[index]
                if argument == "--pid", index + 1 < args.count {
                    expectedPid = Int32(args[index + 1])
                    index += 2
                    continue
                }
                candidates.insert(argument.lowercased())
                index += 1
            }
            await capture(candidates: candidates, expectedPid: expectedPid)
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
