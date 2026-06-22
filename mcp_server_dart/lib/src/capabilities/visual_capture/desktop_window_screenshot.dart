import 'dart:convert';
import 'dart:io';

import 'package:flutter_mcp_toolkit_server/src/capabilities/visual_capture/visual_capture.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/types/core_types.dart';
import 'package:path/path.dart' as path;

part 'desktop_window_capture_swift.dart';

typedef RunProcessFn =
    Future<ProcessResult> Function(String executable, List<String> arguments);

// ignore: one_member_abstracts
abstract interface class DesktopWindowScreenshotService {
  Future<DesktopWindowScreenshotCapture?> capture({
    required final String projectDir,
    required final String device,
    required final bool compress,
    final int? targetPid,
    final String? cacheDir,
  });

  Future<Map<String, Object?>> focus({
    required final String device,
    final int? targetPid,
    final String? cacheDir,
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
    required final List<String> fileUrls,
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
  MacOsDesktopWindowScreenshotService({final RunProcessFn? runProcess})
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
  bool supportsPlatform(final String effectivePlatform) {
    if (!Platform.isMacOS) {
      return false;
    }
    if (effectivePlatform == 'macos') {
      return true;
    }
    return effectivePlatform == 'ios';
  }

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
  Future<Map<String, Object?>> focus({
    required final String device,
    final int? targetPid,
    final String? cacheDir,
  }) async {
    if (!_supportsHostDevice(device)) {
      return <String, Object?>{
        'ok': false,
        'message': 'Window focus is only available on macOS host targets.',
      };
    }

    final candidates = _windowCandidates(projectDir: '', device: device);
    return _runHelper(
      command: 'focus',
      cacheDir: cacheDir,
      trailing: <String>[
        if (targetPid != null) ...<String>['--pid', '$targetPid'],
        ...candidates,
      ],
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
    if (!_supportsHostDevice(device)) {
      return null;
    }

    final appNames = _windowCandidates(projectDir: projectDir, device: device);
    if (appNames.isEmpty) {
      return null;
    }

    final focusPayload = await focus(
      device: device,
      targetPid: targetPid,
      cacheDir: cacheDir,
    );

    final payload = await _runHelper(
      command: 'capture',
      cacheDir: cacheDir,
      trailing: <String>[
        if (targetPid != null) ...<String>['--pid', '$targetPid'],
        ...appNames,
      ],
    );
    if (payload['ok'] != true) {
      final helperDetails = _asObject(payload['details']);
      throw DesktopWindowCaptureException(
        message:
            'macOS desktop window capture failed: ${payload['error'] ?? payload}',
        details: <String, Object?>{
          ...helperDetails,
          'helperError': payload['error'],
          'helperPayload': payload,
          'focus': focusPayload,
          'candidates': appNames,
          'targetPid': ?targetPid,
          'device': device,
        },
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
      final payload = _tryParsePayload('${result.stdout}');
      if (payload != null) {
        return <String, Object?>{
          ...payload,
          'helperExitCode': result.exitCode,
          if ('${result.stderr}'.trim().isNotEmpty)
            'helperStderr': '${result.stderr}'.trim(),
        };
      }
      throw DesktopWindowCaptureException(
        message: 'macOS visual capture helper failed: ${result.stderr}'.trim(),
        details: <String, Object?>{
          'command': command,
          'arguments': trailing,
          'exitCode': result.exitCode,
          'stderr': '${result.stderr}',
          'stdout': '${result.stdout}',
        },
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
  // ignore: avoid_js_rounded_ints
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

bool _supportsHostDevice(final String device) {
  if (!Platform.isMacOS) {
    return false;
  }
  switch (device) {
    case 'macos':
    case 'ios':
    case 'chrome':
    case 'web':
    case 'web-server':
      return true;
    default:
      return false;
  }
}

bool _isWebHostDevice(final String device) =>
    device == 'chrome' || device == 'web' || device == 'web-server';

List<String> _windowCandidates({
  required final String projectDir,
  required final String device,
}) {
  if (device == 'ios') {
    return inferIosSimulatorCandidates();
  }
  if (_isWebHostDevice(device)) {
    return inferChromeWindowCandidates();
  }
  return inferMacOsAppCandidates(projectDir: projectDir);
}

List<String> inferIosSimulatorCandidates() => const <String>['simulator'];

List<String> inferChromeWindowCandidates() => const <String>[
  'google chrome',
  'chromium',
  'chrome',
];

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

Map<String, Object?>? _tryParsePayload(final String stdoutText) {
  try {
    return _parsePayload(stdoutText);
  } on FormatException {
    return null;
  }
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
