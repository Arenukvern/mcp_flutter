import 'dart:convert';
import 'dart:io';

import 'package:flutter_inspector_mcp_server/flutter_mcp_core.dart';
import 'package:flutter_inspector_mcp_server/src/core/services/desktop_window_screenshot.dart';
import 'package:test/test.dart';

void main() {
  group('inferMacOsAppCandidates', () {
    test('reads bundle and AppInfo candidates', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'mcp_window_capture',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final bundleDir = Directory(
        '${tempDir.path}/build/macos/Build/Products/Debug/sample_app.app/Contents/MacOS',
      )..createSync(recursive: true);
      File('${bundleDir.path}/sample_app').writeAsStringSync('');
      File('${tempDir.path}/macos/Runner/Configs/AppInfo.xcconfig')
        ..createSync(recursive: true)
        ..writeAsStringSync('PRODUCT_NAME = sample_app\n');

      final candidates = inferMacOsAppCandidates(projectDir: tempDir.path);
      expect(candidates, contains('sample_app'));
      expect(candidates.length, equals(candidates.toSet().length));
    });
  });

  group('MacOsDesktopWindowScreenshotService', () {
    test('returns null for non-macos devices', () async {
      final service = MacOsDesktopWindowScreenshotService();
      final capture = await service.capture(
        projectDir: Directory.systemTemp.path,
        device: 'web',
        compress: true,
      );
      expect(capture, isNull);
    });

    test('captures base64 PNG payload from swift helper output', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'mcp_window_capture',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final bundleDir = Directory(
        '${tempDir.path}/build/macos/Build/Products/Debug/sample_app.app/Contents/MacOS',
      )..createSync(recursive: true);
      File('${bundleDir.path}/sample_app').writeAsStringSync('');

      String? compiledBinary;

      final service = MacOsDesktopWindowScreenshotService(
        runProcess: (final executable, final arguments) async {
          if (executable == 'swiftc') {
            compiledBinary = arguments.last;
            return ProcessResult(1, 0, '', '');
          }
          expect(executable, equals(compiledBinary));
          expect(arguments.first, equals('capture'));
          final payload = <String, Object?>{
            'ok': true,
            'appName': 'sample_app',
            'windowId': 77,
            'windowBounds': <String, Object?>{
              'x': 10.0,
              'y': 20.0,
              'width': 300.0,
              'height': 200.0,
            },
            'pngBase64': base64Encode(<int>[1, 2, 3, 4]),
            'permissionStatus': 'granted',
          };
          return ProcessResult(1, 0, jsonEncode(payload), '');
        },
      );

      final capture = await service.capture(
        projectDir: tempDir.path,
        device: 'macos',
        compress: true,
        cacheDir: tempDir.path,
      );

      expect(capture, isNotNull);
      expect(capture!.captureMode, equals('desktop_window'));
      expect(capture.images, hasLength(1));
      expect(capture.metadata['appName'], equals('sample_app'));
      expect(capture.metadata['windowId'], equals(77));
      expect(compiledBinary, isNotNull);
    });

    test('status/request/open-settings parse helper payloads', () async {
      final calls = <String>[];
      String? compiledBinary;
      final service = MacOsDesktopWindowScreenshotService(
        runProcess: (final executable, final arguments) async {
          if (executable == 'swiftc') {
            compiledBinary = arguments.last;
            return ProcessResult(1, 0, '', '');
          }
          expect(executable, equals(compiledBinary));
          calls.add(arguments.first);
          final payload = switch (arguments.first) {
            'status' => <String, Object?>{
              'ok': true,
              'status': 'not_determined',
              'message': 'status',
              'canRequest': true,
              'canOpenSettings': true,
              'details': <String, Object?>{},
            },
            'request' => <String, Object?>{
              'ok': true,
              'status': 'granted',
              'message': 'request',
              'canRequest': true,
              'canOpenSettings': true,
              'details': <String, Object?>{},
            },
            'open-settings' => <String, Object?>{
              'ok': true,
              'status': 'denied',
              'message': 'open',
              'canRequest': true,
              'canOpenSettings': true,
              'details': <String, Object?>{'opened': true},
            },
            _ => throw StateError('unexpected ${arguments.first}'),
          };
          return ProcessResult(1, 0, jsonEncode(payload), '');
        },
      );

      const configuration = CoreRuntimeConfiguration(
        vmHost: 'localhost',
        vmPort: 8181,
        resourcesSupported: true,
        imagesSupported: true,
        dumpsSupported: false,
        dynamicRegistrySupported: false,
        saveImagesToFiles: false,
        flutterDevice: 'macos',
        stateRootDir: '/tmp/flutter_mcp_state',
      );

      final status = await service.status(
        kind: PermissionKind.visualCapture,
        policy: PermissionPolicy.checkOnly,
        configuration: configuration,
      );
      final request = await service.request(
        kind: PermissionKind.visualCapture,
        policy: PermissionPolicy.requestAlways,
        configuration: configuration,
      );
      final openSettings = await service.openSettings(
        kind: PermissionKind.visualCapture,
        policy: PermissionPolicy.checkOnly,
        configuration: configuration,
      );

      expect(status.status, equals(PermissionStatus.notDetermined));
      expect(request.status, equals(PermissionStatus.granted));
      expect(openSettings.status, equals(PermissionStatus.denied));
      expect(
        calls,
        equals(const <String>['status', 'request', 'open-settings']),
      );
    });

    test('helper cache key is stable for identical source', () {
      expect(
        helperSourceHash('same-source'),
        equals(helperSourceHash('same-source')),
      );
      expect(
        helperSourceHash('same-source'),
        isNot(equals(helperSourceHash('other-source'))),
      );
    });
  });
}
